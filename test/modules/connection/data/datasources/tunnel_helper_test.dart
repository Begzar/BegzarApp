import 'dart:async';
import 'dart:io';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/modules/connection/data/datasources/tunnel_helper.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A lease token in the shape the helper checks. A real one is drawn fresh for
/// every connect.
const _token = '0123456789abcdef0123456789abcdef';

/// A token-shaped value no connect draws, for the connection that must be
/// turned away.
final _wrongToken = '0' * 32;

const _socksPort = 10808;
const _parentPid = 4242;

/// Gives a broken implementation a few seconds to fail rather than the
/// production fifteen.
const _testReadyTimeout = Duration(seconds: 5);

/// Long enough for a close on one end of a loopback socket to reach the other.
const _settle = Duration(milliseconds: 100);

const _channel = MethodChannel('begzar/tunnel_helper');

final _tunnelUnavailable = isA<TunnelFailure>().having(
  (failure) => failure.userFacingKey,
  'userFacingKey',
  UserFacingErrorKeys.tunnelUnavailable,
);

/// The value after [flag] in a command line split on spaces. Good enough for
/// the port and the token, which never hold a space.
String _valueAfter(List<String> arguments, String flag) =>
    arguments[arguments.indexOf(flag) + 1];

/// The helper's end of one lease connection.
class _HelperEnd {
  _HelperEnd(this.socket)
    : closed = socket.drain<void>().then((_) {}, onError: (Object _) {});

  final Socket socket;

  /// Completes once the app has closed this connection.
  final Future<void> closed;
}

/// Plays `begzar-tun.exe` over a real loopback socket.
///
/// It reads the lease port and the token out of the command line the helper
/// would have been started with, so the app's side is exercised from the
/// arguments it builds to the lines it reads back.
class _FakeLauncher implements TunnelHelperLauncher {
  _FakeLauncher({this.outcome = HelperLaunchOutcome.started, this.helper});

  final HelperLaunchOutcome outcome;

  /// What the helper does once it is running, handed the lease port and the
  /// token. Null for a helper that never dials back.
  final Future<void> Function(int leasePort, String token)? helper;

  /// Every connection the helper opened, in order.
  final ends = <_HelperEnd>[];

  String? commandLine;
  int? leasePort;

  /// Dials the lease port and writes [text] exactly as given.
  Future<_HelperEnd> dial(int port, String text) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    final end = _HelperEnd(socket);
    ends.add(end);
    socket.write(text);
    await socket.flush();
    return end;
  }

  /// Dials the lease port and writes [lines], each ended by a newline.
  Future<_HelperEnd> say(int port, List<String> lines) =>
      dial(port, lines.map((line) => '$line\n').join());

  void closeAll() {
    for (final end in ends) {
      end.socket.destroy();
    }
  }

  @override
  Future<HelperLaunchOutcome> launch(String commandLine) async {
    this.commandLine = commandLine;
    final arguments = commandLine.split(' ');
    final port = int.parse(_valueAfter(arguments, '--lease-port'));
    leasePort = port;
    final play = helper;
    if (outcome == HelperLaunchOutcome.started && play != null) {
      unawaited(play(port, _valueAfter(arguments, '--token')));
    }
    return outcome;
  }
}

/// A helper that says hello with the right token, then [reply].
_FakeLauncher _helperReplying(String reply) {
  late final _FakeLauncher launcher;
  launcher = _FakeLauncher(
    helper: (port, token) => launcher.say(port, ['HELLO $token', reply]),
  );
  return launcher;
}

TunnelHelper _tunnelHelper(
  _FakeLauncher launcher, {
  Duration readyTimeout = _testReadyTimeout,
}) {
  final helper = TunnelHelper(
    launcher: launcher,
    readyTimeout: readyTimeout,
    parentPid: _parentPid,
  );
  addTearDown(() async {
    await helper.stop();
    launcher.closeAll();
  });
  return helper;
}

/// Fails unless [port] can be bound again, which it cannot while anything is
/// still listening on it.
Future<void> _expectNothingListening(int port) async {
  final rebound = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
  await rebound.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('windowsCommandLine', () {
    test('should leave plain arguments bare', () {
      expect(
        windowsCommandLine(['--app-mode', 'all-except', r'C:\dir\app.exe']),
        r'--app-mode all-except C:\dir\app.exe',
      );
    });

    test('should quote an argument with a space', () {
      expect(windowsCommandLine(['--app', 'My App.exe']), '--app "My App.exe"');
    });

    test('should escape an embedded quote', () {
      expect(windowsCommandLine([r'a"b']), r'"a\"b"');
    });

    test('should double backslashes before a closing quote', () {
      expect(windowsCommandLine([r'c:\dir with\']), r'"c:\dir with\\"');
    });

    // Backslashes count only when a quote follows them, and an escaped quote
    // is one of those.
    test('should double backslashes before an embedded quote', () {
      expect(windowsCommandLine([r'a\"b']), r'"a\\\"b"');
    });

    // Left bare, an empty argument would vanish and shift every one after it.
    test('should quote an empty argument', () {
      expect(windowsCommandLine(['--app', '']), '--app ""');
    });
  });

  group('helperArguments', () {
    test('should name each picked app once for all-except', () {
      final arguments = helperArguments(
        leasePort: 50000,
        token: _token,
        socksPort: _socksPort,
        parentPid: _parentPid,
        appRouting: const AppRouting(
          mode: AppRoutingMode.allExcept,
          apps: ['My App.exe', 'tool.exe'],
        ),
      );

      expect(arguments, [
        '--lease-port',
        '50000',
        '--token',
        _token,
        '--socks-port',
        '$_socksPort',
        '--parent-pid',
        '$_parentPid',
        '--app-mode',
        'all-except',
        '--app',
        'My App.exe',
        '--app',
        'tool.exe',
      ]);
    });

    test('should send only-some with the picked apps for only selected', () {
      final arguments = helperArguments(
        leasePort: 50000,
        token: _token,
        socksPort: _socksPort,
        parentPid: _parentPid,
        appRouting: const AppRouting(
          mode: AppRoutingMode.onlySelected,
          apps: ['tool.exe'],
        ),
      );

      expect(arguments.sublist(8), [
        '--app-mode',
        'only-some',
        '--app',
        'tool.exe',
      ]);
    });

    // The helper refuses only-some or all-except with no apps, and the app
    // sends no rules at all for an empty pick.
    test('should send mode none when no app is picked', () {
      for (final appRouting in const [
        AppRouting.none,
        AppRouting(mode: AppRoutingMode.onlySelected, apps: []),
      ]) {
        final arguments = helperArguments(
          leasePort: 50000,
          token: _token,
          socksPort: _socksPort,
          parentPid: _parentPid,
          appRouting: appRouting,
        );

        expect(arguments.sublist(8), [
          '--app-mode',
          'none',
        ], reason: '$appRouting');
      }
    });
  });

  group('PlatformTunnelHelperLauncher', () {
    void answerChannel(Future<Object?> Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, handler);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, null),
      );
    }

    test('should send the command line and read the answer by name', () async {
      MethodCall? received;
      answerChannel((call) async {
        received = call;
        return 'declined';
      });

      final outcome = await const PlatformTunnelHelperLauncher().launch(
        '--app "My App.exe"',
      );

      expect(outcome, HelperLaunchOutcome.declined);
      expect(received?.method, 'launch');
      expect(received?.arguments, {'parameters': '--app "My App.exe"'});
    });

    test('should read no answer or an unknown one as failed', () async {
      for (final answer in [null, 'elevated']) {
        answerChannel((_) async => answer);

        expect(
          await const PlatformTunnelHelperLauncher().launch('--app-mode none'),
          HelperLaunchOutcome.failed,
          reason: '$answer',
        );
      }
    });
  });

  group('TunnelHelper', () {
    test('should run once the helper says hello and ready', () async {
      final launcher = _helperReplying('READY');
      final helper = _tunnelHelper(launcher);

      await helper.start(socksPort: _socksPort, appRouting: AppRouting.none);

      expect(helper.isRunning, isTrue);
      final arguments = launcher.commandLine!.split(' ');
      expect(_valueAfter(arguments, '--socks-port'), '$_socksPort');
      expect(_valueAfter(arguments, '--parent-pid'), '$_parentPid');
      expect(_valueAfter(arguments, '--token'), matches(r'^[0-9a-f]{32}$'));
    });

    test('should throw ElevationDeclinedFailure when the prompt is declined, '
        'and leave nothing listening', () async {
      final launcher = _FakeLauncher(outcome: HelperLaunchOutcome.declined);
      final helper = _tunnelHelper(launcher);

      await expectLater(
        helper.start(socksPort: _socksPort, appRouting: AppRouting.none),
        throwsA(isA<ElevationDeclinedFailure>()),
      );

      expect(helper.isRunning, isFalse);
      await _expectNothingListening(launcher.leasePort!);
    });

    test('should throw tunnelUnavailable when the helper is missing', () async {
      final launcher = _FakeLauncher(outcome: HelperLaunchOutcome.missing);
      final helper = _tunnelHelper(launcher);

      await expectLater(
        helper.start(socksPort: _socksPort, appRouting: AppRouting.none),
        throwsA(_tunnelUnavailable),
      );

      expect(helper.isRunning, isFalse);
      await _expectNothingListening(launcher.leasePort!);
    });

    test(
      'should throw tunnelUnavailable when the helper reports an error',
      () async {
        final launcher = _helperReplying('ERROR adapter_failed');
        final helper = _tunnelHelper(launcher);

        await expectLater(
          helper.start(socksPort: _socksPort, appRouting: AppRouting.none),
          throwsA(
            _tunnelUnavailable.having(
              (failure) => failure.message,
              'message',
              contains('adapter_failed'),
            ),
          ),
        );

        expect(helper.isRunning, isFalse);
        // The app hangs up, which is what ends a helper that is still up.
        await launcher.ends.single.closed.timeout(_settle * 20);
      },
    );

    test(
      'should throw tunnelUnavailable when the helper never connects',
      () async {
        final launcher = _FakeLauncher();
        final helper = _tunnelHelper(
          launcher,
          readyTimeout: const Duration(milliseconds: 100),
        );

        await expectLater(
          helper.start(socksPort: _socksPort, appRouting: AppRouting.none),
          throwsA(_tunnelUnavailable),
        );

        expect(helper.isRunning, isFalse);
        await _expectNothingListening(launcher.leasePort!);
      },
    );

    // A helper that never says ready may still be up, and only the lease
    // closing takes it down.
    test(
      'should hang up on a helper that says hello but never ready',
      () async {
        late final _FakeLauncher launcher;
        launcher = _FakeLauncher(
          helper: (port, token) => launcher.say(port, ['HELLO $token']),
        );
        final helper = _tunnelHelper(
          launcher,
          readyTimeout: const Duration(milliseconds: 300),
        );

        await expectLater(
          helper.start(socksPort: _socksPort, appRouting: AppRouting.none),
          throwsA(_tunnelUnavailable),
        );

        expect(helper.isRunning, isFalse);
        await launcher.ends.single.closed.timeout(_settle * 20);
      },
    );

    test('should ignore a connection with the wrong token', () async {
      late final _FakeLauncher launcher;
      launcher = _FakeLauncher(
        helper: (port, token) async {
          final stranger = await launcher.say(port, ['HELLO $_wrongToken']);
          // The app hangs up on it, and only then does the real helper dial.
          await stranger.closed;
          await launcher.say(port, ['HELLO $token', 'READY']);
        },
      );
      final helper = _tunnelHelper(launcher);

      await helper.start(socksPort: _socksPort, appRouting: AppRouting.none);

      expect(helper.isRunning, isTrue);
      expect(launcher.ends, hasLength(2));
    });

    // A first line is "HELLO " and 32 hex characters, so a connection still
    // without a newline long after that is not the helper, and reading on
    // would only buffer whatever it sends.
    test('should close a connection that sends an overlong line', () async {
      late final _FakeLauncher launcher;
      launcher = _FakeLauncher(
        helper: (port, token) async {
          final stranger = await launcher.dial(port, 'x' * 4096);
          await stranger.closed;
          await launcher.say(port, ['HELLO $token', 'READY']);
        },
      );
      final helper = _tunnelHelper(launcher);

      await helper.start(socksPort: _socksPort, appRouting: AppRouting.none);

      expect(helper.isRunning, isTrue);
      expect(launcher.ends, hasLength(2));
    });

    test('should throw tunnelUnavailable when the helper replies with an '
        'overlong line', () async {
      late final _FakeLauncher launcher;
      launcher = _FakeLauncher(
        helper: (port, token) =>
            launcher.dial(port, 'HELLO $token\n${'x' * 4096}'),
      );
      // Only the cap can end this in time: the wait for READY outlasts the
      // test.
      final helper = _tunnelHelper(
        launcher,
        readyTimeout: const Duration(minutes: 1),
      );

      await expectLater(
        helper.start(socksPort: _socksPort, appRouting: AppRouting.none),
        throwsA(_tunnelUnavailable),
      ).timeout(_settle * 20);

      expect(helper.isRunning, isFalse);
      await launcher.ends.single.closed.timeout(_settle * 20);
    });

    // Connections are greeted side by side, so one that dials first and then
    // says nothing cannot keep the helper behind it waiting.
    test('should start while a silent stranger holds a connection', () async {
      late final _HelperEnd stranger;
      late final _FakeLauncher launcher;
      launcher = _FakeLauncher(
        helper: (port, token) async {
          stranger = await launcher.dial(port, 'HEL');
          await launcher.say(port, ['HELLO $token', 'READY']);
        },
      );
      final helper = _tunnelHelper(launcher);

      await helper.start(socksPort: _socksPort, appRouting: AppRouting.none);

      expect(helper.isRunning, isTrue);
      await stranger.closed.timeout(_settle * 20);
    });

    test('should report lost once when the helper closes the lease', () async {
      final launcher = _helperReplying('READY');
      final helper = _tunnelHelper(launcher);
      await helper.start(socksPort: _socksPort, appRouting: AppRouting.none);
      var losses = 0;
      final subscription = helper.lost.listen((_) => losses++);
      addTearDown(subscription.cancel);
      final lost = helper.lost.first;

      launcher.ends.single.socket.destroy();
      await lost.timeout(_settle * 20);
      await helper.stop();
      await Future<void>.delayed(_settle);

      expect(losses, 1);
      expect(helper.isRunning, isFalse);
    });

    test('should not report lost after stop', () async {
      final launcher = _helperReplying('READY');
      final helper = _tunnelHelper(launcher);
      await helper.start(socksPort: _socksPort, appRouting: AppRouting.none);
      var losses = 0;
      final subscription = helper.lost.listen((_) => losses++);
      addTearDown(subscription.cancel);

      await helper.stop();
      // The helper sees its lease end, which is what takes the tunnel down.
      await launcher.ends.single.closed.timeout(_settle * 20);
      await helper.stop();
      await Future<void>.delayed(_settle);

      expect(losses, 0);
      expect(helper.isRunning, isFalse);
    });

    test('should carry the connection from ready until stopped', () async {
      final launcher = _helperReplying('READY');
      final helper = _tunnelHelper(launcher);
      expect(helper.carriesConnection, isFalse);

      await helper.start(socksPort: _socksPort, appRouting: AppRouting.none);
      expect(helper.carriesConnection, isTrue);

      await helper.stop();
      expect(helper.carriesConnection, isFalse);
    });

    // The connection was made through it, and only a stop ends that: the
    // engine behind a lost helper still runs, and whoever asks has to know
    // there is a tunnel to take down.
    test('should still carry the connection once the helper is lost', () async {
      final launcher = _helperReplying('READY');
      final helper = _tunnelHelper(launcher);
      await helper.start(socksPort: _socksPort, appRouting: AppRouting.none);
      final lost = helper.lost.first;

      launcher.ends.single.socket.destroy();
      await lost.timeout(_settle * 20);

      expect(helper.isRunning, isFalse);
      expect(helper.carriesConnection, isTrue);

      await helper.stop();
      expect(helper.carriesConnection, isFalse);
    });

    test('should not carry a connection that never became ready', () async {
      final launcher = _helperReplying('ERROR adapter_failed');
      final helper = _tunnelHelper(launcher);

      await expectLater(
        helper.start(socksPort: _socksPort, appRouting: AppRouting.none),
        throwsA(_tunnelUnavailable),
      );

      expect(helper.carriesConnection, isFalse);
    });
  });
}
