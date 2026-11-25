import 'dart:math';

import 'package:begzar/core/log/log.dart';
import 'package:begzar/core/services/analytics_service.dart';
import 'package:begzar/modules/begzar_core/domain/entities/proxy_config_entity.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/connection/domain/other_vpn_verdict.dart';
import 'package:begzar/modules/connection/domain/probe_target.dart';
import 'package:begzar/modules/connection/domain/proxy_config_validator.dart';
import 'package:begzar/modules/connection/domain/tunnel_mode.dart';
import 'package:begzar/modules/connection/domain/tunnel_options.dart';
import 'package:begzar/modules/connection/domain/value_objects/ping_result.dart';
import 'package:begzar/modules/connection/data/repositories/connection_repository.dart';
import 'package:begzar/modules/connection/data/tunnel_failures.dart';
import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';
import 'package:fpdart/fpdart.dart';

/// The application layer for connecting: everything the UI can ask for, and the
/// only thing that talks to [ConnectionRepository].
///
/// Each method turns an unexpected throw into a [ConnectionFailure] on the left,
/// so a caller never has to catch. The probes ([measurePing], [isRunning],
/// [isConnectionActive]) are deliberately total instead: a failed probe is an
/// answer, not an error, and reporting "not running" is what every caller would
/// do with a left anyway.
class ConnectionService {
  static const _log = Log('connect');

  /// How many of the fastest answers [connectAuto] draws its pick from.
  ///
  /// Also how many answers the probe waits for: the pick never reaches past
  /// these, so a dead config still timing out would only delay the connect.
  /// More than one so that quick connect does not send every user to the one
  /// server that happens to be fastest.
  ///
  /// Not raised to leave room for servers the check outside Google turns
  /// away: most server lists have only a few live servers, and a probe that
  /// waits for more answers than there are sits out the engine's timeout on
  /// the dead ones, which cost three to five seconds a connect when measured.
  static const _shortlistSize = 3;

  /// How long to wait between checks for another VPN to have gone, once
  /// [clearOtherVpn] has asked for it to go.
  ///
  /// A VPN taken down leaves the network a moment later rather than at once,
  /// so the first check after the attempt would often still see it.
  static const _otherVpnPollInterval = Duration(milliseconds: 200);

  /// How many of those checks find it still there before it is taken to have
  /// stayed on: three seconds, long past what a VPN going down takes, and
  /// short enough not to read as a hang on the way to a connect.
  static const _otherVpnPolls = 15;

  /// [readOptions] is called fresh on every connect, so a setting changed
  /// between attempts takes effect on the next one. It is a callback rather
  /// than a value because assembling it needs the Riverpod container, which
  /// neither this layer nor the repository may touch.
  ///
  /// [random] is injectable so tests can pin the order [connectAuto] probes
  /// configs in and which answer it draws. Production gets one unseeded
  /// source, reused across connects so successive attempts land on different
  /// servers.
  ///
  /// [otherVpnPollInterval] is injectable so a test of a VPN that stays on does
  /// not sit through the real wait.
  ConnectionService(
    this._repository, {
    required TunnelOptions Function() readOptions,
    required AnalyticsService analytics,
    Random? random,
    Duration otherVpnPollInterval = _otherVpnPollInterval,
  }) : _readOptions = readOptions,
       _analytics = analytics,
       _random = random ?? Random(),
       _pollInterval = otherVpnPollInterval;

  final ConnectionRepository _repository;
  final TunnelOptions Function() _readOptions;
  final AnalyticsService _analytics;
  final Random _random;
  final Duration _pollInterval;

  /// Emits when the Windows tunnel ends without a disconnect asking for it.
  /// Empty on every other platform.
  Stream<void> get tunnelLost => _repository.tunnelLost;

  /// Whether the connection up now was made through the Windows tunnel
  /// helper, which may since have gone. Never true anywhere else.
  bool get connectedThroughHelper => _repository.connectedThroughHelper;

  /// Whether the helper the connection up now was made through has gone.
  /// Answered at once, so a caller can act on it with nothing awaited between
  /// the answer and what it does.
  bool get helperLost => _repository.helperLost;

  /// Whether another app's VPN is up, without doing anything about it.
  Future<bool> isOtherVpnOn() => _repository.isOtherVpnOn();

  /// Waits for another VPN to go, checking every [_pollInterval], and reports
  /// whether it went.
  Future<bool> _otherVpnWent() async {
    for (var poll = 0; poll < _otherVpnPolls; poll++) {
      if (!await _repository.isOtherVpnOn()) return true;
      await Future<void>.delayed(_pollInterval);
    }
    return false;
  }

  /// Turns another app's VPN off where the platform allows it, and says what
  /// a check afterwards found.
  ///
  /// The verdict comes from that check rather than from the attempt, so a
  /// platform that cannot turn the VPN off — another app's always-on VPN on
  /// Android, a third-party one on Windows — never claims it did.
  Future<OtherVpnVerdict> clearOtherVpn() async {
    if (!await _repository.isOtherVpnOn()) return OtherVpnVerdict.none;

    _log.trace('otherVpn.turnOff');
    await _repository.turnOffOtherVpn();

    final went = await _otherVpnWent();
    _log.trace('otherVpn.verdict', {'went': went});
    return went ? OtherVpnVerdict.disconnected : OtherVpnVerdict.stillOn;
  }

  /// Opens the system's VPN settings, reporting whether anything opened.
  Future<bool> openVpnSettings() => _repository.openVpnSettings();

  /// How many connects [cancelConnect] has called off. A connect that started
  /// under an earlier count is one of them.
  int _cancellations = 0;

  /// The connect started last, kept so that a cancel can hand it on to the
  /// next one as [_unwinding].
  Future<void> _latest = Future<void>.value();

  /// What the connect [cancelConnect] last called off still has to finish.
  ///
  /// The next connect waits for it before probing. A cancelled dial that lands
  /// is taken straight back down, and that teardown stops the engine — which
  /// would take a new probe, or a new tunnel, down with it.
  Future<void> _unwinding = Future<void>.value();

  /// Runs [steps] as one connect that [cancelConnect] can call off.
  ///
  /// [steps] is handed a way to ask whether that has happened, and asks once
  /// each of its awaits returns, because nothing can take back a step already
  /// handed to the engine; it answers null once it finds it has. The connect
  /// does not begin until one cancelled before it has finished unwinding.
  Future<T?> _cancellable<T>(
    Future<T?> Function(bool Function() isCancelled) steps,
  ) async {
    final startedUnder = _cancellations;
    bool isCancelled() => startedUnder != _cancellations;

    await _unwinding;
    if (isCancelled()) return null;

    final run = steps(isCancelled);
    _latest = run;
    return run;
  }

  /// Takes down what a dial brought up after its connect was called off.
  ///
  /// The stop [cancelConnect] sent landed while the dial was still running, so
  /// the tunnel came up behind it. Nothing is recorded: the user never had
  /// this connection.
  Future<void> _abandonDial() async {
    _log.trace('cancel.teardown');
    await _repository.disconnect();
  }

  Future<Either<ConnectionFailure, Unit>?> _connectOne(
    ProxyConfigEntity config,
    bool Function() isCancelled,
  ) async {
    try {
      if (!ProxyConfigValidator.isDialable(config)) {
        _log.warn('one.rejected', {
          'config': config.name,
          'scheme': Log.scheme(config.url),
          'why': 'not dialable',
        });
        return left(const InvalidConfigFailure());
      }

      _log.trace('one.test', {
        'config': config.name,
        'scheme': Log.scheme(config.url),
      });
      final testResult = await _repository.testConfig(config);
      if (isCancelled()) {
        // The same teardown as a config that failed its test, for the same
        // reason: testing may have opened an Apple NE tunnel.
        await _repository.disconnect();
        return null;
      }
      switch (testResult) {
        case Left(value: final failure):
          _log.error('one.test.failed', {
            'reason': failure.runtimeType,
            'key': failure.userFacingKey,
          });
          return left(failure);
        case Right(value: final isWorking):
          if (!isWorking) {
            _log.warn('one.test.dead');
            // startTestMode may have opened an Apple NE tunnel; tear it down so
            // reconcileWithNative does not promote to connected after we fail.
            await _repository.disconnect();
            return left(const ProxyTestFailure());
          }
      }

      _log.trace('one.dial');
      final result = await _repository.connect(
        config,
        _readOptions(),
        isCancelled: isCancelled,
      );
      if (isCancelled()) {
        await _abandonDial();
        return null;
      }
      // The type argument is stated because this is the tail of an async
      // method: without it `fold` infers its return from the enclosing
      // `FutureOr` context and reads as an unawaited future inside a try.
      return result.fold<Either<ConnectionFailure, Unit>>(
        (failure) {
          _log.error('one.dial.failed', {
            'reason': failure.runtimeType,
            'key': failure.userFacingKey,
          });
          return left(failure);
        },
        (mode) {
          _log.trace('one.ok', {'mode': mode.name});
          _recordConnected(config, mode);
          return right(unit);
        },
      );
    } catch (e, stack) {
      _log.error('one.threw', {'type': e.runtimeType}, e, stack);
      return left(tunnelFailure('Connection failed', e));
    }
  }

  /// Connects to one config the caller chose, rejecting it up front if the
  /// engine cannot dial its scheme.
  ///
  /// Null when [cancelConnect] called it off before it finished — not a left,
  /// because nothing went wrong.
  Future<Either<ConnectionFailure, Unit>?> connect(ProxyConfigEntity config) =>
      _cancellable((isCancelled) => _connectOne(config, isCancelled));

  /// Connects on the WARP engine in [mode] (Experimental settings). There is
  /// no list to probe: the engine finds Cloudflare's endpoint itself, and a
  /// tunnel that comes up has already carried a request.
  ///
  /// Null when [cancelConnect] called it off before it finished.
  Future<Either<ConnectionFailure, Unit>?> connectWarp(WarpMode mode) =>
      _cancellable((isCancelled) => _connectWarp(mode, isCancelled));

  Future<Either<ConnectionFailure, Unit>?> _connectWarp(
    WarpMode mode,
    bool Function() isCancelled,
  ) async {
    try {
      _log.trace('warp.dial', {'mode': mode.engineName});
      final result = await _repository.connectWarp(mode, _readOptions());
      if (isCancelled()) {
        await _abandonDial();
        return null;
      }
      return result.fold<Either<ConnectionFailure, Unit>>(
        (failure) {
          _log.error('warp.dial.failed', {
            'reason': failure.runtimeType,
            'key': failure.userFacingKey,
          });
          return left(failure);
        },
        (tunnelMode) {
          _log.trace('warp.ok', {'mode': tunnelMode.name});
          _analytics.logUserConnected(
            configName: warpConfigName(mode),
            connectionMode: tunnelMode.analyticsLabel,
          );
          return right(unit);
        },
      );
    } catch (e, stack) {
      _log.error('warp.threw', {'type': e.runtimeType}, e, stack);
      return left(tunnelFailure('WARP connection failed', e));
    }
  }

  /// What analytics calls a connect on the WARP engine, in the place a
  /// server's name goes: there is no server, and the mode is what tells one
  /// such connect from another.
  static String warpConfigName(WarpMode mode) => 'warp:${mode.analyticsValue}';

  /// The [_shortlistSize] fastest of [candidates], fastest first, leaving out
  /// every one whose delay in [delays] is null.
  List<ProxyConfigEntity> _fastestAnswers(
    List<ProxyConfigEntity> candidates,
    List<int?> delays,
  ) {
    final answered = [
      for (var index = 0; index < candidates.length; index++)
        if (delays[index] case final delay?)
          (config: candidates[index], delay: delay),
    ]..sort((first, second) => first.delay.compareTo(second.delay));
    return [for (final answer in answered.take(_shortlistSize)) answer.config];
  }

  /// The servers of [shortlist] that also reach a host outside Google, in the
  /// order [shortlist] gives them.
  ///
  /// A server can answer Google and fail the TLS handshake with every other
  /// host, and a tunnel through it loads almost nothing. When not one of
  /// [shortlist] reaches the second host, the host itself is as likely the
  /// fault, so [shortlist] comes back whole, as it was drawn from before this
  /// check: an outage there must not refuse every connect.
  Future<List<ProxyConfigEntity>> _reachingOutsideGoogle(
    List<ProxyConfigEntity> shortlist,
  ) async {
    // No early stop: every one of the shortlist is a candidate for the draw.
    final delays = await _repository.measureDelays(
      shortlist,
      stopAfter: 0,
      target: ProbeTarget.outsideGoogle,
    );
    final reaching = [
      for (var index = 0; index < shortlist.length; index++)
        if (delays[index] != null) shortlist[index],
    ];
    if (reaching.isEmpty) {
      _log.warn('auto.outsideGoogle.none', {'checked': shortlist.length});
      return shortlist;
    }
    _log.trace('auto.outsideGoogle', {
      'checked': shortlist.length,
      'reaching': reaching.length,
    });
    return reaching;
  }

  Future<Either<ConnectionFailure, ProxyConfigEntity>?> _connectAuto(
    List<ProxyConfigEntity> configs,
    bool Function() isCancelled,
  ) async {
    try {
      if (configs.isEmpty) {
        _log.warn('auto.empty');
        return left(const NoWorkingConfigFailure(0, 'No configs available'));
      }

      // Both tiers hand over the server's list in the server's order, and that
      // order does not change between fetches. The engine starts probes in the
      // order it is handed them, a few at a time, so a fixed order would keep
      // giving the same servers the head start. The order is randomized here
      // instead.
      //
      // The copy matters: the list belongs to the caller. Shuffling in place
      // would reorder the premium server list the UI is showing. Picking a
      // server by hand goes through [connect] and is never reordered.
      final candidates = [...configs]..shuffle(_random);
      _log.trace('auto.start', {'candidates': candidates.length});

      final delays = await _repository.measureDelays(
        candidates,
        stopAfter: _shortlistSize,
      );
      // No teardown, for the reason the exhausted probe below needs none.
      if (isCancelled()) return null;
      final fastest = _fastestAnswers(candidates, delays);

      if (fastest.isEmpty) {
        // No teardown: probing runs beside the tunnel rather than through it,
        // so a probe that found nothing left nothing up.
        _log.error('auto.exhausted', {'tested': configs.length});
        return left(
          NoWorkingConfigFailure(
            configs.length,
            'No working config found after testing ${configs.length}',
          ),
        );
      }

      final shortlist = await _reachingOutsideGoogle(fastest);
      if (isCancelled()) return null;
      final landedOn = shortlist[_random.nextInt(shortlist.length)];

      _log.trace('auto.dial', {
        'config': landedOn.name,
        'scheme': Log.scheme(landedOn.url),
        'shortlist': shortlist.length,
      });
      // On Apple this opens the tunnel itself: nothing was opened while
      // probing, so there is no test tunnel to reuse as a hand-picked config
      // has.
      final result = await _repository.connect(
        landedOn,
        _readOptions(),
        isCancelled: isCancelled,
      );
      if (isCancelled()) {
        await _abandonDial();
        return null;
      }
      return result.fold<Either<ConnectionFailure, ProxyConfigEntity>>(
        (failure) {
          _log.error('auto.dial.failed', {
            'reason': failure.runtimeType,
            'key': failure.userFacingKey,
          });
          return left(failure);
        },
        (mode) {
          _log.trace('auto.ok', {'mode': mode.name});
          _recordConnected(landedOn, mode);
          return right(landedOn);
        },
      );
    } catch (e, stack) {
      _log.error('auto.threw', {'type': e.runtimeType}, e, stack);
      return left(tunnelFailure('Auto-connection failed', e));
    }
  }

  /// Probes every one of [configs] at once, then connects to one of the
  /// fastest to answer.
  ///
  /// The list is always the caller's: proxy configs come from the server alone,
  /// so an empty list fails with [NoWorkingConfigFailure] rather than falling
  /// back to anything bundled into the app.
  ///
  /// The probe returns once [_shortlistSize] configs have answered. Those are
  /// checked against a host outside Google, and the pick is drawn at random
  /// from the ones that reach it too — see [_reachingOutsideGoogle]. A dial
  /// that fails is reported as it is rather than retried on the next answer,
  /// as it was when configs were tested one at a time.
  ///
  /// Returns the config that dialled, not [unit]. The candidates are shuffled
  /// and the pick is drawn, so which one landed is not something the caller can
  /// work out from the list it passed in — and a caller that has to record
  /// where it ended up (the premium list's last-connected badge) has no other
  /// way to find out.
  ///
  /// Null when [cancelConnect] called it off, as with [connect].
  Future<Either<ConnectionFailure, ProxyConfigEntity>?> connectAuto(
    List<ProxyConfigEntity> configs,
  ) => _cancellable((isCancelled) => _connectAuto(configs, isCancelled));

  /// Calls off the connect in flight, wherever it has got to.
  ///
  /// The engine is stopped now rather than once the step under way returns:
  /// that is what cuts a running probe short, and a dial still running lands
  /// behind it. Whatever that step does bring up is taken back down by the
  /// connect itself when it returns, and the next connect waits for that.
  ///
  /// Not a disconnect as far as analytics is concerned: nothing connected.
  Future<void> cancelConnect() async {
    _cancellations++;
    _unwinding = _latest;
    _log.trace('cancel');
    await _repository.disconnect();
  }

  /// Completes once the connect [cancelConnect] last called off has finished
  /// unwinding, its teardown included.
  ///
  /// Until then a tunnel its dial brought up may still be standing, and asking
  /// the platform whether one is would report a connection the user called
  /// off.
  Future<void> settleCancelledConnect() => _unwinding;

  /// [connectedFor] is how long the tunnel being taken down was up. It is null
  /// when none was, and then no session ended for analytics to record: a
  /// second request for the same tunnel, or a connect called off before it
  /// landed.
  Future<Either<ConnectionFailure, Unit>> disconnect({
    Duration? connectedFor,
  }) async {
    try {
      final result = await _repository.disconnect();
      return result.map((_) {
        if (connectedFor != null) {
          _analytics.logUserDisconnected(
            connectionDuration: connectedFor.inSeconds,
          );
        }
        return unit;
      });
    } catch (e) {
      return left(tunnelFailure('Disconnect failed', e));
    }
  }

  /// Records a connect that happened, without making the caller wait on it.
  ///
  /// Deliberately not awaited: analytics is a side channel, and the tunnel is
  /// already up by the time this runs. `AnalyticsService` swallows its own
  /// failures, so there is nothing here for a caller to handle.
  void _recordConnected(ProxyConfigEntity config, TunnelMode mode) {
    _analytics.logUserConnected(
      configName: config.name,
      connectionMode: mode.analyticsLabel,
    );
  }

  /// Records a connect the user asked for that ended without a tunnel.
  ///
  /// The notifier calls this rather than [connect] and [connectAuto] recording
  /// their own failures, because a connect also fails before it gets here: a
  /// server list that could not be fetched, or an update gate that threw.
  void recordFailedConnect(
    String reason,
    ConnectSelection selection, {
    String? configName,
  }) {
    _analytics.logConnectionFailed(
      reason: reason,
      selection: selection,
      configName: configName,
    );
  }

  Future<PingResult> measurePing([List<String>? urls]) async {
    try {
      return await _repository.measurePing(urls);
    } catch (e) {
      return PingResult.failure('Ping measurement failed: $e');
    }
  }

  /// Whether the live tunnel still carries traffic; see
  /// `ConnectionRepository.isPassingTraffic`.
  Future<bool> isPassingTraffic() => _repository.isPassingTraffic();

  Future<bool> isRunning() async {
    try {
      return await _repository.isRunning();
    } catch (_) {
      return false;
    }
  }

  /// Whether the connection is truly up: the engine, plus the VPN tunnel where
  /// the platform uses one.
  Future<bool> isConnectionActive() async {
    try {
      return await _repository.isConnectionActive(_readOptions());
    } catch (_) {
      return false;
    }
  }

  /// When the live tunnel came up, as the platform records it, or null when it
  /// has no answer — an older engine, a desktop build, or no tunnel at all.
  ///
  /// Total for the same reason the two probes above are: a platform that will
  /// not say when a tunnel started has not failed at anything, it has simply
  /// left the caller to fall back on the time it noticed.
  Future<DateTime?> tunnelStartedAt() async {
    try {
      return await _repository.tunnelStartedAt();
    } catch (_) {
      return null;
    }
  }
}
