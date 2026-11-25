import 'dart:async';
import 'dart:math';

import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/core/services/api_service.dart';
import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:begzar/modules/connection/application/services/connection_service.dart';
import 'package:begzar/modules/connection/data/datasources/other_vpn_data_source.dart';
import 'package:begzar/modules/connection/data/datasources/proxy_core_adapter.dart';
import 'package:begzar/modules/connection/data/datasources/tunnel_helper.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/connection/domain/local_proxy_endpoint.dart';
import 'package:begzar/modules/connection/domain/probe_target.dart';
import 'package:begzar/modules/connection/domain/proxy_config_validator.dart';
import 'package:begzar/modules/connection/domain/tunnel_mode.dart';
import 'package:begzar/modules/connection/domain/tunnel_options.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:begzar/modules/connection/data/repositories/connection_repository.dart';
import 'package:begzar/modules/connection/data/repositories/engine_log_repository.dart';
import 'package:begzar/modules/connection/domain/entities/engine_log_line.dart';
import 'dart:ui' show Rect;
import 'package:begzar/modules/connection/domain/value_objects/ping_result.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:begzar/modules/connection/presentation/controllers/other_vpn_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:begzar_engine/begzar_engine.dart';

/// Scheme for synthetic test configs.
///
/// Deliberately not a real proxy scheme: nothing here should ever be mistaken
/// for a usable server config.
const String kTestConfigScheme = 'test';

/// Builds a config whose name doubles as its identity in the fakes below.
///
/// Its scheme is deliberately one [ProxyConfigValidator] rejects, which suits
/// auto-connect (it does not validate) and lets a test exercise a real
/// validation failure. Use [dialableConfig] where the config must pass.
ProxyConfigEntity testConfig(String name) =>
    ProxyConfigEntity(url: '$kTestConfigScheme://$name', name: name);

/// Builds a config the validator accepts, for the paths that check before
/// connecting.
///
/// The scheme is read from [ProxyConfigValidator] rather than written out, so
/// no string here can be mistaken for a real config and the helper stays
/// correct if the accepted list changes.
ProxyConfigEntity dialableConfig(String name) => ProxyConfigEntity(
  url: '${ProxyConfigValidator.supportedSchemes.first}$name',
  name: name,
);

/// Event-loop turns a VPN that will not go takes to be given up on.
///
/// The service checks for it up to fifteen times, each a call and a timer, all
/// immediate under the test's poll interval. Turns are counted, not timed.
const int turnsToGiveUpOnAVpn = 100;

/// Answers every warning about another VPN Begzar could not turn off, as the
/// root screen's dialog would: [goAnyway] is the user tapping Continue anyway,
/// and false is any other way out.
///
/// A container has no screen to raise the warning on, and an unanswered one
/// holds the connect or the measurement that raised it open.
void answerOtherVpnWarnings(
  ProviderContainer container, {
  required bool goAnyway,
}) {
  container.listen(otherVpnProvider, (_, next) {
    if (next?.verdict != OtherVpnVerdict.stillOn) return;
    container.read(otherVpnProvider.notifier).answerWarning(goAnyway: goAnyway);
  });
}

/// A [Random] that turns `List.shuffle` into a no-op, so a test can assert the
/// exact order configs are tried in.
///
/// `shuffle` is Fisher-Yates: it draws `pos = nextInt(length)`, decrements
/// `length`, then swaps `list[length]` with `list[pos]`. Returning `max - 1`
/// makes `pos` equal the post-decrement index every time, so each swap trades
/// an element with itself and the list comes out untouched.
///
/// That relies on the SDK's implementation, so
/// `connect_auto_use_case_test.dart` asserts the identity ordering directly.
/// If `shuffle` ever changes, that assertion fails loudly instead of silently
/// reordering every other test.
class NoShuffleRandom implements Random {
  const NoShuffleRandom();

  @override
  int nextInt(int max) => max - 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// A [ProxyCoreAdapter] for the repository's own tests: its tunnel start throws
/// [startFailure] or, with [startsCleanly], leaves the engine running, and its
/// latency probe answers [latencySamples].
///
/// Only what [ConnectionRepository.connect] reaches on its way to the start, and
/// what [ConnectionRepository.measurePing] reaches, is implemented. Anything
/// else lands in [noSuchMethod] and throws, so a test that wanders off the path
/// it means to cover fails loudly instead of passing on a default. Both starts
/// record the routing they were handed and then behave alike, because which one
/// runs depends on the host the suite runs on rather than on anything the test
/// sets.
class FakeProxyCoreAdapter implements ProxyCoreAdapter {
  FakeProxyCoreAdapter({
    this.startFailure,
    this.startsCleanly = false,
    this.stopFailure,
    this.latencySamples = const [],
    this.tunnelActive = false,
    this.engineAvailable = true,
    List<String>? events,
  }) : events = events ?? <String>[];

  /// False stands for a build made on the open stand-in, without the engine.
  @override
  final bool engineAvailable;

  /// What either tunnel start throws. A test that never starts one leaves it
  /// unset, and a start then fails as unscripted unless [startsCleanly].
  final Object? startFailure;

  /// Whether a start with no [startFailure] succeeds and leaves the engine
  /// running.
  final bool startsCleanly;

  /// What [stop] throws once it has been counted. The real adapter swallows
  /// its own stop errors, so this stands for whatever else could go wrong.
  final Object? stopFailure;

  final List<LatencySample> latencySamples;

  /// Whether Begzar's own tunnel is up, as [isTunnelActive] reports it.
  final bool tunnelActive;

  /// Each engine start and stop, as `engine.start` and `engine.stop`, in the
  /// order they happened. Hand the same list to a [FakeTunnelHelper] to read
  /// the order the two came and went in.
  final List<String> events;

  /// The app routing the last tunnel start was handed, whichever start it was.
  AppRouting? lastAppRouting;

  /// Whether the last proxy start bound the engine to the physical interface.
  bool lastBindPhysicalInterface = false;

  int stopCount = 0;

  bool _running = false;

  void _start() {
    events.add('engine.start');
    if (startFailure case final thrown?) throw thrown;
    if (!startsCleanly) throw UnsupportedError('No start scripted.');
    _running = true;
  }

  @override
  Future<void> initialize({
    Future<void> Function(bool isRunning)? onEngineStateChanged,
  }) async {}

  @override
  Future<bool> isTunnelActive() async => tunnelActive;

  @override
  Future<bool> isRunning() async => _running;

  /// As the real adapter answers off Apple: the engine is running, and in VPN
  /// mode the tunnel is up as well.
  @override
  Future<bool> isConnectionActive({required bool isVpnMode}) async =>
      _running && (!isVpnMode || tunnelActive);

  @override
  Future<void> stop() async {
    stopCount++;
    events.add('engine.stop');
    if (stopFailure case final thrown?) throw thrown;
    _running = false;
  }

  @override
  Future<void> startVpnMode(
    ProxyConfigEntity config, {
    String dnsServer = '8.8.8.8',
    AppRouting appRouting = AppRouting.none,
    CustomRoutingRules customRouting = CustomRoutingRules.empty,
  }) async {
    lastAppRouting = appRouting;
    _start();
  }

  @override
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
    lastAppRouting = appRouting;
    lastBindPhysicalInterface = bindPhysicalInterface;
    _start();
  }

  @override
  Future<List<LatencySample>> measurePing(List<String> urls) async =>
      latencySamples;

  /// What [measureTrafficProbes] throws, for a check that cannot run at all.
  Object? trafficProbeFailure;

  @override
  Future<List<LatencySample>> measureTrafficProbes() async {
    if (trafficProbeFailure case final thrown?) throw thrown;
    return latencySamples;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An [OtherVpnDataSource] that answers from [vpnOn] instead of the platform,
/// for the repository's own tests.
///
/// [failure] makes every call throw it, the way a platform channel with no
/// handler on the host does.
class FakeOtherVpnDataSource implements OtherVpnDataSource {
  FakeOtherVpnDataSource({this.vpnOn = false, this.failure});

  bool vpnOn;
  final Object? failure;

  int turnOffs = 0;

  void _failIfScripted() {
    if (failure case final thrown?) throw thrown;
  }

  @override
  Future<bool> isVpnOn() async {
    _failIfScripted();
    return vpnOn;
  }

  @override
  Future<void> turnOff() async {
    turnOffs++;
    _failIfScripted();
    vpnOn = false;
  }

  @override
  Future<bool> openVpnSettings() async {
    _failIfScripted();
    return true;
  }
}

/// A [TunnelHelper] that answers at once instead of launching anything, for the
/// repository's own tests.
///
/// [start] throws [startFailure] or leaves the helper running and carrying the
/// connection, and [loseTunnel] plays a helper that went away on its own,
/// which still leaves it carrying, as the real one does until [stop]. Unlike
/// the real one, [start] does not stop a running helper first, so a test sees
/// only the stops the repository asked for.
class FakeTunnelHelper implements TunnelHelper {
  FakeTunnelHelper({this.startFailure, List<String>? events})
    : events = events ?? <String>[];

  /// What [start] throws, as the real helper does for a declined admin prompt
  /// or a tunnel that would not come up. Null starts it.
  final Object? startFailure;

  /// Each start and stop, as `helper.start` and `helper.stop`, in the order
  /// they happened. Shared with a [FakeProxyCoreAdapter] the same way.
  final List<String> events;

  int startCount = 0;
  int stopCount = 0;

  /// What the last [start] was handed.
  int? lastSocksPort;
  AppRouting? lastAppRouting;

  /// Settable, so a test can leave a helper running from an earlier connect.
  @override
  bool isRunning = false;

  @override
  bool carriesConnection = false;

  final _lost = StreamController<void>.broadcast();

  @override
  Stream<void> get lost => _lost.stream;

  @override
  Future<void> start({
    required int socksPort,
    required AppRouting appRouting,
  }) async {
    startCount++;
    events.add('helper.start');
    lastSocksPort = socksPort;
    lastAppRouting = appRouting;
    if (startFailure case final thrown?) throw thrown;
    isRunning = true;
    carriesConnection = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    events.add('helper.stop');
    isRunning = false;
    carriesConnection = false;
  }

  /// Ends the lease from the helper's side, as a helper that exits or is
  /// killed does.
  void loseTunnel() {
    isRunning = false;
    _lost.add(null);
  }
}

/// Fake [ConnectionRepository] that replays scripted verdicts and records
/// which configs the caller actually reached.
///
/// `implements` against the concrete class: its constructor and private fields
/// are not part of the implicit interface across a library boundary, so only
/// the public methods need an implementation here.
class FakeConnectionRepository implements ConnectionRepository {
  FakeConnectionRepository({
    Map<String, Either<ConnectionFailure, bool>>? testVerdicts,
    Map<String, int>? probeDelays,
    this.disconnectResult,
    this.connectResult,
    this.connectionActive = false,
    this.serviceRunning = false,
    this.pingResult,
    this.tunnelStartedAtResult,
    this.throughHelper = false,
    Set<String>? googleOnly,
  }) : _testVerdicts = testVerdicts ?? const {},
       _probeDelays = probeDelays ?? const {},
       _googleOnly = googleOnly ?? const {};

  /// How long a config answers a batch probe in when its verdict passes and
  /// no delay was scripted for it.
  static const int defaultProbeDelayMs = 100;

  /// Verdict per config name. Names absent from the map fail their test.
  ///
  /// [measureDelays] reads the same map, so a config that passes its test also
  /// answers a batch probe. A refusal answers nothing in a batch: probing runs
  /// beside the tunnel rather than through it, so it never asks for the VPN
  /// permission a refusal stands for.
  final Map<String, Either<ConnectionFailure, bool>> _testVerdicts;

  /// Delay per config name for [measureDelays], for a test that cares which
  /// configs answered fastest. A scripted delay answers whatever the verdict.
  final Map<String, int> _probeDelays;

  /// Config names that answer a probe to Google and nothing else, as a server
  /// that only reaches Google does.
  final Set<String> _googleOnly;

  /// The real repository resolves these against what the OS will let it bind.
  /// Nothing here opens a socket, so the preferred ports stand in — a test that
  /// cares which port a reader was handed sets them.
  @override
  int activeSocksPort = kDefaultProxyPort;

  @override
  int activeHttpProxyPort = kDefaultHttpProxyPort;

  /// Overrides what [disconnect] returns; null means success.
  final Either<ConnectionFailure, Unit>? disconnectResult;

  /// Overrides what [connect] returns; null means a successful VPN-mode dial.
  final Either<ConnectionFailure, TunnelMode>? connectResult;

  /// What [isConnectionActive] reports. Mutable so a test can simulate the
  /// tunnel going down underneath a live connection.
  bool connectionActive;

  bool serviceRunning;

  final PingResult? pingResult;

  /// When [tunnelStartedAt] says the tunnel came up. Null is a platform that
  /// cannot say, which is what a desktop build and an older engine both do.
  final DateTime? tunnelStartedAtResult;

  /// Whether a connect is made through the Windows tunnel helper, as one is
  /// there when Tunnel is chosen. Off, this is every other platform and mode,
  /// where nothing stands in front of the engine.
  final bool throughHelper;

  /// Whether the helper the connection was made through is still running.
  /// [loseTunnel] ends it, and so does a disconnect.
  bool helperRunning = false;

  /// Set by a connect made [throughHelper] and cleared by a disconnect.
  /// Settable, so a test can find a helper connection it did not dial.
  @override
  bool connectedThroughHelper = false;

  final _tunnelLost = StreamController<void>.broadcast();

  /// Config names the caller tested, in the order it asked: one at a time
  /// through [testConfig], or a whole batch at once through [measureDelays]
  /// against Google.
  final List<String> testedConfigNames = <String>[];

  /// The `stopAfter` of each [measureDelays] call against Google, in call
  /// order.
  final List<int> probeStopAfters = <int>[];

  /// The config names of each [measureDelays] call against a host outside
  /// Google, in call order.
  final List<List<String>> outsideGoogleChecks = <List<String>>[];

  /// The `stopAfter` of each of those calls, in call order.
  final List<int> outsideGoogleStopAfters = <int>[];

  /// Holds a [measureDelays] call against a host outside Google open until
  /// the test completes it. [holdProbe] holds every probe; this holds only the
  /// check that follows the Google one.
  Completer<void>? holdOutsideGoogleCheck;

  /// Config names passed to [connect], in call order.
  final List<String> connectedConfigNames = <String>[];

  int disconnectCount = 0;

  /// Holds [measureDelays] and [testConfig] open until the test completes it,
  /// so something can be done to a connect while its probe is in flight.
  Completer<void>? holdProbe;

  /// Holds [connect] open the same way, before the tunnel comes up.
  Completer<void>? holdDial;

  /// Holds [disconnect] open the same way, before the tunnel goes down.
  Completer<void>? holdDisconnect;

  /// Holds [tunnelStartedAt] open the same way: the tunnel is up, and the
  /// connect that dialled it has yet to publish connected.
  Completer<void>? holdTunnelStartedAt;

  /// Whether another app's VPN is on, as [isOtherVpnOn] reports it. Mutable so
  /// a test can turn one on before it asks for a connect.
  bool otherVpnOn = false;

  /// Whether [turnOffOtherVpn] works. It does not against another app's
  /// always-on VPN on Android, or a third-party one on Windows.
  bool otherVpnYields = true;

  int otherVpnTurnOffs = 0;
  int vpnSettingsOpened = 0;

  /// Holds [turnOffOtherVpn] open until the test completes it, so something
  /// can be done to a connect while the other VPN is being turned off.
  Completer<void>? holdOtherVpnTurnOff;

  @override
  Future<bool> isOtherVpnOn() async => otherVpnOn;

  @override
  Future<void> turnOffOtherVpn() async {
    otherVpnTurnOffs++;
    await holdOtherVpnTurnOff?.future;
    if (otherVpnYields) otherVpnOn = false;
  }

  @override
  Future<bool> openVpnSettings() async {
    vpnSettingsOpened++;
    return true;
  }

  @override
  Future<DateTime?> tunnelStartedAt() async {
    await holdTunnelStartedAt?.future;
    return tunnelStartedAtResult;
  }

  @override
  Future<Either<ConnectionFailure, bool>> testConfig(
    ProxyConfigEntity config,
  ) async {
    testedConfigNames.add(config.name);
    await holdProbe?.future;
    return _testVerdicts[config.name] ?? right(false);
  }

  /// What a batch probe hears back from [name]: its scripted delay, the
  /// default one when its verdict passes, and nothing otherwise.
  int? _probeAnswer(String name) {
    final scripted = _probeDelays[name];
    if (scripted != null) return scripted;
    return switch (_testVerdicts[name]) {
      Right(value: true) => defaultProbeDelayMs,
      _ => null,
    };
  }

  /// Answers every config at once. Unlike the engine it never cancels the
  /// probes past `stopAfter`, so a test sees each scripted answer; the caller
  /// must not rely on the engine having cut the list short.
  @override
  Future<List<int?>> measureDelays(
    List<ProxyConfigEntity> configs, {
    required int stopAfter,
    ProbeTarget target = ProbeTarget.google,
  }) async {
    final names = [for (final config in configs) config.name];
    switch (target) {
      case ProbeTarget.google:
        probeStopAfters.add(stopAfter);
        testedConfigNames.addAll(names);
      case ProbeTarget.outsideGoogle:
        outsideGoogleChecks.add(names);
        outsideGoogleStopAfters.add(stopAfter);
        await holdOutsideGoogleCheck?.future;
    }
    await holdProbe?.future;
    return [
      for (final name in names)
        target == ProbeTarget.outsideGoogle && _googleOnly.contains(name)
            ? null
            : _probeAnswer(name),
    ];
  }

  /// Options the caller passed to [connect], in call order.
  final List<TunnelOptions> connectOptions = <TunnelOptions>[];

  @override
  Future<Either<ConnectionFailure, TunnelMode>> connect(
    ProxyConfigEntity config,
    TunnelOptions options, {
    bool Function()? isCancelled,
  }) async {
    connectedConfigNames.add(config.name);
    connectOptions.add(options);
    await holdDial?.future;
    final scripted = connectResult;
    if (scripted != null) return scripted;
    connectionActive = true;
    if (throughHelper) {
      connectedThroughHelper = true;
      helperRunning = true;
    }
    return right(TunnelMode.vpn);
  }

  /// The WARP modes [connectWarp] was asked for, in call order.
  final List<WarpMode> warpModes = <WarpMode>[];

  /// What [connectWarp] answers instead of succeeding, when set.
  Either<ConnectionFailure, TunnelMode>? warpResult;

  @override
  Future<Either<ConnectionFailure, TunnelMode>> connectWarp(
    WarpMode mode,
    TunnelOptions options,
  ) async {
    warpModes.add(mode);
    connectOptions.add(options);
    await holdDial?.future;
    final scripted = warpResult;
    if (scripted != null) return scripted;
    connectionActive = true;
    return right(TunnelMode.vpn);
  }

  /// The helper is stopped whatever the disconnect's result, as the real
  /// repository stops it even when the engine will not stop.
  @override
  Future<Either<ConnectionFailure, Unit>> disconnect() async {
    disconnectCount++;
    await holdDisconnect?.future;
    connectedThroughHelper = false;
    helperRunning = false;
    final scripted = disconnectResult;
    if (scripted != null) return scripted;
    connectionActive = false;
    return right(unit);
  }

  @override
  Future<PingResult> measurePing([List<String>? urls]) async =>
      pingResult ?? PingResult.failure('no ping scripted');

  /// What [isPassingTraffic] answers. Mutable so a test can stop a live
  /// tunnel's traffic, or bring it back, between checks.
  bool passingTraffic = true;

  /// How many times the tunnel was checked for traffic.
  int trafficChecks = 0;

  @override
  Future<bool> isPassingTraffic() async {
    trafficChecks++;
    return passingTraffic;
  }

  @override
  Future<bool> isRunning() async => serviceRunning;

  @override
  Future<bool> isConnectionActive(TunnelOptions options) async =>
      connectionActive;

  @override
  Stream<void> get tunnelLost => _tunnelLost.stream;

  @override
  bool get helperLost => connectedThroughHelper && !helperRunning;

  /// Plays the helper going away on its own, as one that exits or is killed
  /// does: it stops running, the connection reads as down, and the loss is
  /// reported on [tunnelLost].
  void loseTunnel() {
    helperRunning = false;
    connectionActive = false;
    _tunnelLost.add(null);
  }
}

/// What [proxyConfigsFromSubscription] calls the first URL a subscription
/// carries, and so the config a free-tier connect dials in these tests.
///
/// The free tier names its configs by position rather than from the payload,
/// so this is the server's answer as the connection module sees it — not
/// something [FakeApiV2Service] gets to choose.
const String kFreeTierConfigName = 'Server 1';

/// An [ApiV2Service] that answers from a scripted payload, so the free-tier
/// connect path never reaches the network.
///
/// `implements` against the concrete class: its constructor, private fields and
/// static members are not part of the implicit interface across a library
/// boundary, so only the public instance methods need an implementation here.
///
/// Overriding `apiV2ServiceProvider` with one of these is not optional for a
/// test that can reach the free path. The real service calls the production
/// API for real, and a 200 from it publishes into `ReleaseHintBus` — a
/// process-wide static with no seam, which then changes what every later test
/// in the same isolate does.
class FakeApiV2Service implements ApiV2Service {
  FakeApiV2Service({this.subscriptionResult});

  /// One config and no server version. The version is what the connect path
  /// hands to the update gate, and a null one leaves that gate nothing to
  /// enforce — which is what a test that is not about forced updates wants.
  /// The config carries a dialable scheme because the free path drops any
  /// line the engine cannot dial.
  static final SubscriptionPayload defaultSubscription = SubscriptionPayload(
    configUrls: ['${ProxyConfigValidator.supportedSchemes.first}free-tier'],
  );

  /// Overrides what [getVPNConfigurations] returns; null answers with
  /// [defaultSubscription].
  final Either<ApiFailure, SubscriptionPayload>? subscriptionResult;

  /// How many times the free path asked the server for configs.
  int fetchCount = 0;

  /// Holds [getVPNConfigurations] open until the test completes it, so
  /// something can be done to a connect while the server has yet to answer.
  Completer<void>? holdFetch;

  @override
  Future<Either<ApiFailure, SubscriptionPayload>> getVPNConfigurations() async {
    fetchCount++;
    await holdFetch?.future;
    return subscriptionResult ?? right(defaultSubscription);
  }

  @override
  Future<Either<ApiFailure, String>> initializeDevice() async =>
      right(_sessionToken);

  @override
  Future<Either<ApiFailure, String>> ensureSessionToken() async =>
      right(_sessionToken);

  @override
  Future<bool> isInitialized() async => true;

  @override
  Future<String?> getUserKey() async => _sessionToken;

  @override
  Future<void> clearCredentials() async {}

  static const String _sessionToken = 'test-session-token';
}

/// Neutral tunnel settings: the tunnel rather than either proxy mode, and no
/// app routing, unless the arguments say otherwise.
///
/// Above the repository it is faked in every test, so there the values only
/// need to be valid rather than meaningful. The repository's own tests pick
/// the mode with [proxyOnly] and [systemProxy].
TunnelOptions testTunnelOptions({
  AppRouting appRouting = AppRouting.none,
  bool proxyOnly = false,
  bool systemProxy = false,
}) => TunnelOptions(
  dnsServer: '8.8.8.8',
  proxyOnly: proxyOnly,
  systemProxy: systemProxy,
  listenAddress: kLocalhostListen,
  customRouting: const CustomRoutingRules(),
  appRouting: appRouting,
);

/// A service on [repository], reading the neutral options above.
///
/// Pass [random] to pin the order `connectAuto` tries its candidates in.
///
/// The real `AnalyticsService` is inert off Firebase — every log method returns
/// at the `isFirebaseSupported` guard — so there is nothing to fake here and
/// nothing leaves the test.
///
/// Waits for nothing between the checks after turning another VPN off, so a
/// test of one that stays on does not sit through the real settle time.
ConnectionService testConnectionService(
  ConnectionRepository repository, {
  Random? random,
  AnalyticsService? analytics,
}) => ConnectionService(
  repository,
  readOptions: testTunnelOptions,
  analytics: analytics ?? AnalyticsService(),
  random: random,
  otherVpnPollInterval: Duration.zero,
);

/// A line for the engine log fakes, numbered through its message.
EngineLogLine testLogLine(
  String message, {
  EngineLogComponent component = EngineLogComponent.xray,
  EngineLogLevel level = EngineLogLevel.warn,
}) {
  return EngineLogLine(
    time: DateTime(2026, 1, 1, 12),
    component: component,
    level: level,
    message: message,
    fromTunnel: false,
  );
}

/// The engine log repository, answering each read with the next queued batch
/// and recording what the viewer asked of it.
class FakeEngineLogRepository implements EngineLogRepository {
  final batches = <Either<ConnectionFailure, EngineLogBatch>>[];
  final reads = <bool>[]; // fromStart, per read
  final waits = <Duration>[];
  int clears = 0;
  Either<ConnectionFailure, Unit> clearResult = right(unit);
  Either<ConnectionFailure, EngineLogExportOutcome> exportResult = right(
    EngineLogExportOutcome.shared,
  );
  List<EngineLogLine>? exported;

  void queue(List<EngineLogLine> lines, {bool dropped = false}) =>
      batches.add(right(EngineLogBatch(lines: lines, dropped: dropped)));

  @override
  Future<Either<ConnectionFailure, EngineLogBatch>> read({
    bool fromStart = false,
    Duration wait = Duration.zero,
  }) async {
    reads.add(fromStart);
    waits.add(wait);
    // Taken now, as the engine would: what is queued when the read starts.
    final batch = batches.isEmpty ? null : batches.removeAt(0);
    final gate = readGate;
    if (gate != null) {
      readGate = null;
      await gate.future;
    }
    return batch ?? right(EngineLogBatch.empty);
  }

  /// When set, the next read holds its answer until it completes.
  Completer<void>? readGate;

  @override
  Future<Either<ConnectionFailure, Unit>> clear() async {
    clears++;
    return clearResult;
  }

  @override
  Future<Either<ConnectionFailure, EngineLogExportOutcome>> export(
    List<EngineLogLine> lines, {
    Rect? shareOrigin,
  }) async {
    exported = lines;
    return exportResult;
  }
}
