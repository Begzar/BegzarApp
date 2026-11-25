import 'dart:io';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/services/windows_system_proxy_service.dart';
import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/connection/domain/value_objects/ping_result.dart';
import 'package:begzar/modules/connection/domain/local_proxy_endpoint.dart';
import 'package:begzar/modules/connection/domain/probe_target.dart';
import 'package:begzar/modules/connection/domain/tunnel_mode.dart';
import 'package:begzar/modules/connection/domain/tunnel_options.dart';
import 'package:begzar/modules/connection/data/datasources/local_port_allocator.dart';
import 'package:begzar/modules/connection/data/datasources/other_vpn_data_source.dart';
import 'package:begzar/modules/connection/data/datasources/proxy_core_adapter.dart';
import 'package:begzar/modules/connection/data/datasources/tunnel_helper.dart';
import 'package:begzar/modules/connection/data/tunnel_failures.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:fpdart/fpdart.dart' hide State;

/// Drives the proxy engine: the only place that decides VPN versus proxy mode
/// and hands a config to [ProxyCoreAdapter], and on Windows the only place that
/// puts the tunnel helper in front of it.
///
/// It takes what it needs as arguments and reaches for nothing. There is no
/// interface above it either — tests substitute it by overriding
/// `connectionRepositoryProvider`, and a fake `implements ConnectionRepository`
/// against the implicit interface every Dart class carries.
class ConnectionRepository {
  static const _log = Log('tunnel');

  final ProxyCoreAdapter _adapter;

  /// A connect in a build without the engine: the stand-in would only throw
  /// prose, which would read as a server that failed rather than an engine
  /// that is not there.
  static const _engineMissing = TunnelFailure(
    'The proxy engine is not part of this build',
    userFacingKey: UserFacingErrorKeys.engineMissing,
  );
  final LocalPortAllocator _ports;
  final OtherVpnDataSource _otherVpn;

  /// The Windows helper that puts a tunnel in front of the engine when Tunnel
  /// is chosen. Null on every other platform, which is what keeps them off the
  /// tunnel branch entirely.
  final TunnelHelper? _tunnelHelper;

  ConnectionRepository(
    this._adapter, {
    LocalPortAllocator ports = const LocalPortAllocator(),
    OtherVpnDataSource otherVpn = const OtherVpnDataSource(),
    TunnelHelper? tunnelHelper,
  }) : _ports = ports,
       _otherVpn = otherVpn,
       _tunnelHelper = tunnelHelper;

  /// Emits when the helper's tunnel ends without a disconnect asking for it:
  /// the helper exited, was killed, or its tunnel failed. Empty where there is
  /// no helper.
  Stream<void> get tunnelLost => _tunnelHelper?.lost ?? const Stream.empty();

  /// Whether the connection up now was made through the helper, which may
  /// since have gone. Never true without a helper.
  ///
  /// It answers for the connect that was made rather than for the mode
  /// Settings shows now, which can change while connected. The helper keeps
  /// the answer, not this repository: a language change rebuilds the
  /// repository, and the helper stays.
  bool get connectedThroughHelper => _tunnelHelper?.carriesConnection ?? false;

  /// Whether the connection up now was made through the helper and the helper
  /// has gone since. The helper stops reading as running the moment its lease
  /// closes, before [tunnelLost] reports it, so this sees a loss the report
  /// has yet to reach.
  bool get helperLost =>
      connectedThroughHelper && !(_tunnelHelper?.isRunning ?? false);

  int _activeSocksPort = kDefaultProxyPort;
  int _activeHttpProxyPort = kDefaultHttpProxyPort;

  /// The SOCKS port the engine is actually listening on.
  ///
  /// Read it rather than [kDefaultProxyPort]: the preferred port is not always
  /// bindable, and anything that dials through the relay — the exit-address
  /// lookup, the port shown in settings — has to agree with what was opened or
  /// it talks to nothing. Before the first connect this is the preferred port,
  /// which is the right answer for a screen drawn while the tunnel is down.
  int get activeSocksPort => _activeSocksPort;

  /// The same, for the HTTP listener Windows points the system proxy at.
  int get activeHttpProxyPort => _activeHttpProxyPort;

  /// Desktop without a TUN of its own: Linux always, and Windows unless its
  /// helper carries a tunnel (see [_helperFor]). Either is otherwise a local
  /// SOCKS / system proxy.
  /// iOS/macOS always use Network Extension (shield mode); relay is unsupported.
  bool get _forceProxyOnly => Platform.isWindows || Platform.isLinux;

  bool get _forceVpnOnly => Platform.isIOS || Platform.isMacOS;

  /// The helper a connect with [options] puts in front of the engine, or null
  /// when it uses none: the user chose one of the proxy modes, or this
  /// platform has no helper.
  TunnelHelper? _helperFor(TunnelOptions options) =>
      options.wantsTunnel ? _tunnelHelper : null;

  /// Stops the helper, then the engine.
  ///
  /// The helper goes first because its tunnel hands every app's traffic to the
  /// engine: an engine that went first, or whose stop failed, would leave the
  /// machine routing into a port nothing answers on. The engine is stopped
  /// even when the helper's stop throws.
  Future<void> _stopHelperThenEngine() async {
    try {
      await _tunnelHelper?.stop();
    } finally {
      await _adapter.stop();
    }
  }

  /// Apple opens its tunnel before the engine starts in it, so an engine that
  /// fails to start leaves a tunnel up that carries nothing.
  bool get _appleTunnel => Platform.isIOS || Platform.isMacOS;

  /// Takes down what a connect that failed had started.
  ///
  /// The system proxy is cleared in every mode, as it always was. A tunnel
  /// connect also stops the helper and the engine, because a failure can land
  /// after either came up — a declined admin prompt arrives with the engine
  /// already running. Never throws, so the failure the caller reports is the
  /// one that happened.
  Future<void> _unwindFailedStart({required bool tunnel}) async {
    await WindowsSystemProxyService.instance.clearProxy();
    if (!tunnel) return;
    try {
      await _stopHelperThenEngine();
    } catch (e) {
      _log.warn('start.unwindThrew', {'type': e.runtimeType});
    }
  }

  /// Opens the tunnel and reports which mode it settled on.
  ///
  /// The mode is not the caller's to predict — the platform overrides it — and
  /// the application layer needs it to record what happened, so it comes back
  /// rather than being worked out twice.
  ///
  /// Tunnel mode on Windows is proxy mode with the helper in front: the engine
  /// starts as Proxy only starts it, the helper starts once the engine is
  /// listening, and the system proxy is never set.
  ///
  /// [isCancelled] is the caller's way of saying the connect was called off
  /// while it ran. Only the helper's launch asks it.
  Future<Either<ConnectionFailure, TunnelMode>> connect(
    ProxyConfigEntity config,
    TunnelOptions options, {
    bool Function()? isCancelled,
  }) async {
    if (!_adapter.engineAvailable) return left(_engineMissing);
    // Settled before anything starts, so a failure at any step knows whether
    // there is a helper to take down.
    final helper = _helperFor(options);
    try {
      // Initialize adapter
      await _adapter.initialize();

      // Android/Windows/Linux: tear down relay/test engine before real start.
      // iOS/macOS: testing already opened the NE tunnel with the winning config —
      // keep that same tunnel and only swap/re-apply the engine config.
      final reuseAppleTunnel =
          (Platform.isIOS || Platform.isMacOS) &&
          await _adapter.isTunnelActive();
      if (reuseAppleTunnel) {
        _log.trace('start.reuse', {'platform': 'apple'});
      } else {
        _log.trace('start.restart');
        await _stopHelperThenEngine();
        await Future.delayed(const Duration(milliseconds: 300));
      }
      await WindowsSystemProxyService.instance.clearProxy();

      // The platform can force a mode regardless of what the user asked for.
      // Windows is a proxy unless the helper carries a tunnel in front of it.
      final isProxyOnly =
          !_forceVpnOnly &&
          (options.proxyOnly || (_forceProxyOnly && helper == null));
      final useSystemProxy =
          Platform.isWindows && options.systemProxy && !options.proxyOnly;

      if (isProxyOnly || helper != null) {
        // Resolved per start rather than once: the reserved blocks that make a
        // port unbindable are assigned by the OS and move across reboots, so
        // the answer is only good for the start it was measured for.
        final socksPort = await _ports.resolve(
          kDefaultProxyPort,
          fallbacks: kProxyPortFallbacks,
          host: options.listenAddress,
        );
        final httpPort = useSystemProxy
            ? await _ports.resolve(
                kDefaultHttpProxyPort,
                fallbacks: kHttpProxyPortFallbacks,
              )
            : null;
        _activeSocksPort = socksPort;
        if (httpPort != null) _activeHttpProxyPort = httpPort;

        _log.trace(helper == null ? 'start.proxyOnly' : 'start.tunnel', {
          'systemProxy': useSystemProxy,
          'socksPort': socksPort,
          'httpPort': httpPort ?? -1,
          'config': config.name,
          'scheme': Log.scheme(config.url),
        });
        // Behind the helper, every connection reaches the engine as the
        // helper's, so the engine cannot tell programs apart and the helper
        // applies App Routing instead. The engine binds its own connections
        // to the physical interface, so none of them enters the tunnel it
        // feeds.
        await _adapter.startProxyMode(
          config,
          dnsServer: options.dnsServer,
          socksPort: socksPort,
          listenAddress: options.listenAddress,
          customRouting: options.customRouting,
          httpPort: httpPort,
          appRouting: helper == null ? options.appRouting : AppRouting.none,
          bindPhysicalInterface: helper != null,
        );
        if (helper != null) {
          // Asked once more before the admin prompt, which is the one step a
          // user who already called the connect off would see. What came up
          // is the engine alone, and the caller that called it off takes that
          // down, as it does any dial that lands after the call.
          if (isCancelled?.call() ?? false) {
            _log.trace('start.calledOff');
            return right(TunnelMode.proxy);
          }
          await helper.start(
            socksPort: socksPort,
            appRouting: options.appRouting,
          );
        }

        if (useSystemProxy && httpPort != null) {
          final ok = await WindowsSystemProxyService.instance.setProxy(
            host: kLocalhostListen,
            port: httpPort,
          );
          if (!ok) {}
        }
      } else {
        _log.trace('start.vpn', {
          'config': config.name,
          'scheme': Log.scheme(config.url),
        });
        // On Apple platforms with an existing tunnel, simpleStart only reloads the
        // provider inside the same NE session (QUICK_SHUTDOWN + QUICK_LAUNCH).
        await _adapter.startVpnMode(
          config,
          dnsServer: options.dnsServer,
          appRouting: options.appRouting,
          customRouting: options.customRouting,
        );
      }

      return right(
        useSystemProxy
            ? TunnelMode.systemProxy
            : (isProxyOnly ? TunnelMode.proxy : TunnelMode.vpn),
      );
    } on ConnectionFailure catch (failure) {
      // Typed where it was raised — a refused VPN permission by the adapter, a
      // declined admin prompt or a helper that would not start by the helper —
      // so it travels as itself rather than as prose for [tunnelFailure] to
      // read a key back out of.
      _log.error('start.failed', {'type': failure.runtimeType});
      await _unwindFailedStart(tunnel: helper != null);
      return left(failure);
    } catch (e) {
      _log.error('start.threw', {'type': e.runtimeType}, e);
      await _unwindFailedStart(tunnel: helper != null);
      return left(tunnelFailure('Connection failed: ${config.name}', e));
    }
  }

  /// Opens the tunnel on the WARP engine in [mode] (Experimental settings)
  /// and reports which mode it settled on.
  ///
  /// The engine is built into the Android and iOS cores only, so this is
  /// [connect]'s mobile path: no Windows helper and no system proxy. Proxy
  /// Only on Android serves SOCKS on the same allocated port xray would use,
  /// on loopback: the engine does not share with the LAN.
  Future<Either<ConnectionFailure, TunnelMode>> connectWarp(
    WarpMode mode,
    TunnelOptions options,
  ) async {
    if (!_adapter.engineAvailable) return left(_engineMissing);
    try {
      await _adapter.initialize();

      // As in [connect]: Apple keeps an open tunnel and swaps the engine in
      // it; everywhere else the old engine goes first.
      final reuseAppleTunnel =
          (Platform.isIOS || Platform.isMacOS) &&
          await _adapter.isTunnelActive();
      if (reuseAppleTunnel) {
        _log.trace('warp.reuse', {'platform': 'apple'});
      } else {
        await _stopHelperThenEngine();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final isProxyOnly = !_forceVpnOnly && options.proxyOnly;
      if (isProxyOnly) {
        final socksPort = await _ports.resolve(
          kDefaultProxyPort,
          fallbacks: kProxyPortFallbacks,
          host: kLocalhostListen,
        );
        _activeSocksPort = socksPort;
        _log.trace('warp.proxyOnly', {
          'mode': mode.engineName,
          'socksPort': socksPort,
        });
        await _adapter.startWarpMode(
          mode,
          vpnMode: false,
          dnsServer: options.dnsServer,
          socksPort: socksPort,
        );
        return right(TunnelMode.proxy);
      }

      _log.trace('warp.vpn', {'mode': mode.engineName});
      await _adapter.startWarpMode(
        mode,
        vpnMode: true,
        dnsServer: options.dnsServer,
        appRouting: options.appRouting,
      );
      return right(TunnelMode.vpn);
    } on ConnectionFailure catch (failure) {
      _log.error('warp.failed', {'type': failure.runtimeType});
      await _unwindFailedStart(tunnel: _appleTunnel);
      return left(failure);
    } catch (e) {
      _log.error('warp.threw', {'type': e.runtimeType}, e);
      await _unwindFailedStart(tunnel: _appleTunnel);
      return left(
        tunnelFailure('WARP connection failed: ${mode.engineName}', e),
      );
    }
  }

  /// Takes the tunnel down, the helper first.
  ///
  /// The helper is stopped whatever the options say now: the mode may have
  /// changed since the connect, and a helper left behind its engine leaves the
  /// machine without a network. That is also what takes down a helper that
  /// came up after its connect was called off.
  Future<Either<ConnectionFailure, Unit>> disconnect() async {
    try {
      await WindowsSystemProxyService.instance.clearProxy();
      await _stopHelperThenEngine();
      return right(unit);
    } catch (e) {
      await WindowsSystemProxyService.instance.clearProxy();
      return left(tunnelFailure('Disconnect failed', e));
    }
  }

  Future<Either<ConnectionFailure, bool>> testConfig(
    ProxyConfigEntity config,
  ) async {
    try {
      _log.trace('test', {
        'config': config.name,
        'scheme': Log.scheme(config.url),
      });
      await _adapter.initialize();
      final result = await _adapter.testConfiguration(config);
      _log.trace('test.result', {'working': result});
      return right(result);
    } on VpnPermissionFailure catch (e) {
      _log.error('test.permissionDenied');
      return left(e);
    } catch (e) {
      _log.warn('test.threw', {
        'type': e.runtimeType,
        'read as': 'not working',
      });
      return right(false);
    }
  }

  /// Real delay for every config in one batch, in input order; null where a
  /// config did not answer. [stopAfter] above 0 returns once that many have
  /// answered. [target] is the host each probe asks.
  ///
  /// No `Either`, unlike [testConfig]: probing runs beside the tunnel, so it
  /// cannot be refused the VPN permission, and a probe that could not run at
  /// all reads as no answer — the same reading [testConfig] gives a throw.
  Future<List<int?>> measureDelays(
    List<ProxyConfigEntity> configs, {
    required int stopAfter,
    ProbeTarget target = ProbeTarget.google,
  }) async {
    try {
      await _adapter.initialize();
      return await _adapter.measureDelays(
        configs,
        stopAfter: stopAfter,
        target: target,
      );
    } catch (e) {
      _log.warn('probe.threw', {
        'type': e.runtimeType,
        'read as': 'no answers',
      });
      return List<int?>.filled(configs.length, null);
    }
  }

  Future<PingResult> measurePing([List<String>? urls]) async {
    try {
      final testUrls = urls ?? ['https://www.google.com/generate_204'];
      final results = await _adapter.measurePing(testUrls);

      if (results.isEmpty) {
        return PingResult.failure('No ping results');
      }

      final delays = results.map((sample) => sample.elapsedMs).toList();
      final minPing = delays.reduce((a, b) => a < b ? a : b);

      if (minPing < 0 || minPing > 30000) {
        return PingResult.failure('Invalid ping: ${minPing}ms');
      }

      return PingResult.success(minPing);
    } catch (e) {
      return PingResult.failure('Ping failed: $e');
    }
  }

  /// Whether the live tunnel still carries traffic: either probe page
  /// answering through it is enough, because a server that reaches one of
  /// them is passing traffic.
  ///
  /// A check that could not run at all reads as no traffic, the same reading
  /// a probe gives a throw. One such answer alone ends nothing: a tunnel is
  /// called dead only after several in a row.
  Future<bool> isPassingTraffic() async {
    try {
      final samples = await _adapter.measureTrafficProbes();
      return samples.any((sample) => sample.succeeded);
    } catch (e) {
      _log.warn('liveness.threw', {
        'type': e.runtimeType,
        'read as': 'no traffic',
      });
      return false;
    }
  }

  Future<bool> isRunning() async {
    try {
      return await _adapter.isRunning();
    } catch (_) {
      return false;
    }
  }

  /// Whether the connection up now is carrying traffic.
  ///
  /// Judged by how that connection was made, not by the mode in [options]:
  /// Settings can change it while connected, and the change only applies to
  /// the next connect. [options] decide only how to ask about a connection
  /// the helper did not carry.
  Future<bool> isConnectionActive(TunnelOptions options) async {
    try {
      await _adapter.initialize();
      // Windows reports no tunnel of its own, so the helper's lease is what
      // says this one is up. An engine still running behind a helper that is
      // gone carries nothing.
      if (connectedThroughHelper) {
        return (_tunnelHelper?.isRunning ?? false) &&
            await _adapter.isRunning();
      }
      final isVpnMode =
          _forceVpnOnly || (!options.proxyOnly && !_forceProxyOnly);
      return await _adapter.isConnectionActive(isVpnMode: isVpnMode);
    } catch (_) {
      return false;
    }
  }

  /// When the live tunnel came up, or null when the platform cannot say.
  Future<DateTime?> tunnelStartedAt() async {
    try {
      await _adapter.initialize();
      return await _adapter.tunnelStartedAt();
    } catch (_) {
      return null;
    }
  }

  /// Whether another app's VPN is up.
  ///
  /// The platform reports any VPN, so Begzar's own tunnel is ruled out first:
  /// on Windows, the helper's adapter for as long as the helper runs. A check
  /// that throws reads as no: this decides whether measuring servers can be
  /// trusted, not who may connect, and a broken check must not lock everyone
  /// out.
  Future<bool> isOtherVpnOn() async {
    try {
      if (_tunnelHelper?.isRunning ?? false) return false;
      if (await _adapter.isTunnelActive()) return false;
      return await _otherVpn.isVpnOn();
    } catch (e) {
      _log.warn('otherVpn.checkThrew', {
        'type': e.runtimeType,
        'read as': 'none',
      });
      return false;
    }
  }

  /// Tries to turn another app's VPN off.
  ///
  /// Reports nothing, because the attempt is not the answer: Android can be
  /// refused, and Apple documents no promise at all. Whoever asked checks
  /// again afterwards. Initializing first is what hands the Apple plugin the
  /// tunnel's identifiers, which the takeover saves the configuration under.
  Future<void> turnOffOtherVpn() async {
    try {
      await _adapter.initialize();
      await _otherVpn.turnOff();
    } catch (e) {
      _log.warn('otherVpn.turnOffThrew', {'type': e.runtimeType});
    }
  }

  /// Opens the system's VPN settings, reporting whether anything opened.
  Future<bool> openVpnSettings() async {
    try {
      return await _otherVpn.openVpnSettings();
    } catch (e) {
      _log.warn('otherVpn.settingsThrew', {'type': e.runtimeType});
      return false;
    }
  }
}
