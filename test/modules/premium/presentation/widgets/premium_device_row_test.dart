import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/errors/error_presentation.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/di/premium_providers.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_device_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../premium_test_doubles.dart';

/// Past the eight seconds the error toast stays up for.
const _pastTheToast = Duration(seconds: 9);

const _otherDevice = PremiumDevice(deviceId: 'other', deviceName: 'Old tablet');

Widget _rowUnderTest(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('fa')],
        home: Scaffold(
          body: PremiumDeviceRow(
            device: _otherDevice,
            isCurrent: false,
            isRemoving: false,
            canRemove: true,
          ),
        ),
      ),
    ),
  );
}

void main() {
  /// Pumps the row against a server that answers a removal with [result],
  /// confirms the removal, and lets whatever reports it slide in.
  Future<AppLocalizations> removeAgainst(
    WidgetTester tester,
    Either<ApiFailure, int> result,
  ) async {
    final container = ProviderContainer(
      overrides: [
        premiumRepositoryProvider.overrideWithValue(
          FakePremiumRepository(removeDeviceResult: result),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_rowUnderTest(container));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PremiumDeviceRow)),
    );

    await tester.tap(find.text(l10n.removeDevice));
    await tester.pumpAndSettle();
    // The dialog's own action carries the same label as the row's button.
    await tester.tap(find.text(l10n.removeDevice).last);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    return l10n;
  }

  group('PremiumDeviceRow', () {
    testWidgets('should report a failed removal in the error toast', (
      tester,
    ) async {
      final l10n = await removeAgainst(
        tester,
        left(const RateLimitFailure('quota')),
      );
      final error = ErrorPresentation.fromKey(
        UserFacingErrorKeys.rateLimit,
        l10n,
      );

      expect(find.text(error.message), findsOneWidget);
      expect(
        find.text(error.hint!),
        findsOneWidget,
        reason:
            'the plain snackbar dropped the hint the line above the device '
            'list used to carry, and that line is gone',
      );
      expect(find.byType(SnackBar), findsNothing);

      await tester.pump(_pastTheToast);
    });

    testWidgets('should confirm a removal in a snackbar', (tester) async {
      final l10n = await removeAgainst(tester, right(1));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(l10n.deviceRemovedSuccess), findsOneWidget);

      await tester.pump(_pastTheToast);
    });
  });
}
