import 'package:begzar/modules/app_update/presentation/states/available_update_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the release the user may update to.
///
/// Nothing clears it. Opening settings is not dealing with it, so the dot
/// stays until a newer build is installed, which starts a new process.
class AvailableUpdateNotifier extends Notifier<AvailableUpdateState?> {
  @override
  AvailableUpdateState? build() => null;

  void publish({required String version, required String url}) {
    state = AvailableUpdateState(version: version, url: url);
  }
}

/// The optional update, readable by the nav bar and the settings screen.
///
/// App-wide for the same reason as `forceUpdateProvider`: the check runs once
/// at startup, and the screens that show its answer are mounted after it.
final availableUpdateProvider =
    NotifierProvider<AvailableUpdateNotifier, AvailableUpdateState?>(
      AvailableUpdateNotifier.new,
    );
