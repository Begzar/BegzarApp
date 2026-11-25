import 'package:begzar/core/domain/errors/failure.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendRefusal;

/// Typed failure for Begzar API calls (free tier and premium).
///
/// Services return `Either<ApiFailure, T>` instead of throwing, so callers
/// can tell a pin mismatch from a timeout from a server rejection. The family
/// is sealed so this module can switch over it exhaustively; [Failure] is what
/// the layers above hold, so presentation can read a key off an API failure
/// and a connection failure through the same call.
sealed class ApiFailure implements Failure {
  const ApiFailure(this.message);

  @override
  final String message;

  /// Stable l10n key for this failure (see [UserFacingErrorKeys]).
  ///
  /// Deliberately left abstract. There was once a default here that ran
  /// [resolveUserFacingErrorKey] over [message], which made a developer log
  /// line decide a user's sentence and let a new variant inherit that quietly.
  /// A variant that cannot name one constant carries the key instead, the way
  /// [UnexpectedFailure] does.
  @override
  String get userFacingKey;

  @override
  String toString() => message;
}

/// Transport-level failure with no HTTP response (DNS, socket, cancel).
///
/// Reached only once a status code and a timeout have both been ruled out, so
/// every variant of it is the same thing to a user: the request never made it
/// off the device. The message carries the host that could not be reached and
/// is for logs only.
final class NetworkFailure extends ApiFailure {
  const NetworkFailure([super.message = 'Network error']);

  @override
  String get userFacingKey => UserFacingErrorKeys.networkError;
}

/// Connect/send/receive timeout.
final class TimeoutFailure extends ApiFailure {
  const TimeoutFailure([super.message = 'Connection timed out']);

  @override
  String get userFacingKey => UserFacingErrorKeys.connectionTimeout;
}

/// TLS SPKI pin validation rejected the connection.
final class PinningFailure extends ApiFailure {
  const PinningFailure([
    super.message = 'Secure connection failed (certificate pin mismatch)',
  ]);

  @override
  String get userFacingKey => UserFacingErrorKeys.secureConnectionFailed;
}

/// HTTP 429 — request quota exhausted.
final class RateLimitFailure extends ApiFailure {
  const RateLimitFailure(super.message, {this.retryAfterSeconds});

  final int? retryAfterSeconds;

  @override
  String get userFacingKey => UserFacingErrorKeys.rateLimit;
}

/// No usable session/credentials (registration failed, premium session gone).
final class SessionFailure extends ApiFailure {
  const SessionFailure(super.message);

  @override
  String get userFacingKey => UserFacingErrorKeys.sessionNotFound;
}

/// The server no longer registers this device against the subscription.
///
/// Distinct from [SessionFailure], which is a credential the app never had or
/// has already dropped. This one is a credential the app still holds and the
/// server has stopped honouring — a seat freed from another device, or by
/// support — so the session is ended locally rather than retried.
final class SessionRevokedFailure extends ApiFailure {
  const SessionRevokedFailure([
    super.message = 'Device is no longer registered on the account',
  ]);

  @override
  String get userFacingKey => UserFacingErrorKeys.deviceRemoved;
}

/// Server replied with an error status or a non-ok result body.
final class ServerFailure extends ApiFailure {
  const ServerFailure(
    super.message, {
    this.statusCode,
    this.serverError,
    this.refusal,
  });

  final int? statusCode;
  final String? serverError;

  /// Which of the backend's known refusals this was, as the engine named it.
  final BackendRefusal? refusal;

  @override
  String get userFacingKey => serverFailureKey(
    statusCode: statusCode,
    serverError: serverError,
    message: message,
    refusal: refusal,
  );
}

/// The answer could not be opened: malformed, or sealed under another key.
///
/// The server answered and the transport was fine, so from the user's side
/// this is a server list that would not load — not a server that would not
/// answer, and not a server that was tried and failed.
final class PayloadFailure extends ApiFailure {
  const PayloadFailure(super.message);

  @override
  String get userFacingKey => UserFacingErrorKeys.fetchConfigsFailed;
}

/// The call succeeded but produced no usable configurations.
final class NoConfigsFailure extends ApiFailure {
  const NoConfigsFailure(super.message);

  @override
  String get userFacingKey => UserFacingErrorKeys.noConfigsFromServer;
}

/// This build does not carry the proxy engine, which makes every backend
/// call: it was built on the open stand-in. Nothing was asked of anyone, so
/// this is neither a network failure nor the server's answer.
final class EngineMissingFailure extends ApiFailure {
  const EngineMissingFailure([
    super.message = 'The proxy engine is not part of this build',
  ]);

  @override
  String get userFacingKey => UserFacingErrorKeys.engineMissing;
}

/// Anything not covered above; [cause] keeps the original error for logs.
///
/// The one variant that cannot answer a constant: it is what a `catch (e)`
/// produces, so the throw it wraps could be anything and the only thing known
/// for certain is which call was being made. That is what [userFacingKey]
/// names, and the call site is the only place that knows it — same shape as
/// `TunnelFailure` on the connection side.
final class UnexpectedFailure extends ApiFailure {
  const UnexpectedFailure(
    super.message, {
    required this.userFacingKey,
    this.cause,
  });

  @override
  final String userFacingKey;

  final Object? cause;
}
