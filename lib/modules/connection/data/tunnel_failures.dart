import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';

/// Wraps a throw from the proxy engine as a [TunnelFailure].
///
/// The engine reports its failures as prose — `Exception('Failed to start VPN
/// mode: …')` and friends — so the only way to tell a host-lookup failure from
/// a refused permission is to read the text. That reading happens once, here,
/// at the boundary where the prose arrives, and the result travels as a key.
/// Layers above ask the failure for [TunnelFailure.userFacingKey] and never see
/// the string.
///
/// [what] names the operation for the log; [cause] is the original throw and is
/// never shown to anyone, since engine text can carry an address or a URL.
TunnelFailure tunnelFailure(String what, Object cause) => TunnelFailure(
  '$what: $cause',
  userFacingKey: resolveUserFacingErrorKey(cause),
);

/// What each platform says, lowercased, when it refuses the VPN permission.
///
/// Android's plugin answers `VPN_PERMISSION_DENIED`; Apple reports an
/// `NEVPNErrorDomain` error or a failed prepare when the profile cannot be
/// installed.
const List<String> _vpnPermissionRefusalMarkers = [
  'permission denied',
  'vpn_permission_denied',
  'prepare_failed',
  'nevpnerror',
  'configuration invalid',
];

/// Whether [cause] is the system refusing the VPN permission, which no other
/// config or retry can get past.
///
/// Read from the text for the same reason as [tunnelFailure]: the refusal
/// arrives as a platform error, and the adapter turns it into a
/// `VpnPermissionFailure` the moment it is recognised.
bool isVpnPermissionRefusal(Object cause) {
  final text = cause.toString().toLowerCase();
  return _vpnPermissionRefusalMarkers.any(text.contains);
}
