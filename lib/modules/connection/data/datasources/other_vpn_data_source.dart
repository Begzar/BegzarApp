import 'dart:io';

import 'package:flutter/services.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// Asks the platform about other apps' VPNs, and turns one off where it can.
///
/// Every call can throw — a platform with no handler raises
/// [MissingPluginException] — and `ConnectionRepository` is what turns a throw
/// into an answer. This layer only knows which platform does what.
///
/// Built for Android, iOS and Windows. macOS is not released, and Linux has no
/// tunnel of its own to compete with, so both answer that no VPN is on.
class OtherVpnDataSource {
  const OtherVpnDataSource();

  static const _channel = MethodChannel('cloud.begzar.begzar/other_vpn');

  static bool get _supported =>
      Platform.isAndroid || Platform.isIOS || Platform.isWindows;

  /// Whether any VPN is up on the device. It cannot tell another app's from
  /// Begzar's own; the repository rules Begzar's out first.
  Future<bool> isVpnOn() async {
    if (!_supported) return false;
    return await _channel.invokeMethod<bool>('isVpnOn') ?? false;
  }

  /// Android and iOS make Begzar the device's VPN app, which takes the other
  /// one down where the platform allows it. Windows hangs up the VPN profiles
  /// from its own settings; a third-party VPN app is out of its reach.
  Future<void> turnOff() async {
    if (Platform.isWindows) {
      await _channel.invokeMethod<void>('turnOffVpn');
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      await BegzarEngine.ins.takeOverVpn();
    }
  }

  /// Opens the system page where VPNs are turned off. iOS has no public link
  /// to its VPN page, so it opens Begzar's own page in Settings, one level
  /// below it.
  Future<bool> openVpnSettings() async {
    if (!_supported) return false;
    return await _channel.invokeMethod<bool>('openVpnSettings') ?? false;
  }
}
