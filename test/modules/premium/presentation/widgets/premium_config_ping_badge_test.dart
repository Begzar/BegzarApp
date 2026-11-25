import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_config_ping_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frame-sized ticks, not one long pump: the shimmer's own animation repeats
/// forever, and a single pump past the swap leaves its entry unremoved.
const _frame = Duration(milliseconds: 40);

/// Comfortably past the badge's swap and the resize that follows it.
const _framesToSettle = 20;

/// Wider than any reading, so the badge has room it does not need — which is
/// the state it is in for the whole of a swap, while the shimmer it is
/// replacing still holds the box open.
const _roomiestBox = 600.0;

/// Where the reading starts in the language on screen — the right edge under
/// Persian, which is the side the icon and number read from.
double _startEdge(WidgetTester tester, Finder finder) =>
    tester.getTopRight(finder).dx;

double _badgeWidth(WidgetTester tester) =>
    tester.getSize(find.byType(PremiumConfigPingBadge)).width;

/// Pumps the badge alone, driven by a notifier a test can push new states
/// into. [width] leaves it more room than its content needs.
Widget _badgeUnderTest(
  ValueNotifier<ConfigPingState?> pingState, {
  double? width,
}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      locale: const Locale('fa'),
      // The same four the app declares in app.dart.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fa')],
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: width,
            child: ValueListenableBuilder<ConfigPingState?>(
              valueListenable: pingState,
              builder: (context, value, _) =>
                  PremiumConfigPingBadge(pingState: value),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('PremiumConfigPingBadge', () {
    testWidgets('reads from the start edge of the room it is given', (
      tester,
    ) async {
      final pingState = ValueNotifier<ConfigPingState?>(
        const ConfigPingState.success(116),
      );
      addTearDown(pingState.dispose);

      await tester.pumpWidget(_badgeUnderTest(pingState, width: _roomiestBox));
      await tester.pump();

      expect(
        _startEdge(tester, find.byType(Icon)),
        _startEdge(tester, find.byType(PremiumConfigPingBadge)),
        reason:
            'centred in its box, a reading narrower than the room it is in '
            'sits inset — which is where every reading is parked while the '
            'shimmer it replaces still holds that box open, and the step '
            'across to its resting place is the jump this guards',
      );
    });

    testWidgets('closes the room it reserved gradually, not in one frame', (
      tester,
    ) async {
      final pingState = ValueNotifier<ConfigPingState?>(
        const ConfigPingState.loading(),
      );
      addTearDown(pingState.dispose);

      await tester.pumpWidget(_badgeUnderTest(pingState));
      await tester.pump();
      final shimmerWidth = _badgeWidth(tester);

      // Every frame of it: the resize only starts once the swap has finished
      // handing the room back, so which frame lands mid-way is not fixed.
      pingState.value = const ConfigPingState.success(116);
      final widths = <double>[];
      for (var frame = 0; frame < _framesToSettle; frame++) {
        await tester.pump(_frame);
        widths.add(_badgeWidth(tester));
      }
      final settledWidth = widths.last;

      expect(
        settledWidth,
        lessThan(shimmerWidth),
        reason: 'the reading needs less room than the shimmer reserved',
      );
      expect(
        widths.any((width) => width < shimmerWidth && width > settledWidth),
        isTrue,
        reason:
            'the badge is caught between the two widths at least once — the '
            'row gives the room back over the transition rather than '
            'snapping it shut in a single frame',
      );
    });

    testWidgets('takes no width before anything has been measured', (
      tester,
    ) async {
      final pingState = ValueNotifier<ConfigPingState?>(null);
      addTearDown(pingState.dispose);

      await tester.pumpWidget(_badgeUnderTest(pingState));
      await tester.pumpAndSettle();

      expect(
        _badgeWidth(tester),
        0,
        reason:
            'a row that has never been pinged must not claim the room a '
            'measurement would need — it has not said the server is '
            'unreachable, or anything else',
      );
    });
  });
}
