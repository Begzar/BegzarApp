import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_config_tile.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_server_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// One country or location, expanding to the configs it offers.
///
/// The card is what carries "where am I connected": its border is blue while
/// one of its configs is active, the same blue a step quieter when it holds
/// the one used last, and neutral otherwise.
class PremiumServerCard extends StatelessWidget {
  const PremiumServerCard({
    super.key,
    required this.server,
    required this.expanded,
    required this.state,
    required this.isBusy,
    required this.onToggle,
    required this.onSelectConfig,
  });

  final PremiumServer server;
  final bool expanded;

  /// Read for the ids and pings this card's rows need; the card takes the
  /// whole state rather than seven fields, which had started to drift out of
  /// order at the call site.
  final PremiumServersState state;

  /// A connect or disconnect is running somewhere, so rows other than the one
  /// causing it must not accept a tap.
  final bool isBusy;

  final VoidCallback onToggle;
  final ValueChanged<PremiumServerConfig> onSelectConfig;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final hasActive = server.configs.any(
      (config) => config.id == state.activeConfigId,
    );
    final isLastConnectedServer =
        state.lastConnectedServerId == server.id &&
        !hasActive &&
        state.lastConnectedConfigId != null;

    final fill = hasActive || isLastConnectedServer
        ? palette.cardLive
        : palette.cardSurface;

    return AppGlassPanel(
      style: AppGlass.panel(
        context.palette,
        cornerRadius: AppLayout.premiumCardRadius.r,
        color: fill,
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(
                AppLayout.premiumCardRadius.r,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppLayout.premiumServerCardPadH.w,
                  vertical: AppLayout.premiumServerCardPadV.h,
                ),
                child: _Header(
                  server: server,
                  expanded: expanded,
                  showLastConnectedBadge: isLastConnectedServer && !expanded,
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _Configs(
              server: server,
              state: state,
              isBusy: isBusy,
              onSelectConfig: onSelectConfig,
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: PremiumPalette.stateChange,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.server,
    required this.expanded,
    required this.showLastConnectedBadge,
  });

  final PremiumServer server;
  final bool expanded;
  final bool showLastConnectedBadge;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    return Row(
      children: [
        PremiumServerIcon(
          size: AppLayout.premiumServerIconSize.w,
          flagCode: server.flagCode,
        ),
        SizedBox(width: AppLayout.premiumServerCardGap.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                server.name,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: AppLayout.text2xl.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: AppLayout.premiumServerCardLabelGap.h),
              Text(
                l10n.premiumServerConfigsCount(server.configs.length),
                style: TextStyle(
                  color: palette.textTertiary,
                  fontFamily: monoFamilyOf(context),
                  fontSize: AppLayout.textMd.sp,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        if (showLastConnectedBadge) ...[
          PremiumConnectionBadge(label: l10n.lastConnected),
          SizedBox(width: AppLayout.premiumServerCardBadgeGap.w),
        ],
        AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: PremiumPalette.stateChange,
          child: Icon(
            Iconsax.arrow_down_1,
            color: palette.textTertiary,
            size: AppLayout.premiumServerCardGlyph.sp,
          ),
        ),
      ],
    );
  }
}

class _Configs extends StatelessWidget {
  const _Configs({
    required this.server,
    required this.state,
    required this.isBusy,
    required this.onSelectConfig,
  });

  final PremiumServer server;
  final PremiumServersState state;
  final bool isBusy;
  final ValueChanged<PremiumServerConfig> onSelectConfig;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.premiumServerCardBodyPadH.w,
          ),
          child: Divider(height: 1, color: palette.divider),
        ),
        ...server.configs.map((config) {
          final isActive = state.activeConfigId == config.id;
          final isConnecting = state.connectingConfigId == config.id;
          return PremiumConfigTile(
            name: config.name,
            isActive: isActive,
            isConnecting: isConnecting,
            isLastConnected:
                !isActive && state.lastConnectedConfigId == config.id,
            pingState: state.pingFor(config.id),
            // The row already connecting stays tappable so it can be
            // cancelled; every other row waits.
            enabled: !isBusy || isConnecting,
            onTap: () => onSelectConfig(config),
          );
        }),
        SizedBox(height: AppLayout.premiumServerCardBodyGap.h),
      ],
    );
  }
}
