import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Raw text of the kind the proxy engine throws, used to check that none of it
/// reaches the screen.
const String _rawEngineText = 'xray: failed to dial tcp 10.0.0.1:443';

/// Stands in for the connection state: a plain key the test can change.
class _ErrorHolder extends Notifier<String?> {
  @override
  String? build() => null;

  void fail(String key) => state = key;
}

final _errorProvider = NotifierProvider<_ErrorHolder, String?>(
  _ErrorHolder.new,
);

/// Mirrors what `MainScreen` does — listen for the transition into an error and
/// raise the popup from a post-frame callback.
///
/// The indirection matters: the popup needs an `Overlay`, and raising it during
/// the build that produced the error would be too early for one to exist.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(_errorProvider, (previous, next) {
      if (next == null || previous == next) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showTopErrorPopup(context, next);
      });
    });
    return const Scaffold(body: SizedBox.expand());
  }
}

Widget _appUnderTest({Locale locale = const Locale('en')}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fa')],
      home: const _Host(),
    ),
  );
}

/// Pumps the app, pushes [errorKey] through the listener, and settles the
/// toast's entry animation. Returns the localizations the toast was built with,
/// so a caller can ask for the same translation it should be showing.
Future<AppLocalizations> _failWith(
  WidgetTester tester,
  String errorKey, {
  Locale locale = const Locale('en'),
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _appUnderTest(locale: locale),
    ),
  );
  await tester.pumpAndSettle();

  container.read(_errorProvider.notifier).fail(errorKey);
  // One frame to run the listener, one for its post-frame callback, then the
  // 280ms entry animation.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return AppLocalizations.of(tester.element(find.byType(Scaffold)));
}

/// Just short of the eight seconds the toast stays up for.
const _justBeforeDismissal = Duration(milliseconds: 7500);

/// Past the eight seconds, with room for the frame that removes the entry.
const _pastDismissal = Duration(seconds: 9);

/// Runs out the toast's eight-second dismiss timer.
///
/// Not decoration: the test binding fails a test that ends with a timer
/// pending, and it also asserts the toast does not outstay its welcome.
Future<void> _expectSelfDismissal(WidgetTester tester, String message) async {
  await tester.pump(_pastDismissal);
  expect(find.text(message), findsNothing);
}

void main() {
  for (final locale in [const Locale('en'), const Locale('fa')]) {
    testWidgets('a connect failure is explained in ${locale.languageCode}', (
      tester,
    ) async {
      final l10n = await _failWith(
        tester,
        UserFacingErrorKeys.proxyTestFailed,
        locale: locale,
      );
      final expected = l10n.translateError(UserFacingErrorKeys.proxyTestFailed);

      expect(
        expected.trim(),
        isNotEmpty,
        reason: 'an untranslated key makes showTopErrorPopup return silently',
      );
      expect(
        find.text(expected),
        findsOneWidget,
        reason:
            'a failed connect that says nothing leaves the user with a red '
            'screen and no reason for it',
      );

      await _expectSelfDismissal(tester, expected);
    });
  }

  testWidgets('text the engine threw is translated, not shown', (tester) async {
    final l10n = await _failWith(tester, _rawEngineText);
    // Which key that text resolves to is `user_facing_errors`' business, and is
    // covered there. What matters here is that the toast shows the translation
    // rather than the string it was handed.
    final expected = l10n.translateError(
      resolveUserFacingErrorKey(_rawEngineText),
    );

    expect(
      find.text(expected),
      findsOneWidget,
      reason: 'an unrecognized failure still owes the user an explanation',
    );
    expect(
      find.textContaining('xray'),
      findsNothing,
      reason: 'engine text names hosts and ports the user must not be shown',
    );

    await _expectSelfDismissal(tester, expected);
  });

  // The toast is the only report an error gets, so how long it stays and what
  // happens when a second one arrives decide whether the reason is read at all.
  group('showTopErrorPopup', () {
    testWidgets('should still be on screen just before eight seconds', (
      tester,
    ) async {
      final l10n = await _failWith(tester, UserFacingErrorKeys.networkError);
      final expected = l10n.translateError(UserFacingErrorKeys.networkError);

      await tester.pump(_justBeforeDismissal);
      expect(
        find.text(expected),
        findsOneWidget,
        reason:
            'nothing else on screen repeats the reason, so a toast gone in '
            'four seconds is missed by anyone who looked away',
      );

      await _expectSelfDismissal(tester, expected);
    });

    testWidgets('should take itself off screen after eight seconds', (
      tester,
    ) async {
      final l10n = await _failWith(tester, UserFacingErrorKeys.networkError);
      final expected = l10n.translateError(UserFacingErrorKeys.networkError);

      await tester.pump(_pastDismissal);

      expect(find.text(expected), findsNothing);
    });

    testWidgets('should replace the toast already on screen', (tester) async {
      final l10n = await _failWith(tester, UserFacingErrorKeys.networkError);
      final first = l10n.translateError(UserFacingErrorKeys.networkError);
      final second = l10n.translateError(UserFacingErrorKeys.noWorkingConfig);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      container
          .read(_errorProvider.notifier)
          .fail(UserFacingErrorKeys.noWorkingConfig);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text(first),
        findsNothing,
        reason:
            'both toasts sit at the same spot, so a second one stacked on '
            'the first paints one reason over the other',
      );
      expect(find.text(second), findsOneWidget);

      await _expectSelfDismissal(tester, second);
    });
  });
}
