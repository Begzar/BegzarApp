import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/l10n/locale_provider.dart';
import 'package:begzar/modules/settings/data/datasources/settings_storage.dart';
import 'package:begzar/modules/settings/di/settings_providers.dart';
import 'package:begzar/modules/settings/presentation/widgets/first_run_language_gate.dart';
import 'package:begzar/modules/settings/presentation/widgets/language_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/memory_keyed_storage.dart';

/// What the gate stands in front of. Found by key, so a test can tell whether
/// the gate let the app through.
const _home = Key('home');

/// The key the language is stored under, as `SettingsStorage` writes it.
const _localeKey = 'settings_locale';

const _designSize = Size(393, 852);

/// Every string the screen shows, spelled out rather than read back from the
/// localizations under test, so a line that stopped being translated fails
/// rather than agreeing with itself.
const _titles = {
  'fa': 'انتخاب زبان',
  'en': 'Select Language',
  'ru': 'Выберите язык',
  'zh': '选择语言',
};
const _hints = {
  'fa': 'بعداً می‌توانید آن را در تنظیمات تغییر دهید',
  'en': 'You can change this later in Settings',
  'ru': 'Это можно изменить позже в настройках',
  'zh': '之后可在设置中更改',
};
const _languageLabels = {'fa': 'زبان', 'en': 'Language'};
const _continue = {
  'fa': 'ادامه',
  'en': 'Continue',
  'ru': 'Продолжить',
  'zh': '继续',
};

class _Harness {
  _Harness(this.container, this.store);

  final ProviderContainer container;
  final MemoryKeyedStorage? store;

  LocaleNotifier get locale => container.read(localeProvider.notifier);
}

void main() {
  /// Mounts the gate as a launch would find it.
  ///
  /// [stored] is what an earlier run wrote. [knownAtLaunch] is whether `main`
  /// found it before the first frame — true on a real launch whenever
  /// something is stored, and false when only the notifier's own load can
  /// answer.
  Future<_Harness> pumpGate(
    WidgetTester tester, {
    Locale device = const Locale('en'),
    Map<String, String>? stored,
    bool knownAtLaunch = false,
    AppKeyedStorage? storage,
    Size surface = _designSize,
    LaunchCoverPhase cover = LaunchCoverPhase.done,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localeTestValue = device;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final store = storage == null ? MemoryKeyedStorage(stored) : null;
    final container = ProviderContainer(
      overrides: [
        settingsStorageProvider.overrideWithValue(
          SettingsStorage(storage: storage ?? store!),
        ),
        localeProvider.overrideWith(
          () => LocaleNotifier(
            initialLocale: AppLanguage.forDevice(device).locale,
            languageSaved: knownAtLaunch,
          ),
        ),
        launchCoverProvider.overrideWith(
          () => LaunchCoverNotifier(initial: cover),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: _designSize,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) => Consumer(
            builder: (context, ref, _) => MaterialApp(
              locale: ref.watch(localeProvider),
              supportedLocales: AppLanguage.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const FirstRunLanguageGate(child: SizedBox(key: _home)),
            ),
          ),
        ),
      ),
    );
    return _Harness(container, store);
  }

  /// The face a line of text is drawn in, after whatever it inherits.
  String? face(WidgetTester tester, String text) => tester
      .widget<RichText>(
        find.descendant(of: find.text(text), matching: find.byType(RichText)),
      )
      .text
      .style
      ?.fontFamily;

  /// The language the dropdown holds.
  String selected(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  Finder inMenu(String label) => find.descendant(
    of: find.byType(MenuItemButton),
    matching: find.text(label),
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(LanguageDropdown));
    await tester.pumpAndSettle();
  }

  /// Picks [label] from the dropdown's menu, without continuing.
  Future<void> pick(WidgetTester tester, String label) async {
    await openMenu(tester);
    await tester.tap(inMenu(label));
    await tester.pumpAndSettle();
  }

  group('a language already picked', () {
    testWidgets('passes straight through, from the first frame', (
      tester,
    ) async {
      await pumpGate(tester, stored: {_localeKey: 'ru'}, knownAtLaunch: true);

      expect(find.byKey(_home), findsOneWidget);
      expect(find.text('فارسی'), findsNothing);
    });

    testWidgets('leaves the launch cover for the home screen to land', (
      tester,
    ) async {
      final harness = await pumpGate(
        tester,
        stored: {_localeKey: 'ru'},
        knownAtLaunch: true,
        cover: LaunchCoverPhase.covering,
      );

      expect(
        harness.container.read(launchCoverProvider).phase,
        LaunchCoverPhase.covering,
      );
    });

    testWidgets('passes through once storage answers, if launch did not know', (
      tester,
    ) async {
      await pumpGate(tester, stored: {_localeKey: 'en'});
      await tester.pumpAndSettle();

      expect(find.byKey(_home), findsOneWidget);
      expect(find.text('فارسی'), findsNothing);
    });
  });

  group('nothing picked yet', () {
    // The question is a screen of its own: the launch dial has no home dial
    // to land on, so the cover goes rather than waiting over the question.
    testWidgets('ends the launch cover, since it asks', (tester) async {
      final harness = await pumpGate(tester, cover: LaunchCoverPhase.covering);
      await tester.pumpAndSettle();

      expect(
        harness.container.read(launchCoverProvider).phase,
        LaunchCoverPhase.leaving,
      );
    });

    testWidgets('an English device has English picked, asked in English', (
      tester,
    ) async {
      await pumpGate(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(_home), findsNothing);
      expect(selected(tester), 'English');
      expect(find.text(_titles['en']!), findsOneWidget);
      expect(find.text(_hints['en']!), findsOneWidget);
      expect(find.text(_titles['fa']!), findsNothing);
      expect(find.text(_hints['fa']!), findsNothing);
      expect(find.text(_continue['en']!), findsOneWidget);
    });

    testWidgets('a Russian device has Russian picked, asked in Russian '
        'and then English', (tester) async {
      await pumpGate(tester, device: const Locale('ru', 'RU'));
      await tester.pumpAndSettle();

      expect(selected(tester), 'Русский');
      for (final code in ['ru', 'en']) {
        expect(find.text(_titles[code]!), findsOneWidget, reason: code);
        expect(find.text(_hints[code]!), findsOneWidget, reason: code);
      }
      expect(
        tester.getCenter(find.text(_titles['ru']!)).dy,
        lessThan(tester.getCenter(find.text(_titles['en']!)).dy),
      );
      expect(find.text(_titles['fa']!), findsNothing);
    });

    testWidgets('a Chinese device has Chinese picked, asked in Chinese '
        'and English', (tester) async {
      await pumpGate(tester, device: const Locale('zh', 'CN'));
      await tester.pumpAndSettle();

      expect(selected(tester), '中文');
      expect(find.text(_titles['zh']!), findsOneWidget);
      expect(find.text(_titles['en']!), findsOneWidget);
    });

    testWidgets('a device in a language the app lacks has English picked', (
      tester,
    ) async {
      await pumpGate(tester, device: const Locale('de', 'DE'));
      await tester.pumpAndSettle();

      expect(selected(tester), 'English');
    });

    testWidgets('every language the app has is offered', (tester) async {
      await pumpGate(tester);
      await tester.pumpAndSettle();

      await openMenu(tester);

      for (final label in ['English', 'فارسی', '中文', 'Русский']) {
        expect(inMenu(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a Persian device is not asked, and Persian is saved', (
      tester,
    ) async {
      final harness = await pumpGate(tester, device: const Locale('fa', 'IR'));
      await tester.pumpAndSettle();

      expect(find.byKey(_home), findsOneWidget);
      expect(harness.store!.values[_localeKey], 'fa');
      expect(harness.locale.hasSavedLanguage, isTrue);
    });
  });

  group('choosing', () {
    testWidgets('continuing saves the language picked for the device', (
      tester,
    ) async {
      final harness = await pumpGate(tester, device: const Locale('ru'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_continue['ru']!));
      await tester.pumpAndSettle();

      expect(find.byKey(_home), findsOneWidget);
      expect(harness.store!.values[_localeKey], 'ru');
      expect(harness.container.read(localeProvider), const Locale('ru'));
      expect(harness.locale.hasSavedLanguage, isTrue);
    });

    testWidgets('continuing saves a language picked from the menu', (
      tester,
    ) async {
      final harness = await pumpGate(tester);
      await tester.pumpAndSettle();

      await pick(tester, 'فارسی');
      await tester.tap(find.text(_continue['fa']!));
      await tester.pumpAndSettle();

      expect(find.byKey(_home), findsOneWidget);
      expect(harness.store!.values[_localeKey], 'fa');
      expect(harness.container.read(localeProvider), const Locale('fa'));
    });

    testWidgets('the screen follows the language picked, English beneath', (
      tester,
    ) async {
      await pumpGate(tester);
      await tester.pumpAndSettle();

      await pick(tester, 'فارسی');

      expect(find.text(_continue['en']!), findsNothing);
      expect(face(tester, _continue['fa']!), 'Estedad');
      expect(face(tester, _languageLabels['fa']!), 'Estedad');
      expect(
        Directionality.of(tester.element(find.byType(LanguageDropdown))),
        TextDirection.rtl,
      );
      for (final code in ['fa', 'en']) {
        expect(find.text(_titles[code]!), findsOneWidget, reason: code);
        expect(find.text(_hints[code]!), findsOneWidget, reason: code);
      }
      expect(
        tester.getCenter(find.text(_titles['fa']!)).dy,
        lessThan(tester.getCenter(find.text(_titles['en']!)).dy),
      );
      expect(face(tester, _titles['fa']!), 'Estedad');
    });

    testWidgets('picking English asks in English alone', (tester) async {
      await pumpGate(tester, device: const Locale('ru'));
      await tester.pumpAndSettle();

      await pick(tester, 'English');

      expect(find.text(_titles['en']!), findsOneWidget);
      expect(find.text(_hints['en']!), findsOneWidget);
      expect(find.text(_titles['ru']!), findsNothing);
      expect(find.text(_continue['en']!), findsOneWidget);
    });

    testWidgets('picking from the menu saves nothing until continuing', (
      tester,
    ) async {
      final harness = await pumpGate(tester);
      await tester.pumpAndSettle();

      await pick(tester, 'Русский');

      expect(selected(tester), 'Русский');
      expect(find.byKey(_home), findsNothing);
      expect(harness.store!.values.containsKey(_localeKey), isFalse);
      expect(harness.locale.hasSavedLanguage, isFalse);
    });
  });

  testWidgets('storage that cannot be read does not hold the app', (
    tester,
  ) async {
    await pumpGate(tester, storage: const FailingKeyedStorage());
    await tester.pumpAndSettle();

    expect(find.byKey(_home), findsOneWidget);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    await pumpGate(
      tester,
      device: const Locale('ru'),
      surface: const Size(320, 568),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(selected(tester), 'Русский');
    expect(find.text(_continue['ru']!), findsOneWidget);
  });
}
