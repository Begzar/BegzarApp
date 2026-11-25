import 'package:begzar/l10n/localized_date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Anchored on Nowruz, which is the one day of the Solar Hijri year everybody
/// knows the Gregorian date of. It is not a fixed date: the year turns on the
/// day of the vernal equinox as seen from Tehran, so it lands on 20 or 21
/// March depending on whether the equinox falls before or after local noon.
/// Both cases are here, because a calendar that hard-codes one of them is
/// wrong every other year and right half the time.
///
/// These assertions are aimed at `package:shamsi_date` through the formatter
/// rather than at arithmetic of our own, so they are what would catch a
/// package upgrade quietly changing the calendar under the app.
void main() {
  setUpAll(() async {
    // `DateFormat` carries English alone until this runs and throws on the
    // first other locale, which is the same call `main.dart` makes at startup.
    await initializeDateFormatting();
  });

  group('Persian gets the calendar it keeps', () {
    test('1405 began on 21 March 2026', () {
      // The 2026 equinox was 14:46 UTC, after noon in Tehran, so the year
      // turned the following day.
      expect(LocalizedDate.day(DateTime(2026, 3, 21), 'fa'), '۱ فروردین ۱۴۰۵');
    });

    test('20 March 2026 was still the last day of 1404', () {
      expect(LocalizedDate.day(DateTime(2026, 3, 20), 'fa'), '۲۹ اسفند ۱۴۰۴');
    });

    test('20 March 2025 was the thirtieth of Esfand, which 1403 had', () {
      // 1403 was a leap year, so its Esfand ran to 30 days where 1404 above
      // ends on the 29th.
      expect(LocalizedDate.day(DateTime(2025, 3, 20), 'fa'), '۳۰ اسفند ۱۴۰۳');
    });

    test('a subscription expiring in September', () {
      // The date actually on the account screen, which is what makes this one
      // worth reading: 17 September 2026 is 26 Shahrivar 1405.
      expect(LocalizedDate.day(DateTime(2026, 9, 17), 'fa'), '۲۶ شهریور ۱۴۰۵');
    });

    test('a sign-in, with the clock padded and in the same digits', () {
      expect(
        LocalizedDate.dayAndTime(DateTime(2026, 8, 27, 18, 6), 'fa'),
        '۵ شهریور ۱۴۰۵ · ۱۸:۰۶',
      );
    });

    test('no Latin digit survives anywhere in a Persian date', () {
      expect(
        LocalizedDate.dayAndTime(DateTime(2026, 9, 17, 9, 5), 'fa'),
        isNot(contains(RegExp('[0-9]'))),
      );
    });
  });

  group('every other locale keeps the Gregorian calendar', () {
    test('English is unchanged from what it always showed', () {
      expect(LocalizedDate.day(DateTime(2026, 9, 17), 'en'), 'Sep 17, 2026');
      expect(
        LocalizedDate.dayAndTime(DateTime(2026, 8, 27, 18, 46), 'en'),
        'Aug 27, 2026 · 18:46',
      );
    });

    test('Russian and Chinese get their own month names', () {
      // These were English before, because the format carried no locale at
      // all — the bug was never only a Persian one.
      expect(
        LocalizedDate.day(DateTime(2026, 9, 17), 'ru'),
        isNot(contains('Sep')),
      );
      expect(
        LocalizedDate.day(DateTime(2026, 9, 17), 'zh'),
        isNot(contains('Sep')),
      );
    });
  });

  group('a session clock keeps its shape for the whole session', () {
    test('the hours field is written from the first second', () {
      expect(
        LocalizedDate.elapsed(const Duration(seconds: 7), 'en'),
        '00:00:07',
        reason:
            'a field arriving at the hour mark would shift a centred line '
            'sideways once per session',
      );
    });

    test('a run of hours and minutes', () {
      expect(
        LocalizedDate.elapsed(
          const Duration(hours: 2, minutes: 14, seconds: 7),
          'en',
        ),
        '02:14:07',
      );
    });

    test('past a day it keeps counting hours', () {
      expect(
        LocalizedDate.elapsed(
          const Duration(days: 1, hours: 3, minutes: 41, seconds: 12),
          'en',
        ),
        '27:41:12',
        reason:
            'a day field appearing after 24 hours is the same problem as '
            'an hours field appearing after one',
      );
    });

    test('a clock that would run backwards reads as zero', () {
      expect(
        LocalizedDate.elapsed(const Duration(seconds: -4), 'en'),
        '00:00:00',
      );
    });

    test('Persian counts in its own digits', () {
      expect(
        LocalizedDate.elapsed(const Duration(minutes: 14, seconds: 7), 'fa'),
        '۰۰:۱۴:۰۷',
      );
    });

    test('the digit set a locale writes with', () {
      expect(LocalizedDate.digits('en'), '0123456789');
      expect(LocalizedDate.digits('fa'), '۰۱۲۳۴۵۶۷۸۹');
      expect(
        LocalizedDate.digits('ru'),
        '0123456789',
        reason: 'Persian is the one locale on a different set',
      );
    });
  });
}
