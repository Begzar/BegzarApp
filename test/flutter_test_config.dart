import 'dart:async';

import 'package:begzar/core/log/log.dart';

/// Runs before every test file in this directory tree — `flutter_test` picks
/// this name up on its own, so nothing has to import it.
///
/// Its whole job is to silence the log. `Log` writes whenever `kDebugMode` is
/// true, and that includes the test binary, so a suite that exercised a
/// connect used to print a few hundred lines of somebody else's traces between
/// the dots. The signal a test run is meant to carry is which tests failed.
///
/// A test that wants to assert on what was logged installs a
/// `RecordingLogSink` itself and puts this back in a tearDown.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Log.sink = null;
  await testMain();
}
