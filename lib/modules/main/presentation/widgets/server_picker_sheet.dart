import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_sheet_handle.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_servers_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The premium server list, raised over the home screen.
class ServerPickerSheet extends ConsumerWidget {
  const ServerPickerSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
      builder: (_) => const ServerPickerSheet._(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(connectionProvider, (previous, next) {
      final justConnected =
          next.status == ConnectionStatus.connected &&
          previous?.status != ConnectionStatus.connected;
      if (!justConnected) return;

      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    });

    return Container(
      height:
          MediaQuery.sizeOf(context).height *
          AppLayout.mainPickerHeightFraction,
      decoration: BoxDecoration(
        color: PremiumPalette.of(context).sheetSurface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppLayout.mainPickerRadius.r),
        ),
      ),
      child: Column(
        children: [
          const AppSheetHandle(),
          SizedBox(height: AppLayout.mainPickerHandleToList.h),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(overscroll: false),
              child: const PremiumServersList(),
            ),
          ),
        ],
      ),
    );
  }
}
