import 'dart:math' as math;

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/presentation/home_surface_style.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/main/domain/connect_tap_outcome.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_config_ping_badge.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_server_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// What the home screen is pointed at, in one row below the dial, with
/// whatever else the connect will use under it in the same card.
class HomeServerRow extends ConsumerWidget {
  const HomeServerRow({
    super.key,
    required this.onOpenPicker,
    required this.onRefused,
    this.footer,
  });

  final VoidCallback onOpenPicker;
  final ValueChanged<ConnectTapOutcome> onRefused;

  /// Drawn under the server, past a hairline, and answering taps of its own:
  /// a tap there never opens the picker.
  final Widget? footer;

  static const _quarterTurn = math.pi / 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = PremiumPalette.of(context);
    final premium = ref.watch(premiumProvider);
    final servers = ref.watch(premiumServersProvider);
    final status = ref.watch(
      connectionProvider.select((state) => state.status),
    );

    final lapse = homeSurfaceLapse(premium);
    final chosen = homeSurfaceChoice(premium, servers);
    final isBusy = status.isTransitional;

    return _Surface(
      borderColor: homeServerRowBorderColor(
        palette,
        premium: premium,
        servers: servers,
        status: status,
      ),
      footer: footer,
      onTap: isBusy
          ? null
          : () => lapse == HomeSurfaceLapse.none
                ? onOpenPicker()
                : onRefused(refusalForHomeSurfaceLapse(lapse)),
      child: Row(
        children: [
          _leading(palette, lapse, chosen),
          SizedBox(width: AppLayout.mainServerRowGap.w),
          Expanded(child: _label(context, palette, lapse, chosen)),
          SizedBox(width: AppLayout.mainServerRowGap.w),
          _trailing(context, palette, lapse, chosen, servers, status),
        ],
      ),
    );
  }

  Widget _leading(
    PremiumPalette palette,
    HomeSurfaceLapse lapse,
    HomeSurfaceChoice? chosen,
  ) {
    if (chosen != null) {
      return PremiumServerIcon(
        size: AppLayout.mainServerRowLeadingBox.w,
        flagCode: chosen.flagCode,
      );
    }

    // The offer to buy wears the accent as a lit tile, so it reads as the one
    // thing on the row to press; the other states keep a plain one.
    final offer = lapse == HomeSurfaceLapse.notSubscribed;

    return Container(
      width: AppLayout.mainServerRowLeadingBox.w,
      height: AppLayout.mainServerRowLeadingBox.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: offer
              ? [palette.accent, palette.accentDeep]
              : [palette.iconBoxHigh, palette.iconBoxLow],
        ),
        borderRadius: BorderRadius.circular(
          AppLayout.mainServerRowLeadingRadius.r,
        ),
      ),
      child: Icon(
        switch (lapse) {
          HomeSurfaceLapse.none => Iconsax.global,
          HomeSurfaceLapse.notSubscribed => Iconsax.crown_1,
          HomeSurfaceLapse.expired => Iconsax.calendar_remove,
          HomeSurfaceLapse.inactive => Iconsax.user_remove,
        },
        color: switch (lapse) {
          HomeSurfaceLapse.none => palette.textSecondary,
          HomeSurfaceLapse.notSubscribed => palette.onAccent,
          HomeSurfaceLapse.expired => palette.offerRenew,
          HomeSurfaceLapse.inactive => palette.offerRestore,
        },
        size: AppLayout.mainServerRowLeadingGlyph.sp,
      ),
    );
  }

  Widget _label(
    BuildContext context,
    PremiumPalette palette,
    HomeSurfaceLapse lapse,
    HomeSurfaceChoice? chosen,
  ) {
    final l10n = context.l10n;

    // A withdrawn server is still named, with the reason a new pick is due in
    // place of the config's name.
    final (title, subtitle) = switch (lapse) {
      HomeSurfaceLapse.none when chosen != null && chosen.withdrawn => (
        chosen.serverName,
        l10n.serverRowWithdrawn,
      ),
      HomeSurfaceLapse.none when chosen != null => (
        chosen.serverName,
        chosen.configName,
      ),
      HomeSurfaceLapse.none => (
        l10n.serverRowChoose,
        l10n.serverRowChooseHintFor(Theme.of(context).platform),
      ),
      HomeSurfaceLapse.notSubscribed => (
        l10n.serverRowPremium,
        l10n.serverRowPremiumHint,
      ),
      HomeSurfaceLapse.expired => (
        l10n.serverRowExpired,
        l10n.serverRowExpiredHint,
      ),
      HomeSurfaceLapse.inactive => (
        l10n.serverRowInactive,
        l10n.serverRowInactiveHint,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: AppLayout.mainServerRowTitleSize.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppLayout.mainServerRowTitleToSubtitle.h),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            // A config's name is a reading; the hints are sentences.
            fontFamily: chosen != null && !chosen.withdrawn
                ? monoFamilyOf(context)
                : null,
            // A withdrawn server's hint asks for a new pick, so it is set in
            // the warning ink the row's border wears.
            color: chosen != null && chosen.withdrawn
                ? palette.amberInk
                : palette.textTertiary,
            fontSize: AppLayout.mainServerRowSubtitleSize.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _trailing(
    BuildContext context,
    PremiumPalette palette,
    HomeSurfaceLapse lapse,
    HomeSurfaceChoice? chosen,
    PremiumServersState servers,
    ConnectionStatus status,
  ) {
    if (lapse == HomeSurfaceLapse.none &&
        status == ConnectionStatus.connecting) {
      return SizedBox(
        width: AppLayout.mainServerRowSpinnerSize.w,
        height: AppLayout.mainServerRowSpinnerSize.w,
        child: CircularProgressIndicator(
          strokeWidth: AppLayout.mainServerRowSpinnerStroke.w,
          color: palette.amberInk,
        ),
      );
    }

    // A chosen server swaps for another, so its glyph is the up-and-down of a
    // picker; an offer leads on, so its chevron points the way the line reads.
    final glyph = lapse == HomeSurfaceLapse.none
        ? Icon(
            Iconsax.arrow_swap,
            color: chosen != null && chosen.withdrawn
                ? palette.amberInk
                : palette.textSecondary,
            size: AppLayout.mainServerRowTrailingSize.sp,
          )
        : Transform.rotate(
            angle: Directionality.of(context) == TextDirection.rtl
                ? _quarterTurn
                : -_quarterTurn,
            child: Icon(
              Iconsax.arrow_down_1,
              color: palette.textTertiary,
              size: AppLayout.mainServerRowTrailingSize.sp,
            ),
          );
    // In a small raised tile, so the way on reads as a control of its own.
    final pointer = Container(
      width: AppLayout.mainServerRowPointerBox.w,
      height: AppLayout.mainServerRowPointerBox.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.glassHigh,
        borderRadius: BorderRadius.circular(
          AppLayout.mainServerRowPointerRadius.r,
        ),
      ),
      child: glyph,
    );

    final ping = chosen != null && status != ConnectionStatus.connected
        ? servers.pingFor(chosen.configId)
        : null;

    if (ping == null) return pointer;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PremiumConfigPingBadge(pingState: ping),
        SizedBox(width: AppLayout.mainServerRowGap.w),
        pointer,
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.borderColor,
    required this.child,
    this.footer,
    this.onTap,
  });

  final Color borderColor;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onTap;

  static const _disabledOpacity = 0.5;

  @override
  Widget build(BuildContext context) {
    final corner = Radius.circular(AppLayout.mainPanelCornerRadius.r);
    final footer = this.footer;

    return Opacity(
      opacity: onTap == null ? _disabledOpacity : 1,
      child: AppGlassPanel(
        style: AppGlass.homeSurface(
          context.palette,
          cornerRadius: AppLayout.mainPanelCornerRadius,
          borderColor: borderColor,
        ),
        child: Material(
          color: Colors.transparent,
          // The footer's own taps stay inside its own ink, so the card
          // clips both to its corners.
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.all(corner),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.mainPanelInnerPaddingH.w,
                    vertical: AppLayout.mainPanelInnerPaddingV.h,
                  ),
                  child: child,
                ),
              ),
              if (footer != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.mainPanelInnerPaddingH.w,
                  ),
                  child: Container(
                    height: 1,
                    color: MainPalette.of(context).divider,
                  ),
                ),
                footer,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

ConnectTapOutcome refusalForHomeSurfaceLapse(HomeSurfaceLapse lapse) =>
    switch (lapse) {
      HomeSurfaceLapse.notSubscribed => ConnectTapOutcome.notEntitled,
      HomeSurfaceLapse.expired => ConnectTapOutcome.subscriptionExpired,
      HomeSurfaceLapse.inactive => ConnectTapOutcome.accountInactive,
      HomeSurfaceLapse.none => ConnectTapOutcome.ignored,
    };
