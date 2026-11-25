import 'dart:async';

import 'package:begzar/core/navigation/root_navigator_key.dart';
import 'package:begzar/core/services/native_url_launcher.dart';
import 'package:begzar/core/support/support_contact.dart';
import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/di/app_update_providers.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_paywall_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The page buyers outside Iran register on to buy premium.
///
/// Emptying it sends every purchase back to the bot, as every purchase always
/// went before the page was live.
const premiumWebsiteUrl = 'https://begzar.app/premium';

/// Opens wherever this buyer should buy premium.
///
/// Every "Buy" and "Renew" in the app comes through here. Support does not:
/// "Get help" and a disabled account still open the bot wherever the user is,
/// because it is the bot that answers them.
///
/// On a Play build every purchase is the paywall, which sells through Google
/// Play; nothing here can reach the bot or the website to buy there.
///
/// Holds [Ref] rather than borrowing a widget's, because the tap that calls
/// [open] has usually taken its own widget off screen by the time the link
/// is resolved.
class PremiumPurchaseLauncher {
  PremiumPurchaseLauncher(this._ref);

  final Ref _ref;

  bool get sellsThroughGooglePlay =>
      _ref.read(appDistributionSourceProvider) ==
      AppDistributionSource.googlePlay;

  Future<PurchaseDestination> destination() async {
    if (sellsThroughGooglePlay) return PurchaseDestination.googlePlay;

    final status = _ref.read(connectionProvider).status;
    final region = await _ref
        .read(purchaseRegionServiceProvider)
        .resolve(tunnelIsUp: status.isActive || status.isTransitional);
    return purchaseDestinationFor(
      region,
      websiteReady: premiumWebsiteUrl.isNotEmpty,
    );
  }

  /// Settles where this buyer would be sent before any button asks, so the
  /// first purchase dialog of a run already knows.
  ///
  /// Called once per launch, after the tunnel has been reconciled: a relaunch
  /// that adopts a live Apple tunnel must be seen as connected, or its exit
  /// would be asked for and taken for the buyer's address.
  ///
  /// A subscriber is left alone. Nothing on their screen offers a purchase, so
  /// asking where they are would be a request with no one to answer — the
  /// same reason a subscriber's connect never asks for an ad. If their
  /// subscription lapses mid-run, the renewal dialog resolves on demand.
  Future<void> warm() async {
    // A launch restore that has not landed yet reads as signed out.
    await _ref.read(premiumProvider.notifier).ensureRestored();
    if (_ref.read(premiumProvider).hasActiveSubscription) return;
    await destination();
  }

  /// [renewal] titles the paywall for a subscription that ran out; the bot
  /// and the website ask nothing different for one.
  Future<bool> open({bool renewal = false}) async {
    switch (await destination()) {
      case PurchaseDestination.googlePlay:
        final context = rootNavigatorKey.currentContext;
        if (context == null || !context.mounted) return false;
        unawaited(showPremiumPaywall(context, renewal: renewal));
        return true;
      case PurchaseDestination.telegramBot:
        return NativeUrlLauncher.open(supportTelegramLink);
      case PurchaseDestination.website:
        return NativeUrlLauncher.open(premiumWebsiteUrl);
    }
  }
}

final premiumPurchaseLauncherProvider = Provider<PremiumPurchaseLauncher>(
  PremiumPurchaseLauncher.new,
);

/// Where a purchase button on screen will go, for the mark it wears.
///
/// `autoDispose`, so each dialog reads the device afresh; the address answer
/// it may need is held by the service — usually since [PremiumPurchaseLauncher.warm]
/// ran at launch — and not asked twice.
final purchaseDestinationProvider =
    FutureProvider.autoDispose<PurchaseDestination>(
      (ref) => ref.watch(premiumPurchaseLauncherProvider).destination(),
    );
