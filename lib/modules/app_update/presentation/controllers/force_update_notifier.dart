import 'dart:async';

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/app_update/presentation/states/force_update_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the forced-update verdict for the rest of the session.
///
/// One-way on purpose: there is no `clear`. The verdict comes from the server's
/// version catalog, and the only thing that can resolve it is installing a
/// newer build — which restarts the process anyway.
class ForceUpdateNotifier extends Notifier<ForceUpdateState> {
  @override
  ForceUpdateState build() => const ForceUpdateState();

  /// Recorded on the first verdict only: the startup gate and the connect path
  /// can both reach it, and a refused connect reaches it again on every tap.
  void markRequired({
    required String currentVersion,
    required String requiredVersion,
    String? updateUrl,
  }) {
    if (!state.required) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logForceUpdateRequired(
              currentVersion: currentVersion,
              requiredVersion: requiredVersion,
            ),
      );
    }
    state = ForceUpdateState(
      required: true,
      currentVersion: currentVersion,
      requiredVersion: requiredVersion,
      updateUrl: updateUrl ?? state.updateUrl,
    );
  }
}

/// The forced-update verdict, readable from anywhere that could start a tunnel.
///
/// Deliberately app-wide rather than scoped to the splash route: the gate runs
/// once at startup, and the screens that have to honour it — main, premium —
/// are mounted long after splash is gone.
final forceUpdateProvider =
    NotifierProvider<ForceUpdateNotifier, ForceUpdateState>(
      ForceUpdateNotifier.new,
    );
