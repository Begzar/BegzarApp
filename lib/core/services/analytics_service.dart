import 'package:begzar/core/services/firebase_platform.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// How the promotion a connect showed reached the screen.
enum PromotionSource {
  /// Picked and warmed before the connect, so it painted at once.
  prepared,

  /// Nothing was prepared, so it was fetched behind the shimmer.
  fetched,
}

/// Why a promotion's wait went unserved and cost the user the tunnel.
enum PromotionAbandonCause {
  /// The app left the foreground mid-wait.
  background,

  /// The app was killed mid-wait, and the next launch took the tunnel back.
  relaunch,
}

/// How a connect chose the server it dialled.
enum ConnectSelection {
  /// Quick connect: the app probed the list and picked one of the fastest.
  auto,

  /// The user picked the server by hand.
  manual,
}

/// Whether the user is paying.
enum PlanTier {
  /// Not subscribed: sees the post-connect promotion.
  free,

  /// Inside a paid period: sees no ads.
  premium,
}

/// Firebase Analytics Service
/// Manages all analytics events for the application
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// The one place promotions are shown: the overlay after a connect.
  static const _promotionSlot = 'post_connect';
  static const _promotionAbandonedEvent = 'promotion_abandoned';
  static const _promotionBannerFailedEvent = 'promotion_banner_failed';
  static const _promotionUnavailableEvent = 'promotion_unavailable';
  static const _distributionProperty = 'distribution';
  static const _planTierProperty = 'plan_tier';
  static const _forceUpdateRequiredEvent = 'force_update_required';
  static const _premiumRevokedEvent = 'premium_revoked';
  static const _paywallOpenedEvent = 'paywall_open';
  static const _playPurchaseResultEvent = 'play_purchase_result';

  /// How a premium account signs in and is created: a password, and an email
  /// confirmed by code.
  static const _passwordMethod = 'password';
  static const _emailMethod = 'email';
  static const _settingChangedEvent = 'settings_changed';
  static const _localNotificationOpenedEvent = 'local_notification_open';

  FirebaseAnalytics? _analytics;

  FirebaseAnalytics? get analytics =>
      isFirebaseSupported ? (_analytics ??= FirebaseAnalytics.instance) : null;

  FirebaseAnalyticsObserver? get observer {
    final analyticsInstance = analytics;
    if (analyticsInstance == null) {
      return null;
    }
    return FirebaseAnalyticsObserver(analytics: analyticsInstance);
  }

  /// Hands [log] the Firebase instance, where this platform has one.
  ///
  /// Reaching for the instance happens inside the `try` too: without an
  /// initialized Firebase app it throws, and analytics must never interrupt
  /// the app.
  Future<void> _record(
    Future<void> Function(FirebaseAnalytics analytics) log,
  ) async {
    try {
      final instance = analytics;
      if (instance == null) return;
      await log(instance);
    } catch (_) {
      // Analytics must never interrupt the app.
    }
  }

  /// Log user connected event
  Future<void> logUserConnected({
    String? configName,
    String? connectionMode,
  }) async {
    if (!isFirebaseSupported) {
      return;
    }
    try {
      await analytics?.logEvent(
        name: 'user_connected',
        parameters: {
          'config_name': ?configName,
          'connection_mode': ?connectionMode,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {
      // Analytics must never interrupt the app.
    }
  }

  /// Log user disconnected event
  Future<void> logUserDisconnected({int? connectionDuration}) async {
    if (!isFirebaseSupported) {
      return;
    }
    try {
      await analytics?.logEvent(
        name: 'user_disconnected',
        parameters: {
          'duration_seconds': ?connectionDuration,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {
      // Analytics must never interrupt the app.
    }
  }

  /// A connect the user asked for ended without a tunnel.
  ///
  /// [reason] is the failure's l10n key, never its message: a message can
  /// carry raw server text. [configName] is set only when the user picked the
  /// server, because a quick connect that failed never settled on one.
  Future<void> logConnectionFailed({
    required String reason,
    required ConnectSelection selection,
    String? configName,
  }) async {
    if (!isFirebaseSupported) {
      return;
    }
    try {
      await analytics?.logEvent(
        name: 'connection_failed',
        parameters: {
          'failure_reason': reason,
          'selection': selection.name,
          'config_name': ?configName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {
      // Analytics must never interrupt the app.
    }
  }

  /// Set user properties
  Future<void> setUserProperties({String? userId, String? deviceType}) async {
    if (!isFirebaseSupported) {
      return;
    }
    try {
      if (userId != null) {
        await analytics?.setUserId(id: userId);
      }
      if (deviceType != null) {
        await analytics?.setUserProperty(
          name: 'device_type',
          value: deviceType,
        );
      }
    } catch (_) {
      // Analytics must never interrupt the app.
    }
  }

  /// Log custom event
  Future<void> logCustomEvent(
    String eventName, {
    Map<String, Object>? parameters,
  }) async {
    if (!isFirebaseSupported) {
      return;
    }
    try {
      await analytics?.logEvent(name: eventName, parameters: parameters);
    } catch (_) {
      // Analytics must never interrupt the app.
    }
  }

  /// A promotion reached the screen: the impression its click rate is
  /// counted against.
  Future<void> logPromotionViewed({
    required int promotionId,
    required String promotionName,
    required PromotionSource source,
  }) => _record(
    (analytics) => analytics.logViewPromotion(
      promotionId: '$promotionId',
      promotionName: promotionName,
      creativeSlot: _promotionSlot,
      parameters: {'source': source.name},
    ),
  );

  /// The promotion's action was tapped. [opened] is false when no app would
  /// take the link, which is how a dead click URL shows up.
  Future<void> logPromotionSelected({
    required int promotionId,
    required String promotionName,
    required bool duringWait,
    required bool opened,
  }) => _record(
    (analytics) => analytics.logSelectPromotion(
      promotionId: '$promotionId',
      promotionName: promotionName,
      creativeSlot: _promotionSlot,
      parameters: {'during_wait': '$duringWait', 'opened': '$opened'},
    ),
  );

  /// The user walked out on a promotion's wait and lost the tunnel for it.
  ///
  /// A relaunch knows only the [cause]: which promotion it was, and how much
  /// of its wait was left, went with the process that was killed.
  Future<void> logPromotionAbandoned({
    required PromotionAbandonCause cause,
    int? promotionId,
    String? promotionName,
    int? secondsLeft,
  }) => _record(
    (analytics) => analytics.logEvent(
      name: _promotionAbandonedEvent,
      parameters: {
        'cause': cause.name,
        if (promotionId != null) 'promotion_id': '$promotionId',
        'promotion_name': ?promotionName,
        'seconds_left': ?secondsLeft,
      },
    ),
  );

  /// The promotion's banner could not be loaded, so the overlay showed a
  /// broken-image stand-in instead of the artwork.
  Future<void> logPromotionBannerFailed({
    required int promotionId,
    required String promotionName,
  }) => _record(
    (analytics) => analytics.logEvent(
      name: _promotionBannerFailedEvent,
      parameters: {
        'promotion_id': '$promotionId',
        'promotion_name': promotionName,
      },
    ),
  );

  /// A connect was gated for a promotion and there was none to show: nothing
  /// prepared, and the list came back empty or not at all.
  Future<void> logPromotionUnavailable() => _record(
    (analytics) => analytics.logEvent(name: _promotionUnavailableEvent),
  );

  /// The channel this build was made for, as a user property, so every event
  /// can be split by where the app was installed from.
  Future<void> setDistribution({required String source}) => _record(
    (analytics) =>
        analytics.setUserProperty(name: _distributionProperty, value: source),
  );

  /// Whether the user is paying, as a user property, so every event can be
  /// split by who sees ads and who does not.
  Future<void> setPlanTier({required PlanTier tier}) => _record(
    (analytics) =>
        analytics.setUserProperty(name: _planTierProperty, value: tier.name),
  );

  /// A root screen came into view. The app's tabs share one activity, so the
  /// SDK's own screen tracking cannot tell them apart.
  Future<void> logScreenView({required String screenName}) => _record(
    (analytics) => analytics.logScreenView(
      screenName: screenName,
      screenClass: screenName,
    ),
  );

  /// This build is older than the server will serve, and connecting is held
  /// until it is updated.
  Future<void> logForceUpdateRequired({
    required String currentVersion,
    required String requiredVersion,
  }) => _record(
    (analytics) => analytics.logEvent(
      name: _forceUpdateRequiredEvent,
      parameters: {
        'current_version': currentVersion,
        'required_version': requiredVersion,
      },
    ),
  );

  /// A premium sign-in went through. GA4's standard event, so it fills the
  /// built-in sign-in reports.
  Future<void> logLogin() =>
      _record((analytics) => analytics.logLogin(loginMethod: _passwordMethod));

  /// A new account was confirmed and is now signed in on this device.
  Future<void> logSignUp() =>
      _record((analytics) => analytics.logSignUp(signUpMethod: _emailMethod));

  /// The server took this device's seat away, so its session ended without
  /// the user signing out.
  Future<void> logPremiumRevoked() =>
      _record((analytics) => analytics.logEvent(name: _premiumRevokedEvent));

  /// The paywall opened. [plans] is how many Play offered; none means the
  /// paywall could only say that nothing is for sale.
  Future<void> logPaywallOpened({required int plans}) => _record(
    (analytics) => analytics.logEvent(
      name: _paywallOpenedEvent,
      parameters: {'plans': plans},
    ),
  );

  /// Play's purchase sheet opened for the selected plan.
  ///
  /// No price is sent. Play reports the purchase that follows as
  /// `in_app_purchase`, with its revenue, and a value here would count the
  /// same sale twice.
  Future<void> logBeginCheckout({required int devices, required int months}) =>
      _record(
        (analytics) => analytics.logBeginCheckout(
          parameters: {'devices': devices, 'months': months},
        ),
      );

  /// How a purchase the paywall started ended. [outcome] is the name of the
  /// premium module's outcome, which core may not import.
  Future<void> logPlayPurchaseResult({
    required String outcome,
    required int devices,
    required int months,
  }) => _record(
    (analytics) => analytics.logEvent(
      name: _playPurchaseResultEvent,
      parameters: {'outcome': outcome, 'devices': devices, 'months': months},
    ),
  );

  /// The user tapped a notification the app drew itself while it was open.
  /// Firebase records taps on the ones it shows; this is the one it cannot.
  Future<void> logLocalNotificationOpened() => _record(
    (analytics) => analytics.logEvent(name: _localNotificationOpenedEvent),
  );

  /// The user changed a setting. [value] is a kind, never what was typed: a
  /// resolver is `default` or `custom`, not its address.
  Future<void> logSettingChanged({
    required String setting,
    required String value,
  }) => _record(
    (analytics) => analytics.logEvent(
      name: _settingChangedEvent,
      parameters: {'setting': setting, 'value': value},
    ),
  );
}
