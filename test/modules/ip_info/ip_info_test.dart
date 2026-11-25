import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:flutter_test/flutter_test.dart';

IpInfo _info(String ip, {String countryCode = 'DE'}) =>
    IpInfo(ip: ip, country: 'Germany', countryCode: countryCode);

void main() {
  group('maskedIp', () {
    // The masked address goes on a screen people photograph and share. Every
    // case below is one where the host part must not survive.
    test('an IPv4 address keeps only its network half', () {
      expect(_info('203.0.113.42').maskedIp, '203.0.***.***');
    });

    // Masked to the IPv4 shape — two groups kept, two hidden — so both
    // families take the same width in the banner, which used to cut a v6
    // address off at its third masked group.
    test('an IPv6 address keeps its first two groups and hides two', () {
      expect(
        _info('2001:db8:85a3:0:0:8a2e:370:7334').maskedIp,
        '2001:db8:****:****',
      );
    });

    test('a compressed IPv6 address is masked the same way', () {
      expect(_info('2001:db8::7334').maskedIp, '2001:db8:****:****');
    });

    test('an address in neither shape is returned untouched', () {
      expect(_info('Unknown').maskedIp, 'Unknown');
      expect(_info('203.0.113').maskedIp, '203.0.113');
    });
  });

  group('ipVersion', () {
    test('reads the family off the address', () {
      expect(_info('203.0.113.42').isIPv4, isTrue);
      expect(_info('203.0.113.42').ipVersion, 'IPv4');
      expect(_info('2001:db8::1').isIPv6, isTrue);
      expect(_info('2001:db8::1').ipVersion, 'IPv6');
    });
  });

  group('flagEmoji', () {
    test('maps a country code to its regional indicator pair', () {
      expect(_info('203.0.113.42', countryCode: 'DE').flagEmoji, '🇩🇪');
      expect(_info('203.0.113.42', countryCode: 'ir').flagEmoji, '🇮🇷');
    });
  });
}
