import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/app_update/presentation/widgets/force_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/coloured_shadows.dart';

const _designSize = Size(393, 852);

/// The dialog alone, in English, and the strings it is read in.
Future<AppLocalizations> _pumpDialog(WidgetTester tester) async {
  tester.view.physicalSize = _designSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: _designSize,
      builder: (context, _) => const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: Scaffold(
          body: ForceUpdateDialog(
            currentVersion: '7.0.0',
            requiredVersion: '8.0.0',
            updateUrl: 'https://example.invalid/update',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(ForceUpdateDialog)));
}

void main() {
  group('ForceUpdateDialog', () {
    // The cloud in its ring is the dialog's mark, not a state, so it carries
    // no glow; the dialog's own black shadow is depth and stays.
    testWidgets('should draw the update mark without a glow', (tester) async {
      await _pumpDialog(tester);

      expect(
        colouredShadowsUnder(tester, find.byType(ForceUpdateDialog)),
        isEmpty,
      );
      // The halo behind the ring was the same glow, drawn as a radial wash.
      expect(
        find.descendant(
          of: find.byType(ForceUpdateDialog),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                (widget.decoration as BoxDecoration?)?.gradient
                    is RadialGradient,
          ),
        ),
        findsNothing,
      );
    });

    // The update button is the dialog's one action, and an action on this app
    // is a solid fill: a glow marks a state, like the dial's connection.
    testWidgets('should draw no glow under the update button', (tester) async {
      final l10n = await _pumpDialog(tester);

      final fill = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text(l10n.updateNow),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is DecoratedBox &&
                    (widget.decoration as BoxDecoration?)?.gradient != null,
              ),
            )
            .first,
      );

      expect(
        (fill.decoration as BoxDecoration).boxShadow ?? const <BoxShadow>[],
        isEmpty,
      );
    });

    // A build too old is told so at launch, often before the launch cover has
    // carried its dial into home. The dial must not travel over the dialog.
    testWidgets('should end the launch cover when it opens', (tester) async {
      final container = ProviderContainer(
        overrides: [
          launchCoverProvider.overrideWith(
            () => LaunchCoverNotifier(initial: LaunchCoverPhase.covering),
          ),
        ],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = _designSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: _designSize,
            builder: (context, _) => MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => ForceUpdateDialog.show(
                    context,
                    currentVersion: '1.0.0',
                    requiredVersion: '8.0.0',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();

      expect(
        container.read(launchCoverProvider).phase,
        LaunchCoverPhase.leaving,
      );
    });
  });
}
