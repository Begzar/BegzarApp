/// A stand-in for Begzar's private proxy engine.
///
/// It has the engine's public API, so the app compiles and runs without the
/// engine: every screen opens, and everything that needs the engine fails the
/// way it would with no network. It connects nothing, measures nothing and
/// reaches no backend. A release build refuses it (`scripts/verify_engine.sh`).
///
/// Switch to it with `scripts/use_engine.sh stub`, and back with
/// `scripts/use_engine.sh private`. To drive the premium screens, run
/// `tool/fake_backend/main.dart`, which answers them in memory.
library;

import 'dart:async';

import 'package:begzar_engine/models/backend.dart';
import 'package:begzar_engine/models/begzar_engine_config.dart';
import 'package:begzar_engine/models/begzar_engine_exception.dart';
import 'package:begzar_engine/models/begzar_notification_text.dart';
import 'package:begzar_engine/models/engine_config_request.dart';
import 'package:begzar_engine/models/engine_log.dart';
import 'package:begzar_engine/models/latency_sample.dart';
import 'package:begzar_engine/models/real_delay_sample.dart';

export 'package:begzar_engine/models/backend.dart';
export 'package:begzar_engine/models/begzar_engine_exception.dart';
export 'package:begzar_engine/models/begzar_notification_text.dart';
export 'package:begzar_engine/models/engine_config_request.dart';
export 'package:begzar_engine/models/engine_log.dart';
export 'package:begzar_engine/models/latency_sample.dart';
export 'package:begzar_engine/models/real_delay_sample.dart';

class BegzarEngine {
  BegzarEngine._();

  static final BegzarEngine _instance = BegzarEngine._();
  static BegzarEngine get ins => _instance;

  static const _absent = 'The proxy engine is not part of this build.';

  /// The engine answers true; this stand-in is what a build without it runs
  /// on, so the app can say the engine is missing.
  bool get isAvailable => false;

  void setIosTunnelInfo(String appName, String appTunnelBundle) {}

  Future<void> initialize({
    Future<void> Function(bool isRunning)? onEngineStateChanged,
  }) async {
    await onEngineStateChanged?.call(false);
  }

  Future<void> start(
    BegzarEngineConfig config, {
    BegzarNotificationText? notification,
  }) async =>
      throw BegzarEngineException.message(_absent);

  Future<void> simpleStart(
    BegzarEngineConfig config, {
    BegzarNotificationText? notification,
  }) async =>
      throw BegzarEngineException.message(_absent);

  Future<void> stop() async {}

  Future<void> takeOverVpn() async {}

  Future<bool> get isRunning async => false;

  Future<String> retrieveLogs() async => '';

  Future<void> purgeLogs() async {}

  /// Every target unreachable.
  Future<List<LatencySample>> measureLatency(List<String> targets) async => [
        for (final target in targets) LatencySample(url: target, elapsedMs: -1),
      ];

  /// Every link unreachable.
  Future<List<RealDelaySample>> realDelayAll(
    List<String> shareLinks, {
    String endpoint = '',
    int maxWorkers = 0,
    int stopAfter = 0,
  }) async =>
      [
        for (var i = 0; i < shareLinks.length; i++)
          RealDelaySample(index: i, elapsedMs: -1),
      ];

  Future<String> buildEngineConfig(EngineConfigRequest request) async =>
      throw BegzarEngineException.message(_absent);

  /// Every operation fails as the engine missing.
  final BegzarBackend backend = const _AbsentBackend();

  Future<EngineLogPage> readEngineLog([
    EngineLogCursor cursor = EngineLogCursor.start,
    Duration wait = Duration.zero,
  ]) async {
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    return EngineLogPage(entries: const [], cursor: cursor, dropped: false);
  }

  Future<void> clearEngineLog() async {}
}

class _AbsentBackend implements BegzarBackend {
  const _AbsentBackend();

  static const _missing = BackendException(
    BackendFailureKind.engineMissing,
    message: BegzarEngine._absent,
  );

  @override
  Future<BackendAnswer<String>> registerSession() async => throw _missing;

  @override
  Future<BackendAnswer<List<String>>> fetchFreeServers({
    required String sessionKey,
    required String deviceId,
  }) async =>
      throw _missing;

  @override
  Future<BackendAnswer<List<BackendPromotion>>> fetchPromotions({
    required String sessionKey,
    required String deviceId,
  }) async =>
      throw _missing;

  @override
  Future<BackendAnswer<BackendVersionCatalog?>> appVersionCatalog() async =>
      throw _missing;

  @override
  Future<BackendAnswer<String?>> lookupRegionCountry() async => throw _missing;

  @override
  Future<BackendAnswer<BackendExitReading>> lookupExit({
    String viaSocks5 = '',
  }) async =>
      throw _missing;

  @override
  Future<BackendAnswer<BackendSession>> premiumSignIn({
    required String username,
    required String password,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  }) async =>
      throw _missing;

  @override
  Future<BackendAnswer<BackendAccountData>> premiumAccount(
    BackendPremiumCredentials credentials,
  ) async =>
      throw _missing;

  @override
  Future<BackendAnswer<void>> premiumSignOut(
    BackendPremiumCredentials credentials,
  ) async =>
      throw _missing;

  @override
  Future<BackendAnswer<int>> premiumRemoveDevice({
    required String deviceId,
    required BackendPremiumCredentials credentials,
  }) async =>
      throw _missing;

  @override
  Future<BackendAnswer<List<BackendPremiumServer>>> premiumServers(
    BackendPremiumCredentials credentials,
  ) async =>
      throw _missing;

  @override
  Future<BackendAnswer<int?>> requestSignUpCode({
    required String email,
    required String password,
    required BackendPremiumCredentials credentials,
  }) async =>
      throw _missing;

  @override
  Future<BackendAnswer<int?>> resendSignUpCode({
    required String email,
    required BackendPremiumCredentials credentials,
  }) async =>
      throw _missing;

  @override
  Future<BackendAnswer<BackendSession>> confirmSignUp({
    required String email,
    required String code,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  }) async =>
      throw _missing;

  @override
  Future<BackendAnswer<void>> deleteAccount({
    required String password,
    required BackendPremiumCredentials credentials,
  }) async =>
      throw _missing;

  @override
  Future<BackendAnswer<List<BackendPlan>>> premiumPlans() async =>
      throw _missing;

  @override
  Future<BackendAnswer<void>> reportPlayPurchase({
    required String productId,
    required String purchaseToken,
    required BackendPremiumCredentials credentials,
  }) async =>
      throw _missing;
}
