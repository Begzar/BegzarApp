import 'package:begzar/modules/app_update/data/repositories/app_version_repository.dart';
import 'package:begzar/modules/app_update/domain/app_version_gate.dart';
import 'package:begzar/modules/app_update/presentation/controllers/available_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/controllers/force_update_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this build may go on to the app.
enum StartupUpdateVerdict {
  /// Nothing stands in the way.
  allowed,

  /// The installed build is too old. The versions and the update URL are on
  /// [forceUpdateProvider] by the time the verdict is returned, which is where
  /// the dialog reads them from.
  updateRequired,
}

/// The version check the app runs once at startup.
///
/// Nothing waits on it. A required update is announced through
/// [forceUpdateProvider], and the screen already listening on that raises the
/// dialog over whatever is on screen — so the check costs the user no time at
/// launch, which is why the app no longer holds a splash screen open for it.
///
/// Deliberately fail-open on everything except a definite "too old": a
/// network that will not answer, a malformed catalog or a request that runs
/// past the timeout all let the user into the app. The alternative is a
/// client that bricks itself whenever the catalog is unreachable, which is a
/// worse failure than running one build behind.
class StartupUpdateGate {
  StartupUpdateGate(this._ref, {AppVersionRepository? repository})
    : _repository = repository ?? AppVersionRepository();

  final Ref _ref;
  final AppVersionRepository _repository;

  /// Runs the check start to finish. The caller fires this and moves on.
  Future<StartupUpdateVerdict> run() =>
      evaluate(_repository.evaluateInstalledBuild());

  /// Resolves a started check, applying the timeout and the fail-open rule,
  /// and records a required update so the rest of the app can gate on it, or
  /// an optional one so the settings tab can offer it.
  Future<StartupUpdateVerdict> evaluate(
    Future<AppVersionGateResult> started,
  ) async {
    AppVersionGateResult gate;
    try {
      gate = await started.timeout(AppVersionRepository.requestTimeout);
    } catch (_) {
      gate = const AppVersionGateResult.allow();
    }

    if (!gate.isUpdateRequired) {
      final latestVersion = gate.latestVersion;
      final updateUrl = gate.updateUrl;
      if (latestVersion != null && updateUrl != null) {
        _ref
            .read(availableUpdateProvider.notifier)
            .publish(version: latestVersion, url: updateUrl);
      }
      return StartupUpdateVerdict.allowed;
    }

    _ref
        .read(forceUpdateProvider.notifier)
        .markRequired(
          currentVersion: gate.currentVersion,
          requiredVersion: gate.requiredVersion,
          updateUrl: gate.updateUrl,
        );
    return StartupUpdateVerdict.updateRequired;
  }
}

final startupUpdateGateProvider = Provider<StartupUpdateGate>(
  StartupUpdateGate.new,
);
