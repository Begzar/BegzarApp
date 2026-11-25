import 'package:begzar/core/services/analytics_service.dart';

/// An [AnalyticsService] that writes nothing down anywhere but here.
///
/// Every call lands in [noSuchMethod] and is kept as it arrived, so a test
/// asserts on what the app told analytics without Firebase in the room, and a
/// new log method needs nothing added here before a test can see it.
class RecordingAnalytics implements AnalyticsService {
  final List<Invocation> _calls = [];

  /// The named arguments of every call to [method], oldest first.
  List<Map<Symbol, Object?>> callsTo(Symbol method) => [
    for (final call in _calls)
      if (call.memberName == method) call.namedArguments,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) return null;
    _calls.add(invocation);
    return Future<void>.value();
  }
}
