import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/log/log.dart';
import 'package:begzar/modules/premium/data/datasources/premium_ping_data_source.dart';
import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/data/datasources/premium_storage.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/entities/premium_user_data.dart';
import 'package:fpdart/fpdart.dart';

/// The premium module's one door to stored and remote data.
///
/// It exists because almost every premium call is remote *and* local: the
/// server wants the stored access key, and what comes back has to be written
/// back down. That pairing used to be split between the API client (which
/// read the session itself) and the notifiers (which persisted the result),
/// so "am I signed in" was answered in two layers at once.
class PremiumRepository {
  PremiumRepository({
    required PremiumRemoteDataSource remote,
    required PremiumStorage storage,
    PremiumPingDataSource? ping,
  }) : _remote = remote,
       _storage = storage,
       _ping = ping ?? PremiumPingDataSource();

  /// Returned when a call needs a credential and nothing is stored. The
  /// message is the one the premium UI has always shown for this case.
  static const sessionMissingFailure = SessionFailure(
    'Premium session not found. Please sign in again.',
  );

  static const _log = Log('premium');

  final PremiumRemoteDataSource _remote;
  final PremiumStorage _storage;
  final PremiumPingDataSource _ping;

  Future<PremiumSession?> readSession() => _storage.readSession();

  /// Signs in and persists the session, so a restart resumes it.
  Future<Either<ApiFailure, PremiumSession>> signIn({
    required String username,
    required String password,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final result = await _remote.login(
      username: username,
      password: password,
      deviceId: deviceId,
    );

    if (result case Right(value: final session)) {
      await _storage.saveSession(session);
    }
    return result;
  }

  /// Asks for a confirmation code for a new account, answering with how long
  /// to wait before another may be asked for.
  Future<Either<ApiFailure, Duration>> signUp({
    required String email,
    required String password,
  }) => _remote.signUp(email: email, password: password);

  Future<Either<ApiFailure, Duration>> resendSignUpCode(String email) =>
      _remote.resendSignUpCode(email: email);

  /// Confirms a new account and persists the session it opens, as [signIn]
  /// does: a confirmed sign-up is a sign-in on this device.
  Future<Either<ApiFailure, PremiumSession>> verifySignUp({
    required String email,
    required String code,
  }) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final result = await _remote.verifySignUp(
      email: email,
      code: code,
      deviceId: deviceId,
    );

    if (result case Right(value: final session)) {
      await _storage.saveSession(session);
    }
    return result;
  }

  /// Deletes the account on the server, then forgets the session here. A
  /// refusal leaves the session where it is, because the account still is.
  ///
  /// Unlike [signOut], clearing is best effort once the server has answered:
  /// the account is gone whatever the keystore does, and a session left on
  /// disk is refused on its next use and signs out then. Reporting a failure
  /// would tell the user the opposite of what happened.
  Future<Either<ApiFailure, Unit>> deleteAccount(String password) =>
      _withAccessKey((accessKey) async {
        final deviceId = await _storage.getOrCreateDeviceId();
        final result = await _remote.deleteAccount(
          accessKey: accessKey,
          deviceId: deviceId,
          password: password,
        );
        if (result.isLeft()) return result;

        try {
          await _storage.clearSession();
        } catch (error) {
          _log.warn('account.delete.clear.failed', {'type': error.runtimeType});
        }
        return result;
      });

  /// Reports a Play purchase for the signed-in account, from this device.
  ///
  /// A grant sets aside any refresh already in flight: it was sent before
  /// the grant and answers with the account before it, so the next caller
  /// asks afresh rather than sharing it.
  Future<Either<ApiFailure, Unit>> reportGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
  }) => _withAccessKey((accessKey) async {
    final deviceId = await _storage.getOrCreateDeviceId();
    final result = await _remote.reportGooglePlayPurchase(
      accessKey: accessKey,
      deviceId: deviceId,
      productId: productId,
      purchaseToken: purchaseToken,
    );
    if (result.isRight()) _refreshInFlight = null;
    return result;
  });

  /// The refresh currently in flight, or null when none is.
  ///
  /// Opening the premium screen asks for this answer twice within a few
  /// milliseconds — the subscription card wants the account and the device
  /// list wants the roster, and one response carries both. Without this they
  /// were two identical signed requests, which is exactly the waste that
  /// reading the roster out of the account was meant to end.
  Future<Either<ApiFailure, PremiumUserData>?>? _refreshInFlight;

  /// Re-reads the account from the server and writes it back down.
  ///
  /// What comes back carries the device roster as well, because the endpoint
  /// sends both; `PremiumAccountService.fetchDevices` reads it from here
  /// rather than making a second signed request for the same list.
  ///
  /// Callers that arrive while a refresh is running share its answer. That is
  /// not a cache: the moment the call settles the next caller starts a fresh
  /// round trip, because entitlement is the server's to decide and a stored
  /// answer is never good enough.
  ///
  /// Null means there was no stored credential to ask with — a different
  /// answer from a failed call, and the caller treats it differently.
  ///
  /// A roster that no longer registers this device ends the session here:
  /// storage is cleared and the answer is [SessionRevokedFailure], so every
  /// caller of this — the launch refresh, the pre-connect check, the device
  /// list — learns about a seat freed elsewhere from the one place that asks.
  /// The server has already dropped the registration, so no logout is sent.
  Future<Either<ApiFailure, PremiumUserData>?> refreshAccount() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    late final Future<Either<ApiFailure, PremiumUserData>?> request;
    request = _refreshAccount().whenComplete(() {
      // A grant may have set this one aside for a fresher one, which is not
      // this one's to clear.
      if (identical(_refreshInFlight, request)) _refreshInFlight = null;
    });
    return _refreshInFlight = request;
  }

  Future<Either<ApiFailure, PremiumUserData>?> _refreshAccount() async {
    final session = await _storage.readSession();
    if (session == null) return null;

    final result = await _remote.fetchUserData(session.accessKey);
    if (result case Right(value: final userData)) {
      final deviceId = await _storage.getOrCreateDeviceId();
      if (!userData.devices.registers(deviceId)) {
        await _storage.clearSession();
        return left(const SessionRevokedFailure());
      }
      await _storage.saveSession(session.copyWith(account: userData.account));
    }
    return result;
  }

  /// Ends the session locally, whatever the server says.
  ///
  /// The remote call is best effort: a user who cannot reach the server must
  /// still be able to sign out of their own device. Clearing storage is not
  /// best effort — if that throws, the caller has to know the session is
  /// still on disk, so the throw is left to propagate.
  Future<void> signOut() async {
    final session = await _storage.readSession();
    if (session != null) {
      final deviceId = await _storage.getOrCreateDeviceId();
      await _remote.logout(accessKey: session.accessKey, deviceId: deviceId);
    }
    await _storage.clearSession();
  }

  Future<Either<ApiFailure, int>> removeDevice(String deviceId) =>
      _withAccessKey(
        (accessKey) =>
            _remote.removeDevice(accessKey: accessKey, deviceId: deviceId),
      );

  Future<Either<ApiFailure, List<PremiumServer>>> fetchServers() =>
      _withAccessKey(_remote.fetchServers);

  /// This install's identifier, generated on first use.
  Future<String> deviceId() => _storage.getOrCreateDeviceId();

  Future<({int serverId, int configId})?> readLastConnected() =>
      _storage.readLastConnected();

  Future<PremiumServerLabel?> readLastConnectedLabel() =>
      _storage.readLastConnectedLabel();

  Future<void> saveLastConnected({
    required int serverId,
    required int configId,
    required PremiumServerLabel label,
  }) => _storage.saveLastConnected(
    serverId: serverId,
    configId: configId,
    label: label,
  );

  /// Real-delay latencies for [configs], in the same order; null per failure.
  Future<List<int?>> measurePings(List<PremiumServerConfig> configs) =>
      _ping.measureBatch(configs);

  /// Runs [call] with the stored access key, or fails with
  /// [sessionMissingFailure] when there is none.
  Future<Either<ApiFailure, T>> _withAccessKey<T>(
    Future<Either<ApiFailure, T>> Function(String accessKey) call,
  ) async {
    final session = await _storage.readSession();
    if (session == null) return left(sessionMissingFailure);
    return call(session.accessKey);
  }
}
