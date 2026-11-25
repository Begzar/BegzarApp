import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_radio_options.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

const _designSize = Size(393, 852);

/// Two values to choose between, standing in for any the widget is given.
enum _Choice { chosen, other }

const _chosenTitle = 'Chosen';
const _otherTitle = 'Other';

/// Short enough to fit on one line beside the chip and the radio.
const _chosenHint = 'What choosing it does';
const _icon = Iconsax.shield_tick_copy;

Finder _rowOf(_Choice choice) => find.byWidgetPredicate(
  (widget) => widget is RadioListTile<_Choice> && widget.value == choice,
);

Finder _radioOf(_Choice choice) =>
    find.descendant(of: _rowOf(choice), matching: find.byType(Radio<_Choice>));

/// Whether [first] ends before [second] starts, reading in [direction].
bool _precedes(Rect first, Rect second, TextDirection direction) =>
    switch (direction) {
      TextDirection.ltr => first.right <= second.left,
      TextDirection.rtl => first.left >= second.right,
    };

void main() {
  /// Mounts both rows reading in [direction], each carrying [icon] when one
  /// is given, with the first row chosen.
  Future<void> pumpOptions(
    WidgetTester tester, {
    TextDirection direction = TextDirection.ltr,
    IconData? icon,
  }) async {
    tester.view.physicalSize = _designSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: _designSize,
        builder: (context, _) => MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: SettingsRadioOptions<_Choice>(
                groupValue: _Choice.chosen,
                onChanged: (_) {},
                options: [
                  SettingsRadioOption(
                    value: _Choice.chosen,
                    title: _chosenTitle,
                    hint: _chosenHint,
                    icon: icon,
                  ),
                  SettingsRadioOption(
                    value: _Choice.other,
                    title: _otherTitle,
                    hint: 'What choosing the other does',
                    icon: icon,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SettingsRadioOptions', () {
    for (final direction in TextDirection.values) {
      // App Routing's choice shares these rows and gives them no icon, and it
      // has to look as it did before any row could carry one.
      testWidgets('should draw no chip and lead with the radio without an icon '
          '(${direction.name})', (tester) async {
        await pumpOptions(tester, direction: direction);

        expect(find.byType(SettingsTileIcon), findsNothing);
        expect(
          _precedes(
            tester.getRect(_radioOf(_Choice.chosen)),
            tester.getRect(find.text(_chosenTitle)),
            direction,
          ),
          isTrue,
        );
      });

      // An iconed row reads like the switch rows: the chip first, the
      // control last, in either direction.
      testWidgets(
        'should lead with the chip and end with the radio given an icon '
        '(${direction.name})',
        (tester) async {
          await pumpOptions(tester, direction: direction, icon: _icon);

          final chip = find.descendant(
            of: _rowOf(_Choice.chosen),
            matching: find.widgetWithIcon(SettingsTileIcon, _icon),
          );
          expect(chip, findsOneWidget);
          final title = tester.getRect(find.text(_chosenTitle));
          expect(_precedes(tester.getRect(chip), title, direction), isTrue);
          expect(
            _precedes(
              title,
              tester.getRect(_radioOf(_Choice.chosen)),
              direction,
            ),
            isTrue,
          );
        },
      );
    }

    // A tile with a subtitle keeps a two-line minimum height and centres a
    // short hint in it, which left a one-line row taller than the switch
    // rows beside it. The density differs between phone and desktop, and so
    // does that minimum.
    testWidgets(
      'should stack an iconed row from its insets, title, gap and hint',
      (tester) async {
        await pumpOptions(tester, icon: _icon);

        final title = tester.getRect(find.text(_chosenTitle));
        final hint = tester.getRect(find.text(_chosenHint));
        expect(
          tester.getRect(_rowOf(_Choice.chosen)).height,
          moreOrLessEquals(
            2 * AppLayout.settingsSwitchPadV.h +
                title.height +
                AppLayout.settingsTileLabelGap.h +
                hint.height,
          ),
        );
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );

    // A choice opens the Connection section on Windows and switch rows follow
    // it, so the radios and the switches stand in one column down the card's
    // end. Sharing the switch rows' end inset was not enough: the radio is
    // smaller than the switch, and its centre sat nearer the edge.
    for (final direction in TextDirection.values) {
      testWidgets(
        'should centre the radio on the switch rows\' switch '
        '(${direction.name})',
        (tester) async {
          tester.view.physicalSize = _designSize;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ScreenUtilInit(
              designSize: _designSize,
              builder: (context, _) => MaterialApp(
                home: Directionality(
                  textDirection: direction,
                  child: Scaffold(
                    body: Column(
                      children: [
                        SettingsRadioOptions<_Choice>(
                          groupValue: _Choice.chosen,
                          onChanged: (_) {},
                          options: const [
                            SettingsRadioOption(
                              value: _Choice.chosen,
                              title: _chosenTitle,
                              hint: _chosenHint,
                              icon: _icon,
                            ),
                          ],
                        ),
                        SettingsSwitchTile(
                          icon: _icon,
                          title: _otherTitle,
                          subtitle: _chosenHint,
                          value: true,
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.getCenter(_radioOf(_Choice.chosen)).dx,
            moreOrLessEquals(tester.getCenter(find.byType(Switch)).dx),
          );
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.windows,
        }),
      );
    }

    // The rule between two rows starts clear of the icons and runs to the
    // card's far edge. Inset on the left, Persian's ran under the icons and
    // stopped short of the end.
    for (final direction in TextDirection.values) {
      testWidgets('should run a divider from past the icons to the far edge '
          '(${direction.name})', (tester) async {
        tester.view.physicalSize = _designSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: _designSize,
            builder: (context, _) => MaterialApp(
              home: Directionality(
                textDirection: direction,
                child: const Scaffold(body: SettingsSectionDivider()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rule = tester.getRect(find.byType(Divider));
        final inset = AppLayout.settingsDividerInset.w;
        switch (direction) {
          case TextDirection.ltr:
            expect(rule.left, moreOrLessEquals(inset));
            expect(rule.right, moreOrLessEquals(_designSize.width));
          case TextDirection.rtl:
            expect(rule.left, moreOrLessEquals(0));
            expect(rule.right, moreOrLessEquals(_designSize.width - inset));
        }
      });
    }

    // The chip is drawn, not announced: a screen reader still meets one radio
    // per row, named by its title and saying whether it is the one chosen.
    testWidgets('should announce an iconed row as a radio with its title', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpOptions(tester, icon: _icon);

      for (final (choice, title, chosen) in [
        (_Choice.chosen, _chosenTitle, true),
        (_Choice.other, _otherTitle, false),
      ]) {
        final node = tester.getSemantics(_rowOf(choice));
        expect(
          node,
          isSemantics(
            hasCheckedState: true,
            isChecked: chosen,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
          reason: title,
        );
        expect(node.getSemanticsData().label.split('\n').first, title);
      }
      semantics.dispose();
    });
  });
}
