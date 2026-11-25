import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/log/log.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:flutter/services.dart';

/// What came of asking Windows to start the tunnel helper.
enum HelperLaunchOutcome {
  /// Windows started it elevated. Whether the tunnel came up is the lease's to
  /// say, not the launch's.
  started,

  /// The user said no to the admin prompt.
  declined,

  /// `begzar-tun.exe` is not beside `begzar.exe`.
  missing,

  /// Windows would not start it for any other reason.
  failed,
}

/// Starts `begzar-tun.exe` elevated with a command line.
///
/// The seam between [TunnelHelper] and the Windows runner, so a test can play
/// the helper over a real socket without an admin prompt.
abstract interface class TunnelHelperLauncher {
  /// Launches the helper with [commandLine] as its parameters, returning once
  /// the admin prompt has been answered.
  Future<HelperLaunchOutcome> launch(String commandLine);
}

/// Launches the helper through the runner's `begzar/tunnel_helper` channel,
/// which asks for it through the Windows admin prompt.
class PlatformTunnelHelperLauncher implements TunnelHelperLauncher {
  const PlatformTunnelHelperLauncher();

  // These are the channel, method and argument names that
  // tunnel_helper_plugin.cpp registers, so each one changes on both sides or
  // on neither.
  static const _channel = MethodChannel('begzar/tunnel_helper');

  /// Reads the runner's answer by the outcome's name. No answer, or one this
  /// side does not know, is a launch that failed.
  @override
  Future<HelperLaunchOutcome> launch(String commandLine) async {
    final answer = await _channel.invokeMethod<String>('launch', {
      'parameters': commandLine,
    });
    return HelperLaunchOutcome.values.asNameMap()[answer] ??
        HelperLaunchOutcome.failed;
  }
}

/// Whether [argument] would not survive the Windows command line bare: a space
/// or a tab would split it, a quote would be read as quoting, and an empty one
/// would vanish.
bool _needsQuoting(String argument) =>
    argument.isEmpty ||
    argument.contains(' ') ||
    argument.contains('\t') ||
    argument.contains('"');

/// Quotes one argument so `CommandLineToArgvW` reads it back unchanged.
///
/// Inside quotes a backslash is literal unless a quote follows it. A run of
/// backslashes before a quote is doubled, so each one stays literal, and an
/// embedded quote gets one more backslash in front of it. The closing quote
/// counts too, which is why trailing backslashes are doubled.
String _quoteArgument(String argument) {
  if (!_needsQuoting(argument)) return argument;

  final quoted = StringBuffer('"');
  var backslashes = 0;
  for (final character in argument.split('')) {
    if (character == r'\') {
      backslashes++;
      continue;
    }
    if (character == '"') {
      quoted.write(r'\' * (backslashes * 2 + 1));
    } else {
      quoted.write(r'\' * backslashes);
    }
    quoted.write(character);
    backslashes = 0;
  }
  quoted.write(r'\' * (backslashes * 2));
  quoted.write('"');
  return quoted.toString();
}

/// Joins [arguments] into one Windows command line that `CommandLineToArgvW`
/// splits back into the same list, as does the Go runtime, which reads its
/// arguments by the same rules.
///
/// `ShellExecuteExW` takes the helper's parameters as a single string, so this
/// is what keeps an App Routing program called `My App.exe` one argument
/// rather than two.
String windowsCommandLine(List<String> arguments) =>
    arguments.map(_quoteArgument).join(' ');

/// The helper's `--app-mode` and the apps it applies to.
///
/// Chosen and named as the engine's own per-program rules take them
/// (`begzar-engine/src/configbuilder`): the apps of the list in force, exactly as
/// they were picked. An empty pick is mode `none` with no apps, because the
/// helper refuses the other two modes without one.
(String, List<String>) _helperAppRouting(AppRouting appRouting) {
  if (appRouting.bypassing.isNotEmpty) {
    return ('all-except', appRouting.bypassing);
  }
  if (appRouting.onlyThrough.isNotEmpty) {
    return ('only-some', appRouting.onlyThrough);
  }
  return ('none', const []);
}

/// The helper's command line, as a list.
List<String> helperArguments({
  required int leasePort,
  required String token,
  required int socksPort,
  required int parentPid,
  required AppRouting appRouting,
}) {
  final (appMode, apps) = _helperAppRouting(appRouting);

  return [
    '--lease-port',
    '$leasePort',
    '--token',
    token,
    '--socks-port',
    '$socksPort',
    '--parent-pid',
    '$parentPid',
    '--app-mode',
    appMode,
    for (final app in apps) ...['--app', app],
  ];
}

/// The longest line the lease reads, newline excluded. The longest the
/// protocol has is the hello: `HELLO ` and 32 hex characters, 38 bytes.
const _maxLineBytes = 64;

const _newline = 0x0A;
const _carriageReturn = 0x0D;

/// A lease connection sent more than [_maxLineBytes] without a newline.
class _OverlongLine implements Exception {
  const _OverlongLine();
}

/// Splits a connection's bytes into lines, ending the stream with
/// [_OverlongLine] at the first line longer than [_maxLineBytes].
///
/// Built per connection, since it holds that connection's unfinished line.
/// Anything on this machine can dial the lease port, and without a cap a line
/// that never ends would be buffered for as long as it kept coming. A line the
/// connection closes on before its newline is dropped.
StreamTransformer<Uint8List, String> _boundedLines() {
  final line = <int>[];
  var ended = false;
  return StreamTransformer.fromHandlers(
    handleData: (chunk, sink) {
      if (ended) return;
      for (final byte in chunk) {
        if (byte == _newline) {
          if (line.isNotEmpty && line.last == _carriageReturn) {
            line.removeLast();
          }
          sink.add(utf8.decode(line, allowMalformed: true));
          line.clear();
        } else if (line.length == _maxLineBytes) {
          ended = true;
          sink.addError(const _OverlongLine());
          sink.close();
          return;
        } else {
          line.add(byte);
        }
      }
    },
  );
}

/// One loopback connection from a helper, read a line at a time.
class _LeaseConnection {
  _LeaseConnection(this._socket)
    : _lines = StreamIterator(_socket.transform(_boundedLines()));

  final Socket _socket;
  final StreamIterator<String> _lines;

  /// Whether the connection ended by sending a line over the cap.
  bool overlong = false;

  /// The next line, or null once the connection has closed, failed or sent a
  /// line over the cap.
  Future<String?> nextLine() async {
    try {
      return await _lines.moveNext() ? _lines.current : null;
    } on _OverlongLine {
      overlong = true;
      return null;
    } catch (_) {
      // A reset reads as a close: either way the helper is gone.
      return null;
    }
  }

  /// Closes both directions now. A [nextLine] still waiting answers null.
  Future<void> close() async {
    _socket.destroy();
    await _lines.cancel();
  }
}

/// One connect's wait for its helper to dial back.
///
/// Every connection is greeted at once rather than in turn, so one that never
/// says anything cannot hold up the helper behind it.
class _LeaseListener {
  _LeaseListener(this._server, this._token) {
    // A listener that fails takes no more connections, and the wait for the
    // helper runs out.
    _server.listen(_greet, onError: (Object _) {});
  }

  static const _log = Log('tunnel');

  final ServerSocket _server;
  final String _token;

  /// Every connection taken and not yet closed, so a failure can close what
  /// is left. The one kept by [close] stays here, so a later failure closes
  /// it too.
  final _connections = <_LeaseConnection>{};
  final _greeted = Completer<_LeaseConnection>();
  bool _closed = false;

  /// The first connection whose first line is the hello with this connect's
  /// token.
  Future<_LeaseConnection> get greeted => _greeted.future;

  Future<void> _greet(Socket socket) async {
    final connection = _LeaseConnection(socket);
    if (_closed || _greeted.isCompleted) {
      await connection.close();
      return;
    }
    _connections.add(connection);

    final hello = await connection.nextLine();
    if (hello == 'HELLO $_token' && !_closed && !_greeted.isCompleted) {
      _greeted.complete(connection);
      return;
    }
    // Not the helper this connect launched. Anything on this machine can dial
    // a loopback port, which is what the token is for.
    if (!_closed) {
      _log.warn('helper.stranger', {'overlong': connection.overlong});
    }
    _connections.remove(connection);
    await connection.close();
  }

  /// Stops listening and closes every connection taken except [keep].
  Future<void> close({_LeaseConnection? keep}) async {
    if (!_closed) {
      _closed = true;
      await _server.close();
    }
    final leftOver = [..._connections.where((each) => each != keep)];
    _connections.removeAll(leftOver);
    for (final connection in leftOver) {
      await connection.close();
    }
  }
}

/// Launches the Windows tunnel helper through the admin prompt and holds its
/// lease.
///
/// The lease is one loopback connection the helper dials back on. Its first
/// line carries a one-time token, so nothing else on the machine can pose as
/// the helper, and its second says whether the tunnel came up. From then on
/// its closing is the tunnel's end in both directions: [stop] closes it and
/// the helper takes its adapter down, and a helper that dies closes it and
/// [lost] says so.
class TunnelHelper {
  TunnelHelper({
    TunnelHelperLauncher launcher = const PlatformTunnelHelperLauncher(),
    Duration readyTimeout = const Duration(seconds: 15),
    int? parentPid,
  }) : _launcher = launcher,
       _readyTimeout = readyTimeout,
       _parentPid = parentPid ?? pid;

  static const _log = Log('tunnel');

  /// A code the helper reports looks like `adapter_failed`. Anything else is
  /// recorded as `unknown`, so no text another process chose reaches a log.
  static final _errorCodePattern = RegExp(r'^[a-z_]{1,32}$');

  final TunnelHelperLauncher _launcher;

  /// How long the helper has to dial back and say it is ready, counted from
  /// when the admin prompt was answered.
  final Duration _readyTimeout;

  /// The process the helper watches, and exits with.
  final int _parentPid;

  final _lost = StreamController<void>.broadcast();

  /// The lease held since the helper said it was ready. Null when no helper
  /// is running.
  _LeaseConnection? _lease;

  /// Whether the connection up now was made through this helper. Set when it
  /// says ready and cleared only by [stop], so a helper that went on its own
  /// still answers yes until the connection it carried is taken down.
  bool _carrying = false;

  bool get isRunning => _lease != null;

  /// Whether the connection up now was made through this helper, which may
  /// since have gone.
  ///
  /// Held here rather than by whoever started it: the repository is rebuilt
  /// on every language change, and the helper lives for the app's whole run.
  bool get carriesConnection => _carrying;

  /// Emits when the helper ends a lease that [stop] did not: it exited, was
  /// killed, or its tunnel failed.
  Stream<void> get lost => _lost.stream;

  /// Every message built here is fixed text plus at most a vetted error code,
  /// so a failure's message is safe to log.
  static TunnelFailure _unavailable(String why) => TunnelFailure(
    'Tunnel helper: $why',
    userFacingKey: UserFacingErrorKeys.tunnelUnavailable,
  );

  /// Sixteen bytes from the system's secure source, as the 32 lowercase hex
  /// characters the helper checks its `--token` against.
  static String _newToken() {
    final random = Random.secure();
    final token = StringBuffer();
    for (var index = 0; index < 16; index++) {
      token.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return token.toString();
  }

  /// A launch that throws is one that failed: the runner has no handler, or
  /// it answered something that is not a name.
  Future<HelperLaunchOutcome> _launch(String commandLine) async {
    try {
      return await _launcher.launch(commandLine);
    } catch (_) {
      return HelperLaunchOutcome.failed;
    }
  }

  /// Fails unless the launch [outcome] started a helper.
  static void _requireStarted(HelperLaunchOutcome outcome) {
    switch (outcome) {
      case HelperLaunchOutcome.started:
        return;
      case HelperLaunchOutcome.declined:
        throw const ElevationDeclinedFailure();
      case HelperLaunchOutcome.missing:
        throw _unavailable('missing');
      case HelperLaunchOutcome.failed:
        throw _unavailable('launch failed');
    }
  }

  /// Waits for the helper's hello, then for what it says about the tunnel.
  Future<_LeaseConnection> _awaitReady(_LeaseListener listener) async {
    final lease = await listener.greeted;
    // One helper per connect: once it has said hello, nothing else may dial
    // in.
    await listener.close(keep: lease);

    final reply = await lease.nextLine();
    if (reply == 'READY') return lease;
    await lease.close();
    if (reply == null) {
      throw _unavailable(
        lease.overlong ? 'overlong reply' : 'closed before ready',
      );
    }
    if (reply.startsWith('ERROR ')) {
      final code = reply.substring('ERROR '.length);
      throw _unavailable(
        'reported ${_errorCodePattern.hasMatch(code) ? code : 'unknown'}',
      );
    }
    throw _unavailable('unexpected reply');
  }

  /// Reads the lease until it closes. Anything the helper says after READY is
  /// not part of the protocol and is dropped, and a line over the cap ends the
  /// lease as a close does.
  Future<void> _watch(_LeaseConnection lease) async {
    while (await lease.nextLine() != null) {}
    // stop() let go of it first, so the close was the app's own.
    if (!identical(_lease, lease)) return;
    _lease = null;
    await lease.close();
    _log.warn('helper.lost');
    _lost.add(null);
  }

  /// Launches the helper for the engine on [socksPort] and returns once it
  /// says its tunnel is up.
  ///
  /// A lease still held from before is closed first, so two helpers never
  /// hold the adapter at once. Throws [ElevationDeclinedFailure] when the
  /// admin prompt is declined, and a [TunnelFailure] with
  /// [UserFacingErrorKeys.tunnelUnavailable] for anything else. Either way
  /// nothing this call opened is left open or listening.
  Future<void> start({
    required int socksPort,
    required AppRouting appRouting,
  }) async {
    await stop();

    final ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    } on SocketException catch (e) {
      _log.error('helper.listen.failed', {'os': e.osError?.errorCode ?? -1});
      throw _unavailable('no lease listener');
    }
    final token = _newToken();
    final commandLine = windowsCommandLine(
      helperArguments(
        leasePort: server.port,
        token: token,
        socksPort: socksPort,
        parentPid: _parentPid,
        appRouting: appRouting,
      ),
    );
    // Listening before the launch, so a helper that dials back while the
    // launch is still returning is taken.
    final listener = _LeaseListener(server, token);

    final _LeaseConnection lease;
    try {
      final outcome = await _launch(commandLine);
      _log.trace('helper.launch', {'outcome': outcome.name});
      _requireStarted(outcome);

      // The clock starts only now. The launch returns once the admin prompt
      // is answered, and the user may take as long as they like over that.
      lease = await _awaitReady(listener).timeout(
        _readyTimeout,
        onTimeout: () => throw _unavailable('no answer in time'),
      );
    } catch (error) {
      await listener.close();
      final failure = error is ConnectionFailure
          ? error
          : _unavailable('${error.runtimeType}');
      _log.error('helper.failed', {
        'type': failure.runtimeType,
        'reason': failure.message,
      });
      throw failure;
    }

    _lease = lease;
    _carrying = true;
    _log.trace('helper.ready');
    unawaited(_watch(lease));
  }

  /// Closes the lease, which ends the helper and its tunnel, and ends
  /// [carriesConnection] even for a helper that already went on its own.
  /// Otherwise does nothing when no helper is running, and never reports
  /// [lost].
  Future<void> stop() async {
    _carrying = false;
    final lease = _lease;
    if (lease == null) return;
    _lease = null;
    await lease.close();
    _log.trace('helper.stop');
  }
}
