import 'dart:io';

import 'package:begzar/core/log/log.dart';

/// Picks a loopback port the proxy engine can actually bind.
///
/// Windows reserves whole blocks of ports for Hyper-V, WSL and Docker, and a
/// bind inside one fails with `WSAEACCES` — "an attempt was made to access a
/// socket in a way forbidden by its access permissions" — even though nothing
/// is listening on it. 2080 sits inside such a block on a stock developer
/// machine, so every dial failed before it reached the network: the engine
/// tested a server, found it healthy, then could not open the relay it had
/// just proved was reachable.
///
/// That is also why this is a probe rather than a different constant. The
/// exclusion list (`netsh interface ipv4 show excludedportrange`) is assigned
/// dynamically and the blocks move across reboots, so a new hardcoded port
/// only relocates the problem to whichever machine draws that range next.
///
/// The check is a bind-and-close, which races anything that grabs the port in
/// between. Losing that race costs one failed start, where guessing costs
/// every start on the machine — and the engine reports the real reason either
/// way now that it is no longer the only thing that ever tried to bind.
class LocalPortAllocator {
  const LocalPortAllocator();

  static const _log = Log('tunnel');

  /// The first of [preferred] then [fallbacks] that binds, or one the OS
  /// assigns when none of them do.
  ///
  /// Falling back to an OS-assigned port is deliberate: a machine whose
  /// reserved ranges swallow every candidate still connects, and the caller
  /// publishes whatever came back rather than assuming it got what it asked
  /// for.
  Future<int> resolve(
    int preferred, {
    List<int> fallbacks = const [],
    String host = '127.0.0.1',
  }) async {
    for (final candidate in <int>[preferred, ...fallbacks]) {
      if (await _isBindable(candidate, host)) {
        if (candidate != preferred) {
          _log.warn('port.fallback', {'from': preferred, 'to': candidate});
        }
        return candidate;
      }
    }

    final assigned = await _ephemeral(host);
    if (assigned == null) {
      // Nothing bound, including a port the OS chose. Hand back what was asked
      // for so the engine fails with its own message rather than this one.
      _log.error('port.none', {'preferred': preferred});
      return preferred;
    }
    _log.warn('port.ephemeral', {'from': preferred, 'to': assigned});
    return assigned;
  }

  Future<bool> _isBindable(int candidate, String host) async {
    try {
      final probe = await ServerSocket.bind(host, candidate);
      await probe.close();
      return true;
    } on SocketException catch (e) {
      _log.trace('port.unavailable', {
        'port': candidate,
        'os': e.osError?.errorCode ?? -1,
      });
      return false;
    }
  }

  Future<int?> _ephemeral(String host) async {
    try {
      final probe = await ServerSocket.bind(host, 0);
      final assigned = probe.port;
      await probe.close();
      return assigned;
    } on SocketException {
      return null;
    }
  }
}
