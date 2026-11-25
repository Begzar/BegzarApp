import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_config_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _tileUnderTest({
  bool isActive = false,
  bool isConnecting = false,
  bool isLastConnected = false,
  VoidCallback? onTap,
}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PremiumConfigTile(
          name: 'DE',
          isActive: isActive,
          isConnecting: isConnecting,
          isLastConnected: isLastConnected,
          pingState: null,
          enabled: true,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

/// Whether [finder] closes the row: its far edge sits on the row's padding.
bool _endsTheRow(WidgetTester tester, Finder finder) {
  final row = tester.getRect(find.byType(PremiumConfigTile));
  final badge = tester.getRect(finder);
  final padding = AppLayout.premiumConfigPadH.w;
  return (row.right - padding - badge.right).abs() < 1;
}

void main() {
  group('PremiumConfigTile', () {
    testWidgets('should not label the connected row with disconnect', (
      tester,
    ) async {
      await tester.pumpWidget(_tileUnderTest(isActive: true));

      expect(find.text('Disconnect'), findsNothing);
    });

    testWidgets('should still answer a tap on the connected row', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _tileUnderTest(isActive: true, onTap: () => taps++),
      );

      await tester.tap(find.byType(PremiumConfigTile));

      expect(taps, 1);
    });

    testWidgets('should end the connected row with a connected badge', (
      tester,
    ) async {
      await tester.pumpWidget(_tileUnderTest(isActive: true));

      expect(
        _endsTheRow(
          tester,
          find.widgetWithText(PremiumConnectionBadge, 'Connected'),
        ),
        isTrue,
      );
    });

    testWidgets(
      'should end the last connected row with a last connected badge',
      (tester) async {
        await tester.pumpWidget(_tileUnderTest(isLastConnected: true));

        expect(
          _endsTheRow(
            tester,
            find.widgetWithText(PremiumConnectionBadge, 'Last connected'),
          ),
          isTrue,
        );
      },
    );

    testWidgets('should end a connecting row with a spinner, not a badge', (
      tester,
    ) async {
      await tester.pumpWidget(_tileUnderTest(isConnecting: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PremiumConnectionBadge), findsNothing);
    });

    testWidgets('should not badge a row that was never connected', (
      tester,
    ) async {
      await tester.pumpWidget(_tileUnderTest());

      expect(find.byType(PremiumConnectionBadge), findsNothing);
    });
  });
}
