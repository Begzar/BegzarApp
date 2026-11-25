import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/presentation/controllers/selected_tab_notifier.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Reports a fixed status without watching the service graph.
class _FixedConnection extends ConnectionNotifier {
  _FixedConnection(this.status);

  final ConnectionStatus status;

  @override
  ConnectionEntity build() =>
      ConnectionEntity.create().copyWith(status: status);
}

void main() {
  group('NavBar does not mirror', () {
    Future<List<double>> iconCentres(
      WidgetTester tester,
      TextDirection direction,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionProvider.overrideWith(
              () => _FixedConnection(ConnectionStatus.ready),
            ),
          ],
          // The bar is measured in `.w` now, like everything else on this
          // screen, so it needs the scale set up before it can lay out.
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp(
              // The tabs read their names from the localizations.
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Directionality(
                textDirection: direction,
                child: NavBar(selected: homeIndex, onSelect: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      return [
        for (final icon in [
          Iconsax.setting_2_copy,
          Iconsax.home_copy,
          Iconsax.user_copy,
        ])
          tester.getRect(find.byIcon(icon).at(0)).center.dx,
      ];
    }

    // The bar publishes what a screen scrolling under it has to leave free.
    // Both screens that do so used to carry their own copy of that number,
    // and both were short: the old bar's height depended on which tab was
    // selected, and the raised one reached ten points past what either
    // allowed for. Whatever the bar is made of, this has to hold.
    testWidgets('the published clearance actually clears the bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionProvider.overrideWith(
              () => _FixedConnection(ConnectionStatus.ready),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Stack(
                children: [
                  Positioned(
                    bottom: NavBar.bottomInset.w,
                    left: 0,
                    right: 0,
                    child: NavBar(selected: homeIndex, onSelect: (_) {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final screen = tester.getSize(find.byType(MaterialApp)).height;
      final reach = screen - tester.getRect(find.byType(NavBar)).top;

      expect(
        reach,
        lessThanOrEqualTo(NavBar.clearance.w),
        reason: 'content kept NavBar.clearance clear would sit behind the bar',
      );
    });

    testWidgets('settings, home, account — in that order either way', (
      tester,
    ) async {
      final ltr = await iconCentres(tester, TextDirection.ltr);
      expect(ltr[0], lessThan(ltr[1]));
      expect(ltr[1], lessThan(ltr[2]));

      final rtl = await iconCentres(tester, TextDirection.rtl);
      expect(
        rtl,
        ltr,
        reason:
            'the bar is furniture: switching to Persian must not move the '
            'account tab to the other side of a tab the user has learned',
      );
    });
  });
}
