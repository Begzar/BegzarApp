import 'dart:async';

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/app_update/di/app_update_providers.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tier [state] stands for, or null while the stored session is still
/// being read and nothing is known yet.
PlanTier? _tierOf(PremiumState? state) => switch (state) {
  null || PremiumRestoring() => null,
  _ when state.hasActiveSubscription => PlanTier.premium,
  _ => PlanTier.free,
};

/// Keeps the user properties every analytics event is split by in step with
/// the app: the channel the build came from, set once, and whether the user
/// is paying, set whenever that changes.
///
/// It lives in the app shell because it reads two modules, and the shell is
/// the one layer allowed to. The tier follows the same rule as the ad gate, an
/// unexpired paid period, so `premium` means exactly the users who see no ads.
final analyticsUserPropertiesProvider = Provider<void>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  unawaited(
    analytics.setDistribution(
      source: ref.watch(appDistributionSourceProvider).apiKey,
    ),
  );

  ref.listen<PremiumState>(premiumProvider, (previous, next) {
    final tier = _tierOf(next);
    if (tier == null || tier == _tierOf(previous)) return;
    unawaited(analytics.setPlanTier(tier: tier));
  }, fireImmediately: true);
});
