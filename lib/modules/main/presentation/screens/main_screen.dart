import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/modules/app_update/presentation/controllers/force_update_notifier.dart';
import 'package:begzar/modules/app_update/presentation/states/force_update_state.dart';
import 'package:begzar/modules/app_update/presentation/widgets/force_update_dialog.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/main/presentation/widgets/connect_tap_dialogs.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_button.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_info_widget.dart';
import 'package:begzar/modules/main/presentation/widgets/home_app_bar.dart';
import 'package:begzar/modules/main/presentation/widgets/home_server_row.dart';
import 'package:begzar/modules/main/presentation/widgets/home_settings_line.dart';
import 'package:begzar/modules/main/presentation/widgets/nav_bar.dart';
import 'package:begzar/modules/main/presentation/widgets/server_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      connectionProvider.select((state) => state.status),
    );

    _listenForForcedUpdate(context, ref);
    _listenForConnectionErrors(context, ref);

    return Scaffold(
      body: AnimatedContainer(
        duration: MainPalette.backgroundShift,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: context.palette.pageGradient(status.mood),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const HomeAppBar(),
              SizedBox(height: AppLayout.mainAppBarToIp.h),
              // The dial below repaints on every frame, and without a boundary
              // its siblings share a layer with it and are re-rasterized at
              // the same rate. This panel's contents change only when a lookup
              // lands, so it has no business repainting with the breath.
              // The exit address while a tunnel is up, and nothing while none
              // is: the reading fades rather than collapsing, so its slot
              // keeps its height and the dial does not move between states.
              // Not being connected is where the app rests, and the status
              // line under the dial says so once.
              const RepaintBoundary(child: ConnectionInfoWidget()),
              SizedBox(height: AppLayout.mainIpToDial.h),
              // The dial and the server row share everything left over, in
              // equal parts: air above the dial, between the two, and under
              // the row. The row standing the same distance from the dial as
              // from the nav bar is the whole point of the arrangement — it
              // used to be pinned to the bar by a fixed padding, which left
              // the gap above it to be whatever the dial had not used, and the
              // two were never the same.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const ConnectionButtonWidget(),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.mainPanelOuterInset.w,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: AppLayout.mainPanelGlassWidth.w,
                          // Same reason as the panel above: this row changes
                          // when the chosen server does, not when the dial
                          // breathes.
                          child: RepaintBoundary(
                            child: HomeServerRow(
                              footer: const HomeSettingsLine(),
                              onOpenPicker: () =>
                                  ServerPickerSheet.show(context),
                              onRefused: (outcome) => showConnectTapExplanation(
                                context,
                                ref,
                                outcome,
                                status: status,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // The bar's bare footprint, with none of its breathing gap: the
              // air under the row is the even gap above, and reserving the
              // bar's own on top of it would push the row off centre by
              // exactly that much.
              SizedBox(height: NavBar.footprint.w),
            ],
          ),
        ),
      ),
    );
  }

  /// Raises the update dialog once, on the transition into required.
  void _listenForForcedUpdate(BuildContext context, WidgetRef ref) {
    ref.listen<ForceUpdateState>(forceUpdateProvider, (previous, next) {
      if (!next.required || (previous?.required ?? false)) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ForceUpdateDialog.show(
          context,
          currentVersion: next.currentVersion,
          requiredVersion: next.requiredVersion,
          updateUrl: next.updateUrl,
        );
      });
    });
  }

  /// Surfaces a connect failure once, on the transition into error — not on
  /// every rebuild while the error is still on screen.
  void _listenForConnectionErrors(BuildContext context, WidgetRef ref) {
    ref.listen(connectionProvider, (previous, next) {
      final becameError =
          next.status == ConnectionStatus.error &&
          previous?.status != ConnectionStatus.error;
      if (!becameError) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showTopErrorPopup(context, next.errorMessage);
      });
    });
  }
}
