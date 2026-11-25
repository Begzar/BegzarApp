import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// Dates, written the way the language on screen writes them.
///
/// Two things were wrong with how the app wrote them before. `DateFormat` was
/// built without a locale, so every date came out in English wherever it
/// appeared — `Sep 17, 2026` in the middle of a Persian screen. And Persian
/// readers do not keep Gregorian dates: the civil calendar of Iran is the
/// Solar Hijri one, and a subscription expiring on `۲۶ شهریور ۱۴۰۵` is a date
/// its holder can place without arithmetic.
///
/// Every other locale gets the same Gregorian date it always had, now with its
/// own month names and digits, which is `DateFormat` doing its job once it is
/// told which language it is writing. `initializeDateFormatting` in `main.dart`
/// is what makes that possible: without it `DateFormat` carries English alone
/// and throws on the first other locale asked of it.
abstract final class LocalizedDate {
  /// The one locale on a different calendar.
  static const _solarHijriLocale = 'fa';

  static const _gregorianPattern = 'MMM d, yyyy';

  /// What separates a date from the time of day after it.
  static const _timeSeparator = ' · ';

  /// What separates one clock field from the next.
  static const _clockSeparator = ':';

  static const _persianDigits = <String>[
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹',
  ];

  /// A day, with no time of day: when a subscription runs out.
  static String day(DateTime date, String localeName) =>
      _write(date, localeName, withTime: false);

  /// A day and the time on it: when a device last signed in.
  static String dayAndTime(DateTime date, String localeName) =>
      _write(date, localeName, withTime: true);

  /// How long something has been running, as a clock: how long the tunnel has
  /// been up.
  ///
  /// The hours field is written even while it is zero, and a run past a day
  /// keeps counting hours rather than growing a day field. Both are the same
  /// decision: this reading is centred under the connect dial and reprinted
  /// every second, so a field that appeared partway through a session would
  /// shift the whole line sideways as it arrived. Three fields, always, never
  /// change the shape of the reading.
  ///
  /// A negative span reads as zero. Nothing should hand one over — a clock
  /// running backwards would mean the device's own clock moved under a live
  /// connection — and if one arrives it is not worth putting `-00:00:04` on
  /// the home screen over.
  static String elapsed(Duration since, String localeName) {
    final run = since.isNegative ? Duration.zero : since;
    final field = _clockField(localeName);
    final minutes = run.inMinutes.remainder(Duration.minutesPerHour);
    final seconds = run.inSeconds.remainder(Duration.secondsPerMinute);

    return '${field(run.inHours)}$_clockSeparator'
        '${field(minutes)}$_clockSeparator${field(seconds)}';
  }

  /// The ten digits [localeName] writes its numbers with, in order.
  ///
  /// For laying a clock out in fixed cells: the cell has to be as wide as the
  /// widest digit in the set, which is not knowable from the digits that
  /// happen to be on screen at the moment it is measured.
  static String digits(String localeName) =>
      localeName.startsWith(_solarHijriLocale)
      ? _persianDigits.join()
      : _latinDigits;

  static const _latinDigits = '0123456789';

  static String _write(
    DateTime date,
    String localeName, {
    required bool withTime,
  }) {
    final written = localeName.startsWith(_solarHijriLocale)
        ? _solarHijri(date)
        : DateFormat(_gregorianPattern, localeName).format(date);

    if (!withTime) return written;

    final field = _clockField(localeName);

    return '$written$_timeSeparator'
        '${field(date.hour)}$_clockSeparator${field(date.minute)}';
  }

  /// One field of a clock, in the digits the language writes.
  ///
  /// Padded to two, because a time is read as a run of two-digit fields
  /// rather than as a row of numbers — the same reason the quantity strings
  /// in the ARB go through `decimalPattern` and this does not.
  static String Function(int) _clockField(String localeName) =>
      localeName.startsWith(_solarHijriLocale)
      ? (int value) => _inPersianDigits(value, width: 2)
      : (int value) => value.toString().padLeft(2, '0');

  /// Reads the date in whatever zone [date] carries, so a subscription
  /// expiring at half past midnight Tehran expires on the day its holder would
  /// name rather than the day before.
  static String _solarHijri(DateTime date) {
    final jalali = Jalali.fromDateTime(date);

    return '${_inPersianDigits(jalali.day)} '
        '${jalali.formatter.mN} '
        '${_inPersianDigits(jalali.year)}';
  }

  /// Digit-for-digit, rather than through `NumberFormat`.
  ///
  /// A formatter would group the thousands in a year and write ۱٬۴۰۵, which is
  /// a quantity of years rather than the name of one. Years, days and clock
  /// fields are all read here as sequences of digits, not as counts — which is
  /// the same reason the quantity strings in the ARB use `decimalPattern` and
  /// these do not.
  static String _inPersianDigits(int value, {int width = 1}) {
    final digits = value.toString().padLeft(width, '0');
    final buffer = StringBuffer();

    for (final rune in digits.runes) {
      final digit = rune - 0x30;
      buffer.write(
        digit >= 0 && digit <= 9
            ? _persianDigits[digit]
            : String.fromCharCode(rune),
      );
    }

    return buffer.toString();
  }
}
