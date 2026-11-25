import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/premium/data/repositories/premium_repository.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/premium_connect_validation.dart';
import 'package:begzar/modules/premium/domain/premium_credentials.dart';
import 'package:begzar/modules/premium/domain/sign_up.dart';
import 'package:fpdart/fpdart.dart';

/// What a pre-connect entitlement check found.
///
/// It carries the account as well as the verdict because the caller has to do
/// two things with one answer: decide whether to connect, and publish what the
/// server just said so the subscription card stops disagreeing with it.
class EntitlementCheck {
  const EntitlementCheck._({required this.verdict, this.account, this.failure});

  final PremiumConnectValidation verdict;

  /// The account the server reported, or null when it did not answer.
  final PremiumAccount? account;

  /// Why the check did not complete, or null when it did.
  final ApiFailure? failure;
}

/// Everything the app does with a premium account: the session it holds, the
/// entitlement it grants, and the devices registered against it.
///
/// Session and devices sit together because they are the same subscription
/// seen from two sides — signing out is what frees a seat, and the device list
/// is only meaningful while a session exists.
class PremiumAccountService {
  const PremiumAccountService(this._repository);

  final PremiumRepository _repository;

  /// The stored session, or null when nobody is signed in.
  Future<PremiumSession?> restoreSession() => _repository.readSession();

  /// Credentials are a parsed type rather than two strings, so a blank
  /// username can never reach the network from here.
  Future<Either<ApiFailure, PremiumSession>> signIn(
    PremiumCredentials credentials,
  ) => _repository.signIn(
    username: credentials.username,
    password: credentials.password,
  );

  /// Takes parsed details for the same reason [signIn] takes credentials: an
  /// address that is not one never costs a request.
  Future<Either<ApiFailure, Duration>> signUp(SignUpDetails details) =>
      _repository.signUp(email: details.email, password: details.password);

  Future<Either<ApiFailure, Duration>> resendSignUpCode(String email) =>
      _repository.resendSignUpCode(email);

  Future<Either<ApiFailure, PremiumSession>> verifySignUp({
    required String email,
    required String code,
  }) => _repository.verifySignUp(email: email, code: code);

  Future<Either<ApiFailure, Unit>> deleteAccount(String password) =>
      _repository.deleteAccount(password);

  /// Re-reads the account from the server. Null means there was no stored
  /// credential to ask with, which is not the same as a failed call.
  ///
  /// The same answer carries the device roster; [fetchDevices] is the side of
  /// it this service's other caller wants.
  Future<Either<ApiFailure, PremiumAccount>?> refreshAccount() async {
    final result = await _repository.refreshAccount();
    return result?.map((userData) => userData.account);
  }

  /// Asks the server whether premium may be used right now.
  ///
  /// Always a round trip: entitlement is the server's to decide, so a stored
  /// account that still looks valid is never enough. A call that does not
  /// complete reports [PremiumConnectValidation.checkFailed] rather than
  /// falling through to allowed.
  Future<EntitlementCheck> checkEntitlement() async {
    final result = await _repository.refreshAccount();
    return switch (result) {
      null => const EntitlementCheck._(
        verdict: PremiumConnectValidation.notLoggedIn,
      ),
      Left(value: final failure) => EntitlementCheck._(
        verdict: PremiumConnectValidation.checkFailed,
        failure: failure,
      ),
      Right(value: final userData) => EntitlementCheck._(
        verdict: PremiumConnectValidation.forAccount(userData.account),
        account: userData.account,
      ),
    };
  }

  Future<void> signOut() => _repository.signOut();

  /// The devices registered against the subscription.
  ///
  /// Read out of the account refresh rather than asked for on its own:
  /// the account already carries the roster, so asking for the devices on
  /// their own was a second request for a list the server had just sent.
  Future<Either<ApiFailure, LinkedDevices>> fetchDevices() async {
    final result = await _repository.refreshAccount();
    return result?.map((userData) => userData.devices) ??
        left(PremiumRepository.sessionMissingFailure);
  }

  Future<Either<ApiFailure, int>> removeDevice(String deviceId) =>
      _repository.removeDevice(deviceId);

  /// This install's identifier, so the device list can mark its own row.
  Future<String> currentDeviceId() => _repository.deviceId();
}
