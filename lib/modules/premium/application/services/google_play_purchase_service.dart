import 'dart:async';
import 'dart:io';

import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/log/log.dart';
import 'package:begzar/modules/premium/data/repositories/google_play_billing_repository.dart';
import 'package:begzar/modules/premium/data/repositories/premium_repository.dart';
import 'package:begzar/modules/premium/domain/play_account_tag.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:fpdart/fpdart.dart';

/// Sells premium through Google Play and sees each purchase through.
///
/// It listens for the whole run, not only while the paywall is open: a
/// pending payment can clear while the app is closed, and Play keeps an
/// unfinished purchase to hand over again on the next launch. A purchase is
/// finished only once the server has granted it — Play refunds one left
/// unacknowledged for three days, and acknowledging first would charge for
/// something the server never gave.
class GooglePlayPurchaseService {
  GooglePlayPurchaseService({
    required GooglePlayBillingRepository billing,
    required PremiumRepository premium,
  }) : _billing = billing,
       _premium = premium;

  static const _log = Log('premium');

  final GooglePlayBillingRepository _billing;
  final PremiumRepository _premium;
  final _outcomes = StreamController<PlayPurchaseOutcome>.broadcast();
  StreamSubscription<void>? _subscription;

  /// What came of each purchase, as it happens.
  Stream<PlayPurchaseOutcome> get outcomes => _outcomes.stream;

  Future<String?> _signedInTag() async {
    final session = await _premium.readSession();
    return session == null ? null : playAccountTag(session.account.username);
  }

  void _announce(PlayPurchaseOutcome outcome) {
    _log.trace('play.outcome', {'outcome': outcome.name});
    if (!_outcomes.isClosed) _outcomes.add(outcome);
  }

  /// True when the server looked at the purchase and turned it down — a
  /// token Google does not know, a tag that is not this account's. Asking
  /// again will not change that answer, so the buyer is told it failed and
  /// Play refunds it. Anything else — no connection, a server error, a key
  /// the server no longer takes, too many requests — may well go through
  /// when the next launch reports it again.
  static bool _refusedOutright(ApiFailure failure) {
    if (failure is! ServerFailure) return false;
    final status = failure.statusCode;
    return status != null &&
        status >= HttpStatus.badRequest &&
        status < HttpStatus.internalServerError &&
        status != HttpStatus.unauthorized &&
        status != HttpStatus.tooManyRequests;
  }

  /// Reports a paid purchase and finishes it once the server has granted it.
  ///
  /// A purchase bound to another account, or with nobody signed in, is left
  /// alone: this device cannot report it for its owner, and the server grants
  /// it from Play's own notice. One already acknowledged has nothing left to
  /// do.
  Future<void> _seeThrough(PlayPurchase purchase) async {
    if (purchase.isAcknowledged) return;
    final tag = await _signedInTag();
    if (tag == null || purchase.accountTag != tag) {
      _log.trace('play.purchase.skipped', {'signedIn': tag != null});
      return;
    }

    final report = await _premium.reportGooglePlayPurchase(
      productId: purchase.productId,
      purchaseToken: purchase.purchaseToken,
    );
    switch (report) {
      case Left(value: final ApiFailure failure):
        _log.warn('play.report.refused', {
          'reason': failure.runtimeType,
          'key': failure.userFacingKey,
        });
        _announce(
          _refusedOutright(failure)
              ? PlayPurchaseOutcome.failed
              : PlayPurchaseOutcome.confirmLater,
        );
      case Right():
        // The server has granted it, so the buyer has premium whatever Play
        // answers now. An acknowledgement that fails is made by the next
        // launch's restore, which reports the token again — the server
        // answers a repeat without granting twice — and acknowledges then.
        try {
          await _billing.complete(purchase);
        } catch (error) {
          _log.warn('play.complete.failed', {'type': error.runtimeType});
        }
        _announce(PlayPurchaseOutcome.granted);
    }
  }

  Future<void> _handleOne(PlayPurchase purchase) async {
    switch (purchase.state) {
      case PlayPurchaseState.purchased:
        await _seeThrough(purchase);
      case PlayPurchaseState.pending:
        _announce(PlayPurchaseOutcome.pending);
      case PlayPurchaseState.canceled:
        _announce(PlayPurchaseOutcome.canceled);
      case PlayPurchaseState.alreadyOwned:
        _announce(PlayPurchaseOutcome.alreadyOwned);
      case PlayPurchaseState.failed:
        _announce(PlayPurchaseOutcome.failed);
    }
  }

  /// A purchase whose handling throws — storage that will not answer while
  /// it is reported — is left unfinished for the next launch to report
  /// again, and the buyer is told it is being confirmed rather than left
  /// waiting on an answer that is not coming. The rest of the batch still
  /// gets its turn.
  Future<void> _handle(List<PlayPurchase> batch) async {
    for (final purchase in batch) {
      try {
        await _handleOne(purchase);
      } catch (error) {
        _log.warn('play.purchase.threw', {'type': error.runtimeType});
        _announce(PlayPurchaseOutcome.confirmLater);
      }
    }
  }

  /// Asks Play for every purchase it still holds; each arrives like a new
  /// one and is seen through the same way.
  Future<void> restore() async {
    try {
      await _billing.restore();
    } catch (error) {
      _log.warn('play.restore.failed', {'type': error.runtimeType});
    }
  }

  /// Starts listening and picks up what an earlier run left unfinished.
  /// Purchases are handled one at a time, in the order Play reports them.
  Future<void> start() async {
    _subscription ??= _billing.purchases
        .asyncMap(_handle)
        .listen(
          (_) {},
          onError: (Object error) {
            _log.warn('play.stream.failed', {'type': error.runtimeType});
          },
        );
    await restore();
  }

  Future<Either<ApiFailure, List<PremiumPlanOffer>>> loadOffers() =>
      _billing.loadOffers();

  /// Opens Play's sheet for [plan], bound to the signed-in account. False with
  /// nobody signed in: a purchase has to land on an account.
  Future<bool> buy(PremiumPlan plan) async {
    final tag = await _signedInTag();
    if (tag == null) return false;
    return _billing.buy(plan, tag);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _outcomes.close();
  }
}
