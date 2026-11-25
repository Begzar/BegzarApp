import 'package:begzar/core/services/analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's analytics sink.
///
/// `AnalyticsService` is a singleton behind a factory constructor, so this
/// hands out the same instance either way. The point of the provider is not a
/// second instance — it is that consumers take analytics as a dependency they
/// were given rather than reaching for it, which is what makes them testable
/// without Firebase and what keeps the reach out of the layers below.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(),
);
