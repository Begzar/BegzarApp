import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:begzar_engine/constants/engine_names.dart';
import 'package:begzar_engine/models/begzar_engine_config.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:begzar/core/log/log.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/connection/domain/probe_target.dart';
import 'package:begzar/modules/connection/data/constants/ios_vpn_constants.dart';
import 'package:begzar/modules/connection/data/datasources/tunnel_notification_text.dart';
import 'package:begzar/modules/connection/data/datasources/engine_config_requests.dart';
import 'package:begzar/modules/connection/data/datasources/warp_engine_payload.dart';
import 'package:begzar/modules/connection/data/tunnel_failures.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';

/// Adapter for ProxyCore external library
/// Encapsulates all direct interactions with the begzar_engine package
class ProxyCoreAdapter {
  /// The app's strings, for the one thing a running tunnel shows the user
  /// outside the app: the ongoing notification. They are handed in rather
  /// than looked up, because a data source does not read providers.
  ProxyCoreAdapter({required this.l10n});

  final AppLocalizations l10n;

  static const _log = Log('engine');

  /// Whether this build carries the proxy engine. The open build runs on a
  /// stand-in that answers false, and starts nothing.
  bool get engineAvailable => BegzarEngine.ins.isAvailable;

  /// The longest the engine gets to become reachable before a probe is sent
  /// through it anyway.
  ///
  /// This used to be a flat wait of the same length, spent whether or not the
  /// engine was ready sooner, and paid once per candidate tested. It is a
  /// ceiling now — see [_awaitEngineReady].
  static const _testSettleCap = Duration(seconds: 2);

  /// How often the engine is asked whether it is running while waiting.
  ///
  /// Short enough that the wait ends near when the engine actually came up,
  /// long enough that the polling is not itself the cost.
  static const _testSettlePoll = Duration(milliseconds: 100);

  /// Waited after the engine says it is running, before measuring through it.
  ///
  /// "Running" is the engine's own state, not a promise that its outbound has
  /// carried a packet yet, and the two are not simultaneous. This is the
  /// margin between them. It is deliberately short rather than safe-by-a-mile
  /// because it is not the only thing standing between a warm-up and a good
  /// server being called dead: a probe that fails quickly is retried, so a
  /// tunnel measured a little early gets a second attempt rather than a
  /// verdict.
  static const _testSettleGrace = Duration(milliseconds: 250);

  /// How long a candidate gets to answer before it is treated as dead.
  static const _testPingTimeout = Duration(seconds: 12);

  /// Slower than this and the config is not worth connecting to. Well above
  /// anything usable — this rejects the broken, not the merely slow.
  static const _testMaxPing = Duration(seconds: 30);

  /// A 204 with no body, so the probe measures the round trip and not the
  /// download.
  static const _testProbeUrl = 'https://www.google.com/generate_204';

  /// Cloudflare's connectivity check: a 204 with no body like Google's, over
  /// HTTPS so it takes the TLS handshake that a server reaching only Google
  /// fails.
  static const _outsideGoogleProbeUrl =
      'https://cp.cloudflare.com/generate_204';
  static const _vpnChannel = MethodChannel('begzar_engine/vpn');
  static const _vpnEventChannel = EventChannel('begzar_engine/vpn_events');

  bool _isInitialized = false;
  Future<void>? _initializeFuture;
  Future<void> Function(bool isRunning)? _onEngineStateChanged;
  bool _iosTunnelInfoSet = false;

  /// Initialize the proxy core
  Future<void> initialize({
    Future<void> Function(bool isRunning)? onEngineStateChanged,
  }) async {
    if (onEngineStateChanged != null) {
      _onEngineStateChanged = onEngineStateChanged;
    }

    if (_isInitialized) {
      _ensureIosTunnelInfo();
      if (onEngineStateChanged != null) {
        await BegzarEngine.ins.initialize(
          onEngineStateChanged: onEngineStateChanged,
        );
      }
      return;
    }

    if (_initializeFuture != null) {
      await _initializeFuture;
      _ensureIosTunnelInfo();
      if (onEngineStateChanged != null) {
        await BegzarEngine.ins.initialize(
          onEngineStateChanged: onEngineStateChanged,
        );
      }
      return;
    }

    _initializeFuture = () async {
      _ensureIosTunnelInfo();
      await BegzarEngine.ins.initialize(
        onEngineStateChanged: _onEngineStateChanged,
      );
      _isInitialized = true;
    }();

    try {
      await _initializeFuture;
    } catch (_) {
      _initializeFuture = null;
      rethrow;
    }
  }

  void _ensureIosTunnelInfo() {
    if ((!Platform.isIOS && !Platform.isMacOS) || _iosTunnelInfoSet) return;
    BegzarEngine.ins.setIosTunnelInfo(
      IosVpnConstants.appName,
      IosVpnConstants.packetTunnelBundleId,
    );
    _iosTunnelInfoSet = true;
  }

  /// Start proxy in VPN mode with given configuration
  ///
  /// Throws [VpnPermissionFailure] when the system refuses to prepare or
  /// install the VPN profile. Quick connect probes beside the tunnel, so on
  /// Apple this start, not a test, is where that refusal first arrives.
  Future<void> startVpnMode(
    ProxyConfigEntity config, {
    String dnsServer = '8.8.8.8',
    AppRouting appRouting = AppRouting.none,
    CustomRoutingRules customRouting = CustomRoutingRules.empty,
  }) async {
    try {
      final configJson = await BegzarEngine.ins.buildEngineConfig(
        vpnModeEngineConfigRequest(
          shareLink: config.url,
          platform: defaultTargetPlatform,
          dnsServer: dnsServer,
          customRouting: customRouting,
        ),
      );

      final dir = await getApplicationDocumentsDirectory().then((d) => d.path);

      // Counts only: an app's name must never reach a log line.
      _log.trace('vpn.appRouting', {
        'mode': appRouting.mode.storedName,
        'apps': appRouting.apps.length,
      });
      await BegzarEngine.ins.simpleStart(
        BegzarEngineConfig.inShieldMode(
          dir: dir,
          config: configJson,
          excludedPackages: appRouting.bypassing,
          allowedPackages: appRouting.onlyThrough,
        ),
        notification: tunnelNotificationText(l10n, vpnMode: true),
      );

      if (Platform.isIOS || Platform.isMacOS) {
        _log.trace('vpn.awaitTunnel', {'platform': 'apple'});
        await _waitForIosTunnelConnected();
      }
    } catch (e) {
      if (isVpnPermissionRefusal(e)) {
        _log.error('vpn.permissionDenied');
        throw VpnPermissionFailure('VPN permission denied: $e');
      }
      _log.error('vpn.startThrew', {'type': e.runtimeType}, e);
      throw Exception('Failed to start VPN mode: $e');
    }
  }

  /// How long Apple waits for the tunnel when the WARP engine starts it.
  ///
  /// Longer than xray's: a first start registers an identity with
  /// Cloudflare, and a Psiphon mode then waits for Psiphon, whose own limit
  /// for finding a tunnel is a minute.
  static const _warpTunnelTimeout = Duration(seconds: 75);

  /// Starts the WARP engine in [mode] (Experimental settings), on the same
  /// port and through the same tunnel as xray.
  ///
  /// [vpnMode] false is Android's Proxy Only: the engine serves SOCKS on
  /// [socksPort] and no tunnel opens. Apple has no such mode, so there it is
  /// always the tunnel. Custom routing rules and ad blocking are xray
  /// features this engine does not have; app routing is the VPN service's,
  /// so it still applies.
  ///
  /// Throws [VpnPermissionFailure] when the system refuses the VPN profile,
  /// as [startVpnMode] does.
  Future<void> startWarpMode(
    WarpMode mode, {
    required bool vpnMode,
    String dnsServer = '1.1.1.1',
    int socksPort = 2080,
    AppRouting appRouting = AppRouting.none,
  }) async {
    final apple = Platform.isIOS || Platform.isMacOS;
    final tunnel = vpnMode || apple;
    try {
      final dir = await getApplicationDocumentsDirectory().then((d) => d.path);
      final payload = warpEnginePayload(mode, dnsServer: dnsServer);
      _log.trace('warp.start', {'mode': mode.engineName, 'tunnel': tunnel});

      final config = tunnel
          ? BegzarEngineConfig.inShieldMode(
              engine: EngineNames.warp,
              dir: dir,
              config: payload,
              excludedPackages: appRouting.bypassing,
              allowedPackages: appRouting.onlyThrough,
            )
          : BegzarEngineConfig.inRelayMode(
              engine: EngineNames.warp,
              dir: dir,
              config: payload,
              tunnelPort: socksPort,
            );
      await BegzarEngine.ins.simpleStart(
        config,
        notification: tunnelNotificationText(l10n, vpnMode: tunnel),
      );

      if (apple) {
        _log.trace('warp.awaitTunnel', {'platform': 'apple'});
        await _waitForIosTunnelConnected(timeout: _warpTunnelTimeout);
      }
    } catch (e) {
      if (isVpnPermissionRefusal(e)) {
        _log.error('warp.permissionDenied');
        throw VpnPermissionFailure('VPN permission denied: $e');
      }
      _log.error('warp.startThrew', {'type': e.runtimeType}, e);
      throw Exception('Failed to start WARP: $e');
    }
  }

  /// Start proxy in Proxy mode (SOCKS proxy only - no VPN)
  ///
  /// [bindPhysicalInterface] is for a tunnel in front of the engine, which
  /// takes the system's traffic and DNS. The engine binds its outbound
  /// connections to the physical interface and resolves the proxy server's
  /// name itself, routed direct, so neither its connections nor that lookup
  /// enter the tunnel the engine feeds. The system's DNS, which the tunnel
  /// hands to the engine, goes to [dnsServer] through the proxy. Off, the
  /// config is built as it always was.
  Future<void> startProxyMode(
    ProxyConfigEntity config, {
    String dnsServer = '8.8.8.8',
    int socksPort = 2080,
    String listenAddress = '127.0.0.1',
    CustomRoutingRules customRouting = CustomRoutingRules.empty,
    int? httpPort,
    AppRouting appRouting = AppRouting.none,
    bool bindPhysicalInterface = false,
  }) async {
    if (Platform.isIOS || Platform.isMacOS) {
      // Relay/SOCKS-only mode is unsupported on Apple — always use the NE tunnel.
      await startVpnMode(
        config,
        dnsServer: dnsServer,
        customRouting: customRouting,
      );
      return;
    }

    try {
      // Only the desktop engine can tell programs apart. Android applies the
      // mode in VpnService and has no per-program lookup in proxy mode, and
      // Apple does not offer it.
      final engineRouting = Platform.isWindows || Platform.isLinux
          ? appRouting
          : AppRouting.none;
      // Counts only: a program's name must never reach a log line.
      _log.trace('proxy.appRouting', {
        'mode': engineRouting.mode.storedName,
        'apps': engineRouting.apps.length,
      });
      final configJson = await BegzarEngine.ins.buildEngineConfig(
        engineConfigRequest(
          shareLink: config.url,
          socksPort: socksPort,
          listenAddress: listenAddress,
          dnsServer: dnsServer,
          customRouting: customRouting,
          httpPort: httpPort,
          appRouting: engineRouting,
          resolveServerOutsideTunnel: bindPhysicalInterface,
          forwardTunnelDns: bindPhysicalInterface,
        ),
      );

      final proxyCoreConfig = BegzarEngineConfig.inRelayMode(
        dir: await getApplicationDocumentsDirectory().then((dir) => dir.path),
        config: configJson,
        tunnelPort: socksPort,
        bindPhysicalInterface: bindPhysicalInterface,
      );
      await BegzarEngine.ins.simpleStart(
        proxyCoreConfig,
        notification: tunnelNotificationText(l10n, vpnMode: false),
      );
    } catch (e) {
      throw Exception('Failed to start Proxy mode: $e');
    }
  }

  /// Start proxy in test mode.
  ///
  /// Android/Windows/Linux: local SOCKS relay (`inRelayMode`).
  /// iOS/macOS: Network Extension is opened by [BegzarEngine.simpleStart] (`inShieldMode`),
  /// then the config runs inside the tunnel and can be pinged.
  Future<void> startTestMode(
    ProxyConfigEntity config, {
    String dnsServer = '8.8.8.8',
    CustomRoutingRules customRouting = CustomRoutingRules.empty,
  }) async {
    try {
      // On Apple the test runs in the packet tunnel, which carries the
      // system's traffic while it is up, so it gets the config a connect does.
      final inTunnel = Platform.isIOS || Platform.isMacOS;
      final configJson = await BegzarEngine.ins.buildEngineConfig(
        inTunnel
            ? vpnModeEngineConfigRequest(
                shareLink: config.url,
                platform: defaultTargetPlatform,
                dnsServer: dnsServer,
                customRouting: customRouting,
              )
            : engineConfigRequest(
                shareLink: config.url,
                dnsServer: dnsServer,
                customRouting: customRouting,
              ),
      );
      final dir = await getApplicationDocumentsDirectory().then((d) => d.path);

      final BegzarEngineConfig proxyCoreConfig;
      if (inTunnel) {
        proxyCoreConfig = BegzarEngineConfig.inShieldMode(
          dir: dir,
          config: configJson,
        );
      } else {
        proxyCoreConfig = BegzarEngineConfig.inRelayMode(
          dir: dir,
          config: configJson,
        );
      }

      // On Apple this opens the NE tunnel first (if needed), then simpleStarts.
      await BegzarEngine.ins.simpleStart(proxyCoreConfig);

      if (Platform.isIOS || Platform.isMacOS) {
        _log.trace('test.awaitTunnel', {'platform': 'apple'});
        await _waitForIosTunnelConnected();
      }
    } catch (e) {
      _log.error('test.startThrew', {'type': e.runtimeType}, e);
      throw Exception('Failed to start test mode: $e');
    }
  }

  /// Stop the proxy core (full VPN teardown on iOS).
  Future<void> stop() async {
    if (!_isInitialized) return;
    try {
      await BegzarEngine.ins.stop();
    } catch (_) {
      // Ignore stop errors
    }
  }

  /// Check if proxy core is running
  Future<bool> isRunning() async {
    if (!_isInitialized) return false;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        // begzar_engine Apple `isEngineActive` can reply before the tunnel message
        // returns; treat NE tunnel connected as the reliable running signal.
        return await isTunnelActive();
      }
      return await BegzarEngine.ins.isRunning;
    } catch (_) {
      return false;
    }
  }

  /// Check if the native VPN tunnel interface is active (Android/Apple VPN mode).
  Future<bool> isTunnelActive() async {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        final status = await _vpnChannel.invokeMethod<String>(
          'getTunnelStatus',
        );
        return status == 'connected';
      } on MissingPluginException {
        return false;
      } on PlatformException {
        return false;
      }
    }
    if (!Platform.isAndroid) return false;
    try {
      final result = await _vpnChannel.invokeMethod<dynamic>('isVPNRunning');
      return result == true || result == 1;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// When the live tunnel came up, or null when nothing native answers.
  ///
  /// Asked of the platform rather than stamped here, because the app is not
  /// always running when a tunnel starts and is not always the thing that
  /// started it. Android's service keeps the time it established the
  /// interface; Apple reports the VPN connection's own `connectedDate`, which
  /// the system keeps outside this process. Either way, an app reopened over
  /// a tunnel that stayed up reads back the age that tunnel really has
  /// instead of restarting from zero.
  Future<DateTime?> tunnelStartedAt() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return null;
    }
    try {
      final millis = await _vpnChannel.invokeMethod<int>('getVpnStartedAt');
      if (millis == null || millis <= 0) return null;

      return DateTime.fromMillisecondsSinceEpoch(millis);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _waitForIosTunnelConnected({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await isTunnelActive()) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
    throw Exception('Apple VPN tunnel did not become connected in time');
  }

  /// Whether the connection is truly active (engine + tunnel when in VPN mode).
  Future<bool> isConnectionActive({required bool isVpnMode}) async {
    if (Platform.isIOS || Platform.isMacOS) {
      // Tunnel status is the source of truth on Apple (see [isRunning]).
      return await isTunnelActive();
    }
    final engineRunning = await isRunning();
    if (!engineRunning) return false;
    if (!isVpnMode) return true;
    return isTunnelActive();
  }

  /// Native VPN status changes (e.g. revoked when another VPN app connects).
  Stream<bool> watchVpnStatusEvents() {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return const Stream<bool>.empty();
    }
    return _vpnEventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event['status'] == true;
      }
      if (event is bool) return event;
      if (event is String) return event == 'connected';
      return false;
    });
  }

  /// [elapsedMs] when it is an answer worth connecting to, null otherwise.
  static int? _usableDelay(int? elapsedMs) {
    if (elapsedMs == null || elapsedMs < 0) return null;
    return elapsedMs < _testMaxPing.inMilliseconds ? elapsedMs : null;
  }

  /// Real delay for every config in one batch, in input order; null where a
  /// config did not answer, or answered too slowly to be worth connecting to.
  ///
  /// Runs throwaway engine instances beside the tunnel on every platform —
  /// the same path the picker badges use — so it never asks for the VPN
  /// permission and never leaves a tunnel up. [stopAfter] above 0 lets the
  /// engine return once that many configs have answered; the rest come back
  /// null. [target] picks the host each probe asks.
  Future<List<int?>> measureDelays(
    List<ProxyConfigEntity> configs, {
    int stopAfter = 0,
    ProbeTarget target = ProbeTarget.google,
  }) async {
    final clock = Stopwatch()..start();
    final samples = await BegzarEngine.ins.realDelayAll(
      configs.map((config) => config.url).toList(),
      endpoint: switch (target) {
        ProbeTarget.google => _testProbeUrl,
        ProbeTarget.outsideGoogle => _outsideGoogleProbeUrl,
      },
      stopAfter: stopAfter,
    );

    // Matched by the index each sample carries rather than by position, as
    // the picker does: a sample is only promised to name its input.
    final elapsedByIndex = {
      for (final sample in samples) sample.index: sample.elapsedMs,
    };
    final delays = [
      for (var index = 0; index < configs.length; index++)
        _usableDelay(elapsedByIndex[index]),
    ];
    _log.trace('probe.batch', {
      'target': target.name,
      'candidates': configs.length,
      'answered': delays.nonNulls.length,
      'stopAfter': stopAfter,
      'total': '${clock.elapsedMilliseconds}ms',
    });
    return delays;
  }

  /// Test a proxy configuration.
  ///
  /// On Apple a passing test keeps the NE tunnel up so [connect] can reuse it
  /// with QUICK_LAUNCH inside the same session. A failed test tears the tunnel
  /// down so [ConnectionNotifier.reconcileWithNative] does not adopt a dead
  /// dial as connected.
  ///
  /// Windows/Linux/Android use throwaway real-delay cores instead of starting
  /// the live relay. That is the same path the picker badges already use, and
  /// it does not occupy [SharedXrayProvider] or the SOCKS port the real dial
  /// needs.
  ///
  /// Throws [VpnPermissionFailure] when the system refuses to prepare or
  /// install the VPN profile.
  Future<bool> testConfiguration(ProxyConfigEntity config) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return _testViaRealDelay(config);
    }
    return _testViaLiveEngine(config);
  }

  Future<bool> _testViaRealDelay(ProxyConfigEntity config) async {
    _log.trace('test.realDelay', {
      'config': config.name,
      'scheme': Log.scheme(config.url),
    });
    try {
      final delay = (await measureDelays([config])).single;
      final passed = delay != null;
      _log.trace('test.verdict', {'minPing': delay ?? -1, 'passed': passed});
      return passed;
    } catch (e) {
      _log.warn('test.threw', {'type': e.runtimeType});
      return false;
    }
  }

  Future<bool> _testViaLiveEngine(ProxyConfigEntity config) async {
    try {
      // Every phase below is timed because the whole of this method is about
      // three quarters of what a connect costs, and until it was measured
      // which phase held that time was a guess. The timings are one line at
      // the end rather than a line each, so a 24-candidate auto-connect does
      // not spend 96 lines saying so.
      final clock = Stopwatch()..start();
      _log.trace('test.start', {
        'config': config.name,
        'scheme': Log.scheme(config.url),
      });
      await startTestMode(config);
      final startedAt = clock.elapsedMilliseconds;

      final readyAfter = await _awaitEngineReady();
      final settledAt = clock.elapsedMilliseconds;

      final pingResults = await measurePing([_testProbeUrl]).timeout(
        _testPingTimeout,
        onTimeout: () {
          _log.warn('test.pingTimeout');
          return <LatencySample>[];
        },
      );
      final pingedAt = clock.elapsedMilliseconds;

      final bool passed;
      if (pingResults.isEmpty) {
        _log.trace('test.noPing');
        passed = false;
      } else {
        final delays = pingResults.map((sample) => sample.elapsedMs).toList();
        final minPing = delays.fold<int>(delays.first, (a, b) => a < b ? a : b);
        passed = minPing >= 0 && minPing < _testMaxPing.inMilliseconds;
        _log.trace('test.verdict', {'minPing': minPing, 'passed': passed});
      }

      if (!passed) {
        await stop();
      }
      final tornDownAt = clock.elapsedMilliseconds;

      _log.trace('test.timing', {
        'start': '${startedAt}ms',
        'settle': '${settledAt - startedAt}ms',
        'ready': readyAfter == null
            ? 'never'
            : '${readyAfter.inMilliseconds}ms',
        'ping': '${pingedAt - settledAt}ms',
        'teardown': '${tornDownAt - pingedAt}ms',
        'total': '${tornDownAt}ms',
      });

      return passed;
    } catch (e) {
      if (isVpnPermissionRefusal(e)) {
        _log.error('test.permissionDenied');
        throw VpnPermissionFailure('VPN permission denied: $e');
      }
      _log.warn('test.threw', {'type': e.runtimeType});
      try {
        await stop();
      } catch (_) {}
      return false;
    }
  }

  /// Waits for the engine to report itself running, then a short grace, and
  /// returns how long readiness took — or null if it never arrived.
  ///
  /// The whole wait is bounded by [_testSettleCap], which is the length of the
  /// flat sleep this replaced, so a candidate can never be slower to test than
  /// it was before. An engine that comes up in 200ms is measured at 450ms
  /// instead of 2000ms; one that never reports running costs exactly what it
  /// always did, and the probe is sent anyway rather than the candidate being
  /// failed on a state check it might be wrong about.
  ///
  /// Apple barely reaches the loop: [startTestMode] has already awaited the NE
  /// tunnel by the time this is called, so readiness is true on the first poll
  /// and only the grace is spent. The flat two seconds there sat on top of a
  /// wait that had already happened.
  Future<Duration?> _awaitEngineReady() async {
    final clock = Stopwatch()..start();

    while (clock.elapsed < _testSettleCap) {
      // A check that throws is not a failed candidate — the engine may simply
      // not be answering yet. Treat it as "not ready" and ask again.
      var running = false;
      try {
        running = await isRunning();
      } catch (_) {}

      if (running) {
        final readyAfter = clock.elapsed;
        await Future.delayed(_shorter(_testSettleGrace, clock));
        return readyAfter;
      }

      if (clock.elapsed >= _testSettleCap) break;
      await Future.delayed(_shorter(_testSettlePoll, clock));
    }

    return null;
  }

  /// [wait], or whatever is left of [_testSettleCap] if that is less.
  ///
  /// Every sleep in the readiness loop goes through this, which is what makes
  /// the cap a real ceiling rather than one the last poll can overshoot.
  static Duration _shorter(Duration wait, Stopwatch clock) {
    final remaining = _testSettleCap - clock.elapsed;
    if (remaining <= Duration.zero) return Duration.zero;
    return remaining < wait ? remaining : wait;
  }

  /// Measure ping using proxy core
  Future<List<LatencySample>> measurePing(List<String> urls) async {
    try {
      return await BegzarEngine.ins.measureLatency(urls);
    } catch (e) {
      throw Exception('Failed to measure ping: $e');
    }
  }

  /// Fetches, through the live tunnel, the two pages auto-connect probes, to
  /// tell whether the tunnel still carries traffic.
  Future<List<LatencySample>> measureTrafficProbes() =>
      measurePing([_testProbeUrl, _outsideGoogleProbeUrl]);

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
  }
}
