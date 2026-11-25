import 'package:begzar/main.dart' show runBegzar;
import 'package:begzar/modules/app_update/data/repositories/app_version_repository.dart';
import 'package:begzar/modules/app_update/presentation/controllers/startup_update_gate.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/data/datasources/premium_storage.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';

import 'fake_google_play_billing.dart';
import 'fake_premium_backend.dart';
import 'fake_run_storage.dart';

/// Set with `--dart-define=FAKE_GOOGLE_PLAY=true`.
const _fakeGooglePlay = bool.fromEnvironment('FAKE_GOOGLE_PLAY');

/// Runs the app with every premium call answered by [FakePremiumBackend]:
///
///     flutter run -d <device> -t tool/fake_backend/main.dart
///
/// The premium session lives in memory with it, so the device's real stored
/// session is left untouched. The version check is answered by it too, and
/// offers [FakePremiumBackend.latestVersion] on every channel so the update
/// row shows. Everything else — the free tier, ads — still talks to the real
/// servers.
///
/// A Play build (`--dart-define=DISTRIBUTION_SOURCE=google_play`) buys through
/// the real Play, which prices the plans Play Console holds and sells to a
/// debug build only for a Google account that is a license tester. With
/// [_fakeGooglePlay] set it buys through [FakeGooglePlayBilling] instead, for
/// a device without one. Other builds never ask for billing.
Future<void> main() {
  final backend = FakePremiumBackend();
  return runBegzar(
    overrides: [
      premiumRemoteDataSourceProvider.overrideWithValue(
        PremiumRemoteDataSource(backend: backend),
      ),
      premiumStorageProvider.overrideWithValue(
        PremiumStorage(storage: FakeRunStorage()),
      ),
      if (_fakeGooglePlay)
        googlePlayBillingDataSourceProvider.overrideWithValue(
          FakeGooglePlayBilling(),
        ),
      startupUpdateGateProvider.overrideWith(
        (ref) => StartupUpdateGate(
          ref,
          repository: AppVersionRepository(backend: backend),
        ),
      ),
    ],
  );
}
