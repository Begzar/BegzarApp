import 'package:begzar/core/domain/errors/failure.dart';
import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';

/// Everything that can go wrong while asking where the internet thinks we are.
///
/// Sealed, so this module can switch over the family exhaustively, and a
/// [Failure], so the layers above read [userFacingKey] off it through the same
/// call they use for an API or a connection failure.
///
/// Being disconnected is deliberately *not* in this family. A tunnel that is
/// down is the app at rest, not the app broken; the service answers `null` for
/// it and nothing here describes it.
sealed class IpInfoFailure implements Failure {
  const IpInfoFailure(this.message);

  /// Developer-facing detail. Never rendered — see [Failure.message].
  @override
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Begzar's own geo endpoint and every public provider behind it were asked,
/// none answered, and there was no cached reading to fall back on.
///
/// One variant covers all six sources on purpose. Each provider is tried
/// inside its own `catch` and the reason it failed is dropped there, so the
/// repository genuinely cannot say which one broke or why — splitting this
/// into per-source variants would be inventing detail nobody collected.
final class NoSourceAnsweredFailure extends IpInfoFailure {
  const NoSourceAnsweredFailure([
    super.message = 'No IP info source answered',
  ]);

  @override
  String get userFacingKey => UserFacingErrorKeys.locationUnavailable;
}
