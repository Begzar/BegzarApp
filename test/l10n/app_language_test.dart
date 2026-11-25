import 'package:begzar/l10n/app_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('forDevice', () {
    test('a language the app has is that language', () {
      expect(AppLanguage.forDevice(const Locale('fa')), AppLanguage.persian);
      expect(AppLanguage.forDevice(const Locale('ru')), AppLanguage.russian);
      expect(AppLanguage.forDevice(const Locale('zh')), AppLanguage.chinese);
      expect(AppLanguage.forDevice(const Locale('en')), AppLanguage.english);
    });

    test('only the language is compared, not the region or script', () {
      expect(
        AppLanguage.forDevice(const Locale('fa', 'IR')),
        AppLanguage.persian,
      );
      expect(
        AppLanguage.forDevice(
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        ),
        AppLanguage.chinese,
      );
      expect(
        AppLanguage.forDevice(const Locale('en', 'GB')),
        AppLanguage.english,
      );
    });

    test('a language the app does not have answers English', () {
      expect(AppLanguage.forDevice(const Locale('de')), AppLanguage.english);
      expect(AppLanguage.forDevice(const Locale('ar')), AppLanguage.english);
      expect(AppLanguage.forDevice(const Locale('tr')), AppLanguage.english);
      expect(AppLanguage.forDevice(const Locale('und')), AppLanguage.english);
    });
  });

  group('firstRunQuestionLanguages', () {
    test('asks in the language picked first, then English', () {
      expect(AppLanguage.firstRunQuestionLanguages(AppLanguage.russian), [
        AppLanguage.russian,
        AppLanguage.english,
      ]);
      expect(AppLanguage.firstRunQuestionLanguages(AppLanguage.chinese), [
        AppLanguage.chinese,
        AppLanguage.english,
      ]);
      expect(AppLanguage.firstRunQuestionLanguages(AppLanguage.persian), [
        AppLanguage.persian,
        AppLanguage.english,
      ]);
    });

    test('English picked is asked in English once', () {
      expect(AppLanguage.firstRunQuestionLanguages(AppLanguage.english), [
        AppLanguage.english,
      ]);
    });
  });

  group('firstRunAsks', () {
    test('a Persian device is not asked', () {
      expect(AppLanguage.firstRunAsks(AppLanguage.persian), isFalse);
    });

    test('every other device is asked', () {
      for (final device in [
        AppLanguage.english,
        AppLanguage.chinese,
        AppLanguage.russian,
      ]) {
        expect(AppLanguage.firstRunAsks(device), isTrue, reason: device.code);
      }
    });
  });

  test('only Persian runs right to left', () {
    for (final language in AppLanguage.values) {
      expect(
        language.textDirection,
        language == AppLanguage.persian ? TextDirection.rtl : TextDirection.ltr,
        reason: language.code,
      );
    }
  });
}
