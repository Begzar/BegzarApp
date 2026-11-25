// The open engine stub's copy of the private engine's public model, with the
// wire conversions it has no use for removed. Keep it in step with the engine:
// scripts/check_engine_stub.sh fails when the app uses something it lacks.

// The tunnel descriptor only ever reached the wire.
// ignore_for_file: unused_field

import 'dart:io';
import 'package:begzar_engine/models/begzar_engine_exception.dart';
import 'package:begzar_engine/constants/engine_names.dart';

class BegzarEngineConfig {
  // The keys of the `startVPN` arguments map. Kotlin reads them through its
  // `ARGUMENT_EXCLUDED_PACKAGES` and `ARGUMENT_ALLOWED_PACKAGES` constants, so
  // a key changes on both sides or on neither.
  static const _excludedPackagesArgument = 'excludedPackages';
  static const _allowedPackagesArgument = 'allowedPackages';

  final EngineNames engine;
  final String dir;
  final String config;
  final int memory;
  final bool isString;
  final int tunnelPort;
  final bool _shieldMode;
  late final int? _tunnelDescriptorId;
  final List<String> excludedPackages;
  final List<String> allowedPackages;

  /// Whether the engine binds its outbound connections to the interface that
  /// carries the system's default route, so they stay out of a tunnel in front
  /// of it. Only relay mode sets it.
  final bool bindPhysicalInterface;

  BegzarEngineConfig.inRelayMode({
    this.engine = EngineNames.xray,
    required this.dir,
    required this.config,
    this.memory = 128,
    this.isString = true,
    this.tunnelPort = 2080,
    this.excludedPackages = const [],
    this.allowedPackages = const [],
    this.bindPhysicalInterface = false,
  })  : _shieldMode = false,
        _tunnelDescriptorId = null {
    if (Platform.isIOS || Platform.isMacOS) {
      throw BegzarEngineException('Relay Mode is not supported on iOS/macOS');
    }
  }

  BegzarEngineConfig.inShieldMode({
    this.engine = EngineNames.xray,
    required this.dir,
    required this.config,
    this.memory = 128,
    this.isString = true,
    this.tunnelPort = 2080,
    this.excludedPackages = const [],
    this.allowedPackages = const [],
  })  : _shieldMode = true,
        bindPhysicalInterface = false;

  @Deprecated('Use inRelayMode instead')
  BegzarEngineConfig.inTunnelMode({
    this.engine = EngineNames.xray,
    required this.dir,
    required this.config,
    this.memory = 128,
    this.isString = true,
    this.tunnelPort = 2080,
    this.excludedPackages = const [],
    this.allowedPackages = const [],
  })  : _shieldMode = false,
        _tunnelDescriptorId = null,
        bindPhysicalInterface = false {
    if (Platform.isIOS || Platform.isMacOS) {
      throw BegzarEngineException('Relay Mode is not supported on iOS/macOS');
    }
  }

  @Deprecated('Use inShieldMode instead')
  BegzarEngineConfig.inVpnMode({
    this.engine = EngineNames.xray,
    required this.dir,
    required this.config,
    this.memory = 128,
    this.isString = true,
    this.tunnelPort = 2080,
    this.excludedPackages = const [],
    this.allowedPackages = const [],
  })  : _shieldMode = true,
        bindPhysicalInterface = false;

  bool get shieldMode => _shieldMode;
  bool get vpnMode => _shieldMode;
  set parcelFileId(int id) => _tunnelDescriptorId = id;

  /// Returns both app lists as the arguments of the native `startVPN` call.
  ///
  /// They travel with every start, empty included, so the native side keeps no
  /// list between connects and an old one can never outlive a setting turned
  /// off.
  Map<String, List<String>> get vpnStartArguments => {
        _excludedPackagesArgument: excludedPackages,
        _allowedPackagesArgument: allowedPackages,
      };
}
