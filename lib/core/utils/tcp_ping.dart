import 'dart:io';

/// TCP connect latency to [host]:[port]. Returns null on failure/timeout.
///
/// Deliberately measures the handshake alone: it says whether a server is
/// reachable and how far away it is, without knowing what protocol will be
/// spoken over the socket afterwards. That is why it lives on the floor —
/// premium server pings and any future reachability check can share it.
Future<int?> measureTcpPing(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final stopwatch = Stopwatch()..start();
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    stopwatch.stop();
    try {
      await socket.close();
    } catch (_) {}
    return stopwatch.elapsedMilliseconds;
  } catch (_) {
    return null;
  }
}
