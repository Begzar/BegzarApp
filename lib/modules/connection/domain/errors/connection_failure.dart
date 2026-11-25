import 'package:begzar/core/domain/errors/failure.dart';
import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';

/// Everything that can go wrong while dialling a tunnel.
///
/// Sealed, so this module can switch over the family exhaustively, and a
/// [Failure], so the layers above read [userFacingKey] off it through the same
/// call they use for an API failure. A failure still describes what went wrong
/// rather than how to say it — the key is a key, and turning it into a sentence
/// stays in presentation.
///
/// Also an [Exception] because some variants genuinely cross a throw boundary.
/// The data sources under the repository have no `Either` to return: the
/// platform adapter throws [VpnPermissionFailure] when the VPN permission is
/// refused, and the Windows tunnel helper throws [ElevationDeclinedFailure] or
/// a [TunnelFailure] when its tunnel will not start. The repository turns each
/// straight back into a left, and nothing above it catches one.
sealed class ConnectionFailure implements Failure, Exception {
  const ConnectionFailure(this.message);

  /// Developer-facing detail. Never rendered — see [Failure.message].
  @override
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The engine cannot dial this config's scheme, so there is nothing to test.
///
/// Deliberately does not keep the config URL: it carries the server's
/// credentials, and a failure object outlives the call that made it.
final class InvalidConfigFailure extends ConnectionFailure {
  const InvalidConfigFailure([super.message = 'Invalid proxy configuration']);

  @override
  String get userFacingKey => UserFacingErrorKeys.invalidConfig;
}

/// The config was dialable but failed its live connectivity test.
final class ProxyTestFailure extends ConnectionFailure {
  const ProxyTestFailure([super.message = 'Proxy test failed']);

  @override
  String get userFacingKey => UserFacingErrorKeys.proxyTestFailed;
}

/// Every config on offer was tried and none of them passed.
///
/// [attemptedConfigs] is zero when the server returned nothing at all, which
/// is a different problem with the same outcome.
final class NoWorkingConfigFailure extends ConnectionFailure {
  const NoWorkingConfigFailure(this.attemptedConfigs, super.message);

  final int attemptedConfigs;

  @override
  String get userFacingKey => UserFacingErrorKeys.noWorkingConfig;
}

/// The system refused to prepare or install the VPN profile.
///
/// Reported as it is rather than retried with another config: no config can
/// succeed while the profile is refused.
final class VpnPermissionFailure extends ConnectionFailure {
  const VpnPermissionFailure([super.message = 'VPN permission denied']);

  @override
  String get userFacingKey => UserFacingErrorKeys.accessDenied;
}

/// The user declined the Windows admin prompt that tunnel mode needs.
///
/// Not a [VpnPermissionFailure]: that one reads as access denied and sends the
/// user to sign in again, when what is left to them is allowing the prompt or
/// choosing System proxy instead.
final class ElevationDeclinedFailure extends ConnectionFailure {
  const ElevationDeclinedFailure([
    super.message = 'Administrator permission declined',
  ]);

  @override
  String get userFacingKey => UserFacingErrorKeys.elevationDeclined;
}

/// The tunnel could not be brought up or taken down.
///
/// This is the one variant wrapping a throw from the engine, which reports its
/// failures as prose. That prose is resolved to a key once, at the boundary
/// that catches it, so no layer above has to sniff strings a second time.
final class TunnelFailure extends ConnectionFailure {
  const TunnelFailure(super.message, {required this.userFacingKey});

  @override
  final String userFacingKey;
}

/// The engine log could not be read or cleared: the engine did not answer.
///
/// Only the log viewer meets this, and it keeps the lines it already holds.
final class EngineLogReadFailure extends ConnectionFailure {
  const EngineLogReadFailure(super.message);

  @override
  String get userFacingKey => UserFacingErrorKeys.engineLogUnavailable;
}

/// The engine log could not be written out for the user to keep.
final class EngineLogExportFailure extends ConnectionFailure {
  const EngineLogExportFailure(super.message);

  @override
  String get userFacingKey => UserFacingErrorKeys.noStorageAccess;
}
