import 'package:begzar/modules/settings/domain/entities/dns_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accepts', () {
    test('the resolvers the dialog suggests', () {
      for (final address in [
        '8.8.8.8',
        '1.1.1.1',
        '4.2.2.4',
        '208.67.222.222',
      ]) {
        expect(DnsServer.parse(address)?.address, address, reason: address);
      }
    });

    test('surrounding whitespace, which it trims', () {
      expect(DnsServer.parse('  1.1.1.1  ')?.address, '1.1.1.1');
    });

    test('IPv6 resolvers, compressed or written out', () {
      for (final address in [
        '2001:4860:4860::8888',
        '2606:4700:4700::1111',
        '::1',
        'fe80::1',
        '2001:0db8:0000:0000:0000:0000:0000:0001',
      ]) {
        expect(DnsServer.parse(address)?.address, address, reason: address);
      }
    });
  });

  group('refuses', () {
    test('an empty field', () {
      expect(DnsServer.parse(''), isNull);
      expect(DnsServer.parse('   '), isNull);
    });

    // The one that mattered: this used to save, and every lookup failed once
    // the tunnel came up.
    test('a hostname', () {
      expect(DnsServer.parse('dns.google'), isNull);
      expect(DnsServer.parse('hello'), isNull);
    });

    test('a DoH URL, which the engine is not handed here', () {
      expect(DnsServer.parse('https://dns.google/dns-query'), isNull);
    });

    test('a short address rather than reading it as shorthand', () {
      expect(DnsServer.parse('1.1.1'), isNull);
      expect(DnsServer.parse('8.8'), isNull);
    });

    test('too many octets', () {
      expect(DnsServer.parse('1.1.1.1.1'), isNull);
    });

    test('an octet out of range', () {
      expect(DnsServer.parse('256.1.1.1'), isNull);
      expect(DnsServer.parse('1.1.1.999'), isNull);
    });

    test('an empty or non-numeric octet', () {
      expect(DnsServer.parse('1..1.1'), isNull);
      expect(DnsServer.parse('1.1.1.'), isNull);
      expect(DnsServer.parse('1.1.1.a'), isNull);
      expect(DnsServer.parse('1.1.1.-1'), isNull);
    });

    test('an address with a port, which the engine does not take here', () {
      expect(DnsServer.parse('8.8.8.8:53'), isNull);
    });

    test('a malformed IPv6 literal', () {
      expect(DnsServer.parse('2001::db8::1'), isNull);
      expect(DnsServer.parse('12345::1'), isNull);
      expect(DnsServer.parse('gggg::1'), isNull);
      expect(DnsServer.parse('2001:db8:1'), isNull);
      expect(DnsServer.parse('2001:db8:'), isNull);
    });
  });

  test('the fallback is a resolver it would accept', () {
    expect(DnsServer.parse(DnsServer.fallback.address), DnsServer.fallback);
  });
}
