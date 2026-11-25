import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// The app's failure for a backend operation that did not succeed.
///
/// The engine names which of the app's failures it was and carries the same
/// fields, so this only rebuilds it. [unexpectedKey] is what an unexpected
/// answer is shown as, which only the call site knows.
ApiFailure apiFailureFromBackend(
  BackendException e, {
  required String unexpectedKey,
}) => switch (e.kind) {
  BackendFailureKind.network => NetworkFailure(e.message),
  BackendFailureKind.engineMissing => EngineMissingFailure(e.message),
  BackendFailureKind.timeout => TimeoutFailure(e.message),
  BackendFailureKind.pinning => PinningFailure(e.message),
  BackendFailureKind.rateLimit => RateLimitFailure(
    e.message,
    retryAfterSeconds: e.retryAfterSeconds,
  ),
  BackendFailureKind.server => ServerFailure(
    e.message,
    statusCode: e.status,
    serverError: e.serverMessage,
    refusal: e.refusal,
  ),
  BackendFailureKind.payload => PayloadFailure(e.message),
  BackendFailureKind.noConfigs => NoConfigsFailure(e.message),
  BackendFailureKind.unexpected => UnexpectedFailure(
    e.message,
    userFacingKey: unexpectedKey,
    cause: e,
  ),
};
