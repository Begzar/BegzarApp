import 'dart:async';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendRefusal;
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/premium_connect_validation.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../../support/recording_analytics.dart';
import '../../premium_test_doubles.dart';

/// What the controller does with a session the server has already ended.
///
/// The roster that rides along with every account refresh is what reports it:
/// a device removed elsewhere stops being listed, and the repository answers
/// with [SessionRevokedFailure] instead of an account. That is not an error to
/// show on a premium screen — there is no session left to show one for.
void main() {
  group('a revoked session', () {
    test('should sign the user out when a refresh reports it', () async {
      final repository = FakePremiumRepository(session: _signedIn());
      final container = _container(repository);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      repository.refreshResult = left(const SessionRevokedFailure());
      await notifier.refreshSubscription(silent: true);

      expect(container.read(premiumProvider), isA<PremiumSignedOut>());
    });

    test('should say the device was removed from the account', () async {
      final repository = FakePremiumRepository(session: _signedIn());
      final container = _container(repository);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      repository.refreshResult = left(const SessionRevokedFailure());
      await notifier.refreshSubscription(silent: true);

      expect(
        container.read(premiumProvider).errorMessage,
        UserFacingErrorKeys.deviceRemoved,
      );
    });

    // The tunnel is dropped from the app shell, which needs the sign-out it
    // reacts to to be distinguishable from the one the user asked for.
    test('should mark the sign-out as the server ending it', () async {
      final repository = FakePremiumRepository(session: _signedIn());
      final container = _container(repository);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      repository.refreshResult = left(const SessionRevokedFailure());
      await notifier.refreshSubscription(silent: true);

      final state = container.read(premiumProvider);
      expect((state as PremiumSignedOut).isRevoked, isTrue);
    });

    test('should refuse the pre-connect check', () async {
      final repository = FakePremiumRepository(session: _signedIn());
      final container = _container(repository);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      repository.refreshResult = left(const SessionRevokedFailure());
      final verdict = await notifier.validateBeforeConnect();

      expect(verdict, PremiumConnectValidation.notLoggedIn);
      expect(container.read(premiumProvider), isA<PremiumSignedOut>());
    });
  });

  // Only a roster that named other devices ends a session. Everything else the
  // server can answer with leaves the stored one alone.
  test('should keep the session when a refresh merely fails', () async {
    final repository = FakePremiumRepository(session: _signedIn());
    final container = _container(repository);
    final notifier = container.read(premiumProvider.notifier);
    await _settleRestore(notifier);

    repository.refreshResult = left(const NetworkFailure());
    await notifier.refreshSubscription();

    expect(container.read(premiumProvider), isA<PremiumSignedIn>());
  });

  test('should leave a user-initiated sign-out unmarked', () async {
    final container = _container(FakePremiumRepository(session: _signedIn()));
    final notifier = container.read(premiumProvider.notifier);
    await _settleRestore(notifier);

    await notifier.logout();

    final state = container.read(premiumProvider);
    expect((state as PremiumSignedOut).isRevoked, isFalse);
  });

  group('PremiumNotifier.deleteAccount', () {
    // The shell drops the tunnel on a sign-out the server ended. A deleted
    // account has nothing left behind the premium servers it dialled.
    test('should end the session as one the server ended', () async {
      final container = _container(FakePremiumRepository(session: _signedIn()));
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      final refusal = await notifier.deleteAccount('secret-password');

      final state = container.read(premiumProvider);
      expect(refusal, isNull);
      expect((state as PremiumSignedOut).isRevoked, isTrue);
    });

    test('should return the reason and stay signed in when refused', () async {
      final repository = FakePremiumRepository(
        session: _signedIn(),
        deleteResult: left(
          const ServerFailure(
            'invalid_password',
            serverError: 'invalid_password',
            refusal: BackendRefusal.wrongPassword,
          ),
        ),
      );
      final container = _container(repository);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      final refusal = await notifier.deleteAccount('wrong-password');

      expect(refusal, UserFacingErrorKeys.wrongPassword);
      expect(container.read(premiumProvider), isA<PremiumSignedIn>());
    });

    test('should refuse an empty password without asking the server', () async {
      final repository = FakePremiumRepository(session: _signedIn());
      final container = _container(repository);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      final refusal = await notifier.deleteAccount('');

      expect(refusal, UserFacingErrorKeys.passwordRequired);
      expect(repository.deleteCount, 0);
    });
  });

  group('PremiumNotifier.adoptSignedUpAccount', () {
    test('should publish the new account as signed in', () async {
      final container = _container(FakePremiumRepository());
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);
      const account = PremiumAccount(username: 'reader@example.com');

      notifier.adoptSignedUpAccount(account);

      final state = container.read(premiumProvider);
      expect(state, isA<PremiumSignedIn>());
      expect(state.account, account);
    });
  });

  group('PremiumNotifier.refreshSubscription', () {
    // The refresh a granted purchase asks for has to win over one the launch
    // started before the grant, whichever answer comes back last.
    test('should not publish an older answer over a newer one', () async {
      final repository = FakePremiumRepository(session: _signedIn());
      final container = _container(repository);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);
      const older = PremiumAccount(username: 'user', statusLabel: 'true');
      final newer = _signedIn().account;
      final gate = Completer<void>();
      repository
        ..refreshGates.add(gate)
        ..refreshResult = right(older);

      final first = notifier.refreshSubscription(silent: true);
      repository.refreshResult = right(newer);
      await notifier.refreshSubscription(silent: true);
      gate.complete();
      await first;

      expect(container.read(premiumProvider).account, newer);
    });
  });

  group('what analytics is told', () {
    test('should record a sign-in that went through', () async {
      final analytics = RecordingAnalytics();
      final repository = FakePremiumRepository(
        signInResult: right(_signedIn()),
      );
      final container = _container(repository, analytics: analytics);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      await notifier.login('user', 'secret-password');

      expect(analytics.callsTo(#logLogin), hasLength(1));
    });

    test('should record nothing for a sign-in that was refused', () async {
      final analytics = RecordingAnalytics();
      final repository = FakePremiumRepository(
        signInResult: left(const NetworkFailure()),
      );
      final container = _container(repository, analytics: analytics);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      await notifier.login('user', 'secret-password');

      expect(analytics.callsTo(#logLogin), isEmpty);
    });

    test('should record a confirmed sign-up', () async {
      final analytics = RecordingAnalytics();
      final container = _container(
        FakePremiumRepository(),
        analytics: analytics,
      );
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      notifier.adoptSignedUpAccount(
        const PremiumAccount(username: 'reader@example.com'),
      );

      expect(analytics.callsTo(#logSignUp), hasLength(1));
    });

    // The device list can be told a seat was freed after a refresh already
    // was; one seat taken away is one event.
    test('should record a seat the server took away once', () async {
      final analytics = RecordingAnalytics();
      final repository = FakePremiumRepository(session: _signedIn());
      final container = _container(repository, analytics: analytics);
      final notifier = container.read(premiumProvider.notifier);
      await _settleRestore(notifier);

      repository.refreshResult = left(const SessionRevokedFailure());
      await notifier.refreshSubscription(silent: true);
      notifier.endRevokedSession();

      expect(analytics.callsTo(#logPremiumRevoked), hasLength(1));
    });

    test(
      'should not record a sign-out the user asked for as revoked',
      () async {
        final analytics = RecordingAnalytics();
        final container = _container(
          FakePremiumRepository(session: _signedIn()),
          analytics: analytics,
        );
        final notifier = container.read(premiumProvider.notifier);
        await _settleRestore(notifier);

        await notifier.logout();

        expect(analytics.callsTo(#logPremiumRevoked), isEmpty);
      },
    );
  });
}

/// Waits out the launch restore and the background refresh that follows it, so
/// a test can script the next answer without racing the first one.
Future<void> _settleRestore(PremiumNotifier notifier) async {
  await notifier.ensureRestored();
  await notifier.refreshSubscription(silent: true);
  await Future<void>.delayed(Duration.zero);
}

ProviderContainer _container(
  FakePremiumRepository repository, {
  RecordingAnalytics? analytics,
}) {
  final container = ProviderContainer(
    overrides: [
      premiumRepositoryProvider.overrideWithValue(repository),
      analyticsServiceProvider.overrideWithValue(
        analytics ?? RecordingAnalytics(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

PremiumSession _signedIn() => PremiumSession(
  accessKey: 'access-key',
  account: PremiumAccount(
    username: 'user',
    expireDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    statusLabel: 'true',
  ),
);
