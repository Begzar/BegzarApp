import 'dart:async';

import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/ip_info/presentation/controllers/ip_info_provider.dart';
import 'package:begzar/modules/main/presentation/controllers/ping_notifier.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_info_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _designSize = Size(393, 852);
const _largeHandset = Size(412, 915);
const _smallHandset = Size(360, 780);

const _lineHeight = 1.25;
const _tolerance = 0.01;

class _FixedConnection extends ConnectionNotifier {
  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: ConnectionStatus.connected);
}

class _PendingPing extends PingNotifier {
  @override
  AsyncValue<int?> build() => const AsyncValue<int?>.loading();

  @override
  Future<void> measure() async {}
}

Widget _panelLoading() {
  return ProviderScope(
    overrides: [
      connectionProvider.overrideWith(_FixedConnection.new),
      pingProvider.overrideWith(_PendingPing.new),
      ipInfoProvider.overrideWith((ref) => Completer<Never>().future),
    ],
    child: ScreenUtilInit(
      designSize: _designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const Scaffold(body: Center(child: ConnectionInfoWidget())),
      ),
    ),
  );
}

List<Rect> _barsIn(WidgetTester tester) {
  final bars = find.descendant(
    of: find.byType(ConnectionInfoWidget),
    matching: find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.color == Colors.white &&
          decoration.borderRadius != null;
    }),
  );
  return [
    for (var i = 0; i < tester.widgetList(bars).length; i++)
      tester.getRect(bars.at(i)),
  ];
}

Future<void> _pumpPastEntry(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void _expectBarGap(List<Rect> bars, int first, int second) {
  final gap = bars[second].top - bars[first].bottom;
  final leading =
      (bars[first].height + bars[second].height) * (_lineHeight - 1) / 2;

  expect(
    gap,
    greaterThanOrEqualTo(leading - _tolerance),
    reason:
        'bars $first and $second are $gap apart, closer than the '
        '${leading.toStringAsFixed(2)} the glyph runs they stand in for are.',
  );
}

void main() {
  group('the shimmer keeps the air the text has between its lines', () {
    for (final surface in [_smallHandset, _designSize, _largeHandset]) {
      testWidgets('ConnectionInfoWidget at ${surface.width.toInt()}pt', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = surface;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_panelLoading());
        await _pumpPastEntry(tester);

        final bars = _barsIn(tester);
        expect(
          bars,
          hasLength(4),
          reason:
              'address, country, ping icon, and ping text each shimmer as one '
              'bar. Found ${bars.length}.',
        );

        _expectBarGap(bars, 0, 1);
      });
    }
  });

  testWidgets('the bars stay inside the box the panel reserves', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _designSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_panelLoading());
    await _pumpPastEntry(tester);

    final box = tester.getRect(
      find.descendant(
        of: find.byType(ConnectionInfoWidget),
        matching: find.byType(AnimatedSwitcher),
      ),
    );
    for (final bar in _barsIn(tester)) {
      expect(
        box.contains(bar.topLeft) && box.contains(bar.bottomRight),
        isTrue,
        reason:
            'a bar at $bar left the panel box at $box. Widening the gap '
            'between the bars spends room the reserved box has to hold.',
      );
    }
  });
}
