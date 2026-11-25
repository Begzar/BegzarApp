import 'package:begzar/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Persian is written with its own digits, and a reader of a Persian screen
/// reads ۱۲۰ as a number the way an English reader reads 120. The app used to
/// print Latin digits in every locale because the generated strings dropped
/// their placeholders in as plain interpolations; declaring `decimalPattern` on
/// each one routes it through `NumberFormat`, which already knows what digits
/// each locale is written with.
///
/// What matters as much as the conversion is where it stops. An address, a
/// port, a DNS server: these are identifiers, typed and compared and read back
/// to support, not quantities. Converting one produces something that looks
/// like the value and is not it, which is the same class of bug as reordering a
/// masked address in an RTL paragraph. Both halves are pinned here.
Future<AppLocalizations> _load(String languageCode) =>
    AppLocalizations.delegate.load(Locale(languageCode));

/// The ten digits Persian is written with, in order.
const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

Matcher _writtenInPersianDigits() => predicate<String>(
  (s) =>
      s.split('').any(_persianDigits.contains) && !s.contains(RegExp('[0-9]')),
  'written in Persian digits, with no Latin digit left in it',
);

void main() {
  group('a quantity is written in the digits of its locale', () {
    late AppLocalizations fa;
    late AppLocalizations en;

    setUp(() async {
      fa = await _load('fa');
      en = await _load('en');
    });

    test('a latency', () async {
      expect(fa.pingMs(120), _writtenInPersianDigits());
      expect(en.pingMs(120), contains('120'));
    });

    test('a latency long enough to be grouped', () async {
      // decimalPattern groups thousands, and Persian groups with its own
      // separator rather than a comma.
      expect(fa.pingMs(99999), _writtenInPersianDigits());
      expect(en.pingMs(99999), contains('99,999'));
    });

    test('the days left on a subscription', () async {
      expect(fa.daysLeft(19), _writtenInPersianDigits());
      expect(en.daysLeft(19), contains('19'));
    });

    test('both numbers in a device count', () async {
      expect(fa.devicesCount(1, 2), _writtenInPersianDigits());
      expect(en.devicesCount(1, 2), contains('1 of 2'));
    });

    test('a count inside a plural', () async {
      expect(fa.appRoutingThroughVpn(3), _writtenInPersianDigits());
      expect(en.appRoutingThroughVpn(3), contains('3'));
    });

    test('the configs a server offers', () async {
      expect(fa.premiumServerConfigsCount(4), _writtenInPersianDigits());
    });

    test('the custom routing rules in force', () async {
      expect(fa.routingRulesCount(7), _writtenInPersianDigits());
    });

    test('the seconds before an ad can be closed', () async {
      expect(fa.adCloseCountdown(5), _writtenInPersianDigits());
    });

    test('those seconds alone, inside the close control', () async {
      // The gate row prints the number on its own, so it is the one place a
      // raw interpolation would have shown Latin digits with nothing around
      // them to look wrong against.
      expect(fa.adCloseSeconds(5), _writtenInPersianDigits());
      expect(en.adCloseSeconds(5), '5');
    });

    test('the wait a rate limit imposes', () async {
      expect(fa.errRateLimitWait(30), _writtenInPersianDigits());
    });
  });

  group('an identifier is left exactly as it is', () {
    test('the endpoint a bypassed LAN connects to', () async {
      final fa = await _load('fa');
      expect(
        fa.bypassLanEndpoint('192.168.1.5', 1080),
        contains('192.168.1.5:1080'),
        reason:
            'the port is an int, and an int is exactly what would have '
            'been swept up by formatting every number. It is an address and a '
            'port, to be typed into another program — Persian digits would '
            'make it something that reads like the endpoint and is not it.',
      );
    });

    test('the DNS server in force', () async {
      final fa = await _load('fa');
      expect(fa.dnsServerCurrent('1.1.1.1'), contains('1.1.1.1'));
      expect(fa.dnsChipLabel('Cloudflare', '1.1.1.1'), contains('1.1.1.1'));
    });
  });
}
