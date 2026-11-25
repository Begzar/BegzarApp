import 'dart:io';

import 'package:begzar/modules/connection/data/datasources/local_port_allocator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The allocator exists because a port can be unbindable while nothing is
/// listening on it — Windows reserves whole blocks, and a bind inside one is
/// refused outright. These tests reproduce the shape of that with a socket the
/// test itself holds, which is the one way to make a port unbindable from
/// inside a test on every platform.
void main() {
  const allocator = LocalPortAllocator();

  /// A port nothing is on, found by letting the OS pick one and releasing it.
  Future<int> freePort() async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    return port;
  }

  test('takes the preferred port when it binds', () async {
    final preferred = await freePort();

    expect(await allocator.resolve(preferred), preferred);
  });

  test('falls through to the first fallback that binds', () async {
    final taken = await freePort();
    final blocked = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      taken,
    );
    addTearDown(blocked.close);

    final alsoTaken = await freePort();
    final blockedToo = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      alsoTaken,
    );
    addTearDown(blockedToo.close);

    final open = await freePort();

    expect(
      await allocator.resolve(taken, fallbacks: [alsoTaken, open]),
      open,
      reason: 'the first two are held, so neither may be handed back',
    );
  });

  test('asks the OS for a port when nothing offered will bind', () async {
    final taken = await freePort();
    final blocked = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      taken,
    );
    addTearDown(blocked.close);

    final resolved = await allocator.resolve(taken);

    expect(resolved, isNot(taken));
    expect(resolved, greaterThan(0));

    // Whatever came back has to be usable, or the caller is no better off than
    // it was with the port it could not open.
    final opened = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      resolved,
    );
    addTearDown(opened.close);
    expect(opened.port, resolved);
  });

  test('a resolved port is one the engine can actually open', () async {
    final resolved = await allocator.resolve(await freePort());

    final opened = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      resolved,
    );
    addTearDown(opened.close);

    expect(opened.port, resolved);
  });
}
