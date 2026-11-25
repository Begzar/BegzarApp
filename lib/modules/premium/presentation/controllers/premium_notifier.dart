import 'dart:async';

import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/premium_connect_validation.dart';
import 'package:begzar/modules/premium/application/services/premium_account_service.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/premium_credentials.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' hide State;

class PremiumNotifier extends Notifier<PremiumState> {
  static const _log = Log('premium');

  late PremiumAccountService _accounts;

  /// Bumped whenever the session is deliberately ended, so a network call
  /// that started against the old session cannot publish its result over the
  /// new one.
  int _generation = 0;

  /// Counts refreshes as they are asked for, so an answer can tell whether a
  /// newer refresh has been asked for since.
  int _latestRefresh = 0;

  /// Completes once the stored session has been read, whatever it said.
  ///
  /// [PremiumRestoring] carries no account, so every `isLoggedIn` /
  /// `hasActiveSubscription` read taken before the restore lands answers the
  /// same as a signed-out user's. That is harmless for a card that will
  /// rebuild, and wrong for a one-shot decision — the post-connect ad gate
  /// would show a paying user an ad because the answer had not arrived yet.
  /// Those callers await [ensureRestored] first.
  Completer<void>? _restored;

  @override
  PremiumState build() {
    _accounts = ref.watch(premiumAccountServiceProvider);
    _restored = Completer<void>();
    _restore(_generation);
    return const PremiumRestoring();
  }

  /// Resolves when the launch restore has finished, immediately thereafter.
  ///
  /// The network refresh that follows a restored session is not waited on: it
  /// can hang for its whole timeout, and the stored account already answers
  /// the entitlement question.
  Future<void> ensureRestored() => _restored?.future ?? Future<void>.value();

  void _markRestored() {
    final completer = _restored;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  /// True when a result must be dropped rather than published: the session it
  /// belongs to has ended, or the provider itself is gone (the restore that
  /// runs from `build` outlives a container disposed while it is in flight).
  bool _isStale(int generation) => generation != _generation || !ref.mounted;

  Future<void> _restore(int generation) async {
    try {
      final session = await _accounts.restoreSession();
      if (_isStale(generation)) return;

      if (session == null) {
        state = const PremiumSignedOut();
        return;
      }

      state = PremiumSignedIn(account: session.account);
      _markRestored();

      // Refresh in the background; a network failure keeps the stored account.
      await refreshSubscription(silent: true);
    } catch (_) {
      if (_isStale(generation)) return;
      state = const PremiumSignedOut();
    } finally {
      // Also covers the stale returns above: a disposed container still has to
      // release whoever is waiting, or they wait forever.
      _markRestored();
    }
  }

  /// Refreshes the stored account, dropping the answer if the session it
  /// belongs to ended while the call was in flight.
  ///
  /// Null means there was no stored credential to ask with, or the session
  /// went stale — either way there is nothing to publish, and deciding what
  /// to publish is the caller's job.
  Future<Either<ApiFailure, PremiumAccount>?> _refreshAccount(
    int generation,
  ) async {
    if (_isStale(generation)) return null;

    final result = await _accounts.refreshAccount();
    if (result == null || _isStale(generation)) return null;

    return result;
  }

  /// Ends the session when [failure] says the server already has, and reports
  /// whether it did.
  ///
  /// A revoked session is not an error to show on a premium screen — the
  /// screen it would be shown on belongs to an account this device no longer
  /// holds. The generation moves with it so a refresh still in flight against
  /// the dead session cannot publish an account over the sign-out.
  bool _publishIfRevoked(ApiFailure failure) {
    if (failure is! SessionRevokedFailure) return false;

    // Once per seat: the device list can report it after a refresh already
    // has, and by then the session is long gone.
    if (state is! PremiumSignedOut) {
      unawaited(ref.read(analyticsServiceProvider).logPremiumRevoked());
    }
    _generation++;
    state = const PremiumSignedOut.revoked();
    _markRestored();
    return true;
  }

  /// Publishes a sign-out for a session another premium caller found revoked.
  ///
  /// The device list refreshes the account too, so it can be the first to be
  /// told a seat was freed. Its answer clears the stored session either way;
  /// without this the rest of the app would go on showing a subscription that
  /// no longer has anything behind it.
  void endRevokedSession() {
    if (state is PremiumSignedOut) return;
    _publishIfRevoked(const SessionRevokedFailure());
  }

  Future<void> login(String username, String password) async {
    final credentials = PremiumCredentials.parse(
      username: username,
      password: password,
    );
    if (credentials == null) {
      state = const PremiumSignedOut(
        errorMessage: UserFacingErrorKeys.credentialsRequired,
      );
      return;
    }

    final generation = _generation;
    state = const PremiumSignedOut(isAuthenticating: true);

    try {
      final result = await _accounts.signIn(credentials);
      if (_isStale(generation)) return;

      switch (result) {
        case Left(value: final failure):
          state = PremiumSignedOut(errorMessage: failure.userFacingKey);
        case Right(value: final session):
          state = PremiumSignedIn(account: session.account);
          unawaited(ref.read(analyticsServiceProvider).logLogin());
      }
    } catch (e) {
      if (_isStale(generation)) return;
      state = PremiumSignedOut(errorMessage: resolveUserFacingErrorKey(e));
    }
  }

  /// Publishes the account a confirmed sign-up opened.
  ///
  /// The repository has already stored its session; this is the sign-in the
  /// rest of the app reacts to, arriving from signed out like any other. The
  /// generation moves so nothing still in flight from before can publish over
  /// it.
  void adoptSignedUpAccount(PremiumAccount account) {
    if (!ref.mounted) return;
    _generation++;
    state = PremiumSignedIn(account: account);
    _markRestored();
    unawaited(ref.read(analyticsServiceProvider).logSignUp());
  }

  /// Deletes the account, then ends the session as one the server ended: the
  /// account is gone, so a tunnel it opened is not the user's to keep.
  ///
  /// Returns why it was refused, as an l10n key, or null once it is done. The
  /// confirmation that asked for it is still on screen, and the refusal is
  /// shown there rather than on the account panel behind it.
  Future<String?> deleteAccount(String password) async {
    // Refused here rather than by the server, the way an empty sign-in is.
    if (password.isEmpty) return UserFacingErrorKeys.passwordRequired;

    final generation = _generation;
    _log.trace('account.delete');

    try {
      final result = await _accounts.deleteAccount(password);
      if (_isStale(generation)) return null;

      switch (result) {
        case Left(value: final failure):
          _log.warn('account.delete.refused', {
            'reason': failure.runtimeType,
            'key': failure.userFacingKey,
          });
          return failure.userFacingKey;
        case Right():
          _generation++;
          state = const PremiumSignedOut(isRevoked: true);
          _markRestored();
          return null;
      }
    } catch (e) {
      _log.error('account.delete.threw', {'type': e.runtimeType}, e);
      return UserFacingErrorKeys.deleteAccountFailed;
    }
  }

  /// Publishes the server's latest word on the account. Only the refresh
  /// asked for last may publish: one the launch sent before a purchase was
  /// granted can answer after the one the grant asked for, and must not put
  /// the unpaid account back on screen.
  Future<void> refreshSubscription({bool silent = false}) async {
    final generation = _generation;
    final current = state;
    if (current is! PremiumSignedIn) return;
    final refresh = ++_latestRefresh;

    if (!silent) {
      state = current.copyWith(isRefreshing: true, clearError: true);
    }

    try {
      final result = await _refreshAccount(generation);
      if (_isStale(generation) || refresh != _latestRefresh) return;

      // A silent refresh publishes no error, and this is not one: the session
      // it was refreshing has ended, which the user is told either way.
      if (result case Left(value: final failure)) {
        if (_publishIfRevoked(failure)) return;
      }

      final signedIn = state;
      if (signedIn is! PremiumSignedIn) return;

      state = switch (result) {
        null => signedIn.copyWith(isRefreshing: false),
        Left(value: final failure) => signedIn.copyWith(
          isRefreshing: false,
          errorMessage: silent ? null : failure.userFacingKey,
          clearError: silent,
        ),
        Right(value: final account) => PremiumSignedIn(account: account),
      };
    } catch (_) {
      if (_isStale(generation) || refresh != _latestRefresh) return;
      final signedIn = state;
      if (signedIn is! PremiumSignedIn) return;
      state = signedIn.copyWith(
        isRefreshing: false,
        errorMessage: silent ? null : UserFacingErrorKeys.refreshFailed,
        clearError: silent,
      );
    }
  }

  /// Re-checks the subscription with the server immediately before connecting.
  ///
  /// Gated on the entitlement rather than on which body the home screen is
  /// showing, so it matches what the connect button actually reaches for.
  /// A locally-valid subscription the server has since ended still comes back
  /// as [PremiumConnectValidation.subscriptionExpired].
  Future<PremiumConnectValidation> validateBeforeConnect() async {
    final generation = _generation;
    final current = state;

    if (!current.isEntitled) {
      _log.trace('entitlement.skipped', {'why': 'not entitled'});
      return PremiumConnectValidation.skipped;
    }
    if (current is! PremiumSignedIn) {
      _log.trace('entitlement.skipped', {'why': 'not signed in'});
      return PremiumConnectValidation.notLoggedIn;
    }

    try {
      _log.trace('entitlement.check');
      final check = await _accounts.checkEntitlement();
      _log.trace('entitlement.verdict', {'verdict': check.verdict.name});
      if (check.verdict == PremiumConnectValidation.notLoggedIn) {
        return check.verdict;
      }
      // A session that ended mid-check has nowhere to publish to, and nothing
      // that reads the reason is on screen for a signed-out account.
      if (_isStale(generation)) return PremiumConnectValidation.checkFailed;

      // Publish what the server just said, so the subscription card and this
      // verdict cannot disagree.
      final failure = check.failure;
      if (failure != null) {
        // A seat taken away mid-session is refused as a connect by a signed-out
        // user, which is what this device now is.
        if (_publishIfRevoked(failure)) {
          return PremiumConnectValidation.notLoggedIn;
        }
        final signedIn = state;
        if (signedIn is PremiumSignedIn) {
          state = signedIn.copyWith(errorMessage: failure.userFacingKey);
        }
      } else if (check.account case final account?) {
        state = PremiumSignedIn(account: account);
      }

      return check.verdict;
    } catch (e) {
      _log.error('entitlement.threw', {'type': e.runtimeType}, e);
      // The reason a refused connect is shown comes from here. Left
      // unpublished, a check that threw was reported with whatever the last
      // premium failure had happened to be — or, on a session that had never
      // failed at anything, with nothing at all.
      if (!_isStale(generation)) {
        final signedIn = state;
        if (signedIn is PremiumSignedIn) {
          state = signedIn.copyWith(errorMessage: resolveUserFacingErrorKey(e));
        }
      }
      return PremiumConnectValidation.checkFailed;
    }
  }

  Future<void> logout() async {
    final current = state;
    final account = current.account;
    if (account == null) return;

    state = PremiumSigningOut(account);
    final generation = ++_generation;

    try {
      await _accounts.signOut();
      if (_isStale(generation)) return;
      state = const PremiumSignedOut();
    } catch (_) {
      if (_isStale(generation)) return;
      state = PremiumSignedIn(
        account: account,
        errorMessage: UserFacingErrorKeys.signOutFailed,
      );
    }
  }
}

final premiumProvider = NotifierProvider<PremiumNotifier, PremiumState>(
  PremiumNotifier.new,
);
