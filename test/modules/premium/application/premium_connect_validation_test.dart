import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/entities/premium_user_data.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/domain/premium_connect_validation.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';

import '../../../support/memory_keyed_storage.dart';

/// Signs in with [loginAccount], then answers every later `fetchUserData`
/// with [serverAccount] (or [serverFailure]), so a test can make the server
/// disagree with what the app has stored.
///
/// [serverThrow] is the third answer: not a failure the call reported, but one
/// it never got to report. Nothing between here and the gate catches it, so it
/// arrives as a throw rather than as a `Left`.
class _ScriptedPremiumRemoteDataSource extends PremiumRemoteDataSource {
  _ScriptedPremiumRemoteDataSource({
    required this.loginAccount,
    this.serverAccount,
    this.serverFailure,
    this.serverThrow,
  });

  final PremiumAccount loginAccount;
  final PremiumAccount? serverAccount;
  final ApiFailure? serverFailure;
  final Object? serverThrow;

  @override
  Future<Either<ApiFailure, PremiumSession>> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    return Right(
      PremiumSession(accessKey: 'access-key', account: loginAccount),
    );
  }

  @override
  Future<Either<ApiFailure, PremiumUserData>> fetchUserData(
    String accessKey,
  ) async {
    final thrown = serverThrow;
    if (thrown != null) throw thrown;

    final failure = serverFailure;
    if (failure != null) return Left(failure);
    return Right(
      PremiumUserData(
        account: serverAccount ?? loginAccount,
        devices: const LinkedDevices(
          maxDevices: 1,
          activeDevices: 1,
          devices: [
            PremiumDevice(deviceId: testDeviceId, deviceName: 'This phone'),
          ],
        ),
      ),
    );
  }
}

String _activeExpiry() =>
    DateTime.now().add(const Duration(days: 30)).toIso8601String();

String _lapsedExpiry() =>
    DateTime.now().subtract(const Duration(days: 1)).toIso8601String();

PremiumAccount _account({required String expireDate, String? statusLabel}) =>
    PremiumAccount(
      username: 'user',
      expireDate: expireDate,
      statusLabel: statusLabel,
    );

Future<ProviderContainer> _settledContainer(
  _ScriptedPremiumRemoteDataSource api,
) async {
  final container = ProviderContainer(
    overrides: [
      flutterSecureStorageProvider.overrideWithValue(storageWithDeviceId()),
      premiumRemoteDataSourceProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);

  for (
    var i = 0;
    i < 20 && container.read(premiumProvider) is PremiumRestoring;
    i++
  ) {
    await Future<void>.delayed(Duration.zero);
  }
  return container;
}

void main() {
  test('free mode: a signed-out user skips the premium gate', () async {
    final container = await _settledContainer(
      _ScriptedPremiumRemoteDataSource(
        loginAccount: _account(expireDate: _activeExpiry()),
      ),
    );

    final validation = await container
        .read(premiumProvider.notifier)
        .validateBeforeConnect();

    expect(validation, PremiumConnectValidation.skipped);
    expect(container.read(premiumProvider).isEntitled, isFalse);
  });

  test('free mode: a lapsed subscription skips the premium gate', () async {
    final container = await _settledContainer(
      _ScriptedPremiumRemoteDataSource(
        loginAccount: _account(
          expireDate: _lapsedExpiry(),
          statusLabel: 'true',
        ),
      ),
    );
    await container.read(premiumProvider.notifier).login('user', 'password');

    final validation = await container
        .read(premiumProvider.notifier)
        .validateBeforeConnect();

    expect(validation, PremiumConnectValidation.skipped);
  });

  test('premium mode: an entitled account is allowed to connect', () async {
    final container = await _settledContainer(
      _ScriptedPremiumRemoteDataSource(
        loginAccount: _account(
          expireDate: _activeExpiry(),
          statusLabel: 'true',
        ),
      ),
    );
    await container.read(premiumProvider.notifier).login('user', 'password');

    final validation = await container
        .read(premiumProvider.notifier)
        .validateBeforeConnect();

    expect(validation, PremiumConnectValidation.allowed);
  });

  test(
    'premium mode: a subscription the server has since ended is rejected',
    () async {
      final container = await _settledContainer(
        _ScriptedPremiumRemoteDataSource(
          loginAccount: _account(
            expireDate: _activeExpiry(),
            statusLabel: 'true',
          ),
          serverAccount: _account(
            expireDate: _lapsedExpiry(),
            statusLabel: 'true',
          ),
        ),
      );
      await container.read(premiumProvider.notifier).login('user', 'password');
      expect(container.read(premiumProvider).isEntitled, isTrue);

      final validation = await container
          .read(premiumProvider.notifier)
          .validateBeforeConnect();

      expect(validation, PremiumConnectValidation.subscriptionExpired);
      expect(
        container.read(premiumProvider).isEntitled,
        isFalse,
        reason: 'the server answer must replace the stored one',
      );
    },
  );

  test(
    'premium mode: an account the server has disabled is rejected',
    () async {
      final container = await _settledContainer(
        _ScriptedPremiumRemoteDataSource(
          loginAccount: _account(
            expireDate: _activeExpiry(),
            statusLabel: 'true',
          ),
          serverAccount: _account(
            expireDate: _activeExpiry(),
            statusLabel: 'disabled',
          ),
        ),
      );
      await container.read(premiumProvider.notifier).login('user', 'password');

      final validation = await container
          .read(premiumProvider.notifier)
          .validateBeforeConnect();

      expect(validation, PremiumConnectValidation.accountInactive);
      expect(container.read(premiumProvider).isEntitled, isFalse);
    },
  );

  test('premium mode: an unreachable server reports a failed check', () async {
    final container = await _settledContainer(
      _ScriptedPremiumRemoteDataSource(
        loginAccount: _account(
          expireDate: _activeExpiry(),
          statusLabel: 'true',
        ),
        serverFailure: const NetworkFailure('offline'),
      ),
    );
    await container.read(premiumProvider.notifier).login('user', 'password');

    final validation = await container
        .read(premiumProvider.notifier)
        .validateBeforeConnect();

    expect(validation, PremiumConnectValidation.checkFailed);
    expect(
      container.read(premiumProvider).errorMessage,
      isNotNull,
      reason: 'the UI shows this in the top error popup',
    );
    expect(
      container.read(premiumProvider).isEntitled,
      isTrue,
      reason: 'a failed check must not silently downgrade the account',
    );
  });

  test('premium mode: a check that threw still names a reason', () async {
    final container = await _settledContainer(
      _ScriptedPremiumRemoteDataSource(
        loginAccount: _account(
          expireDate: _activeExpiry(),
          statusLabel: 'true',
        ),
        serverThrow: Exception('Failed host lookup'),
      ),
    );
    await container.read(premiumProvider.notifier).login('user', 'password');

    final validation = await container
        .read(premiumProvider.notifier)
        .validateBeforeConnect();

    expect(validation, PremiumConnectValidation.checkFailed);
    expect(
      container.read(premiumProvider).errorMessage,
      UserFacingErrorKeys.networkError,
      reason:
          'the throw used to be swallowed whole, so the refusal was '
          'reported with whatever the last premium failure had been — or, on '
          'a session that had never failed at anything, with nothing at all',
    );
    expect(
      container.read(premiumProvider).isEntitled,
      isTrue,
      reason: 'a check that never completed says nothing about the account',
    );
  });
}
