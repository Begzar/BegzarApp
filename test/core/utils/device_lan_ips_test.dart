import 'dart:io';
import 'dart:typed_data';

import 'package:begzar/core/utils/device_lan_ips.dart';
import 'package:flutter_test/flutter_test.dart';

/// An interface as `NetworkInterface.list` reports one: a name and the
/// addresses on it, with nothing about whether it is up.
class _Interface implements NetworkInterface {
  _Interface(this.name, List<String> addresses)
    : addresses = [
        for (final address in addresses)
          _BoundAddress(InternetAddress(address)),
      ];

  @override
  final String name;

  @override
  final List<InterfaceAddress> addresses;

  @override
  int get index => 0;
}

/// The address plus the prefix an interface now reports with it. The ranking
/// reads only the address.
class _BoundAddress implements InterfaceAddress {
  _BoundAddress(this._address);

  final InternetAddress _address;

  @override
  String get address => _address.address;

  @override
  InternetAddress? get broadcast => null;

  @override
  String get host => _address.host;

  @override
  bool get isLinkLocal => _address.isLinkLocal;

  @override
  bool get isLoopback => _address.isLoopback;

  @override
  bool get isMulticast => _address.isMulticast;

  @override
  int get prefixLength => 0;

  @override
  Uint8List get rawAddress => _address.rawAddress;

  @override
  Future<InternetAddress> reverse() => _address.reverse();

  @override
  InternetAddressType get type => _address.type;
}

Future<bool> _holdsEverything(InternetAddress _) async => true;

/// A Windows PC on a home LAN with two VPN clients installed and neither
/// connected, in the order Dart lists them: the VPN adapters and the Hyper-V
/// switch come before the Ethernet port.
final _vpnClientsInstalled = [
  _Interface('NordLynx', ['10.5.0.2']),
  _Interface('vEthernet (Default Switch)', ['172.31.80.1']),
  _Interface('Ethernet', ['192.168.1.20']),
  _Interface('OpenVPN Data Channel Offload', ['10.100.0.2']),
];

void main() {
  group('rankLanIpv4Addresses', () {
    test('should put the home LAN ahead of VPN adapters and virtual '
        'switches', () async {
      final addresses = await rankLanIpv4Addresses(
        _vpnClientsInstalled,
        isHeld: _holdsEverything,
      );

      expect(addresses, [
        '192.168.1.20',
        '10.5.0.2',
        '10.100.0.2',
        '172.31.80.1',
      ]);
    });

    test('should leave out an address the platform does not hold', () async {
      // What Windows does with the tentative address on a disconnected
      // VPN adapter: it lists it, and refuses to bind it.
      final addresses = await rankLanIpv4Addresses(
        _vpnClientsInstalled,
        isHeld: (address) async => address.rawAddress.first != 10,
      );

      expect(addresses, ['192.168.1.20', '172.31.80.1']);
    });

    test(
      'should order addresses in one block by number, not as text',
      () async {
        final addresses = await rankLanIpv4Addresses([
          _Interface('Wi-Fi', ['192.168.1.10']),
          _Interface('Ethernet', ['192.168.1.9']),
          _Interface('VPN', ['10.20.0.1', '10.3.0.1']),
        ], isHeld: _holdsEverything);

        expect(addresses, [
          '192.168.1.9',
          '192.168.1.10',
          '10.3.0.1',
          '10.20.0.1',
        ]);
      },
    );

    test('should keep only private IPv4 addresses', () async {
      final addresses = await rankLanIpv4Addresses([
        _Interface('Loopback', ['127.0.0.1']),
        _Interface('Mobile data', ['100.64.0.7', '203.0.113.9']),
        _Interface('Unconfigured', ['169.254.10.1']),
        _Interface('Edges', ['172.15.0.1', '172.16.0.1', '172.32.0.1']),
        _Interface('Ethernet', ['192.168.0.5', 'fd00::5']),
      ], isHeld: _holdsEverything);

      expect(addresses, ['192.168.0.5', '172.16.0.1']);
    });

    test('should list an address two interfaces share once', () async {
      final addresses = await rankLanIpv4Addresses([
        _Interface('Ethernet', ['192.168.1.20']),
        _Interface('Bridge', ['192.168.1.20']),
      ], isHeld: _holdsEverything);

      expect(addresses, ['192.168.1.20']);
    });
  });
}
