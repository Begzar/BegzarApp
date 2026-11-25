import 'package:begzar/core/theme/app_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:begzar/core/errors/user_facing_errors.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/core/widgets/soft_enter.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/connection/presentation/controllers/tunnel_liveness_notifier.dart';
import 'package:begzar/modules/main/presentation/controllers/main_screen_controller.dart';
import 'package:begzar/modules/main/presentation/widgets/connect_tap_dialogs.dart';
import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:begzar/modules/ip_info/presentation/controllers/ip_info_provider.dart';
import 'package:begzar/modules/main/domain/ping_quality.dart';
import 'package:begzar/modules/main/presentation/controllers/ping_notifier.dart';
import 'package:begzar/modules/main/presentation/home_surface_style.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_server_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shimmer/shimmer.dart';

/// Every measurement the exit reading is drawn at.
abstract final class _IpMetrics {
  static double get flagBox => AppLayout.mainIpFlagBox.w;
  static double get leadingGutter => AppLayout.mainIpLeadingGutter.w;
  static double get flagBoxRadius => AppLayout.mainIpFlagBoxRadius.r;
  static double get flagEmoji => AppLayout.mainIpFlagEmoji.sp;
  static double get gap => AppLayout.mainIpGap.w;
  static const lineHeight = AppLayout.mainIpLineHeight;
  static double get address => AppLayout.mainIpAddressSize.sp;
  static const addressSpacing = AppLayout.mainIpAddressSpacing;
  static double get badgeGap => AppLayout.mainIpBadgeGap.w;
  static EdgeInsets get badgePadding => EdgeInsets.symmetric(
    horizontal: AppLayout.mainIpBadgePadH.w,
    vertical: AppLayout.mainIpBadgePadV.h,
  );
  static double get badgeRadius => AppLayout.mainIpBadgeRadius.r;

  /// How strongly the version chip and the verified check are tinted. Both
  /// are a wash of their own colour with the rim carrying the edge, which is
  /// how every small marker on this screen is built.
  static const badgeFill = 0.25;
  static const badgeRim = 0.45;
  static const checkFill = 0.2;

  /// The glyph on a ping that failed, held a step under full strength: the
  /// row beside it already says what to do about it.
  static const errorGlyphAlpha = 0.7;

  /// A reading that could not be taken, said in half-strength ink.
  static const errorInkAlpha = 0.5;
  static double get badgeText => AppLayout.mainIpBadgeText.sp;
  static double get countryGap => AppLayout.mainIpCountryGap.h;
  static double get country => AppLayout.mainIpCountrySize.sp;
  static double get sectionGap => AppLayout.mainIpSectionGap.h;
  static double get dividerGap => AppLayout.mainIpDividerGap.h;
  static double get checkPadding => AppLayout.mainIpCheckPadding.w;
  static double get checkIcon => AppLayout.mainIpCheckIcon.sp;
  static double get errorIcon => AppLayout.mainIpErrorIcon.sp;
  static double get errorGap => AppLayout.mainIpErrorGap.w;
  static double get errorText => AppLayout.mainIpErrorText.sp;
  static Size get addressBar =>
      Size(AppLayout.mainIpBarWidthAddress.w, address);
  static Size get countryBar =>
      Size(AppLayout.mainIpBarWidthCountry.w, country);
  static Size get pingTextBar =>
      Size(AppLayout.mainIpBarWidthPing.w, _PingMetrics.value);
  static double get textBarGap =>
      (address + country) * (lineHeight - 1) / 2 + countryGap;
  static double get barRadius => AppLayout.mainIpBarRadius.r;
  static EdgeInsets get padding => EdgeInsets.symmetric(
    horizontal: AppLayout.mainPanelInnerPaddingH.w,
    vertical: AppLayout.mainPanelInnerPaddingV.h,
  );
  static Size get contentSize => Size(
    AppLayout.mainPanelContentWidth.w,
    AppLayout.mainPanelIpContentHeight.h,
  );
}

abstract final class _PingMetrics {
  static double get icon => AppLayout.mainPingIcon.sp;
  static double get gap => AppLayout.mainPingGap.w;
  static const lineHeight = AppLayout.mainIpLineHeight;
  static double get value => AppLayout.mainPingValueSize.sp;
  static double get idleText => AppLayout.mainPingIdleText.sp;
  static double get errorIcon => AppLayout.mainPingErrorIcon.sp;
  static double get errorGap => AppLayout.mainPingErrorGap.w;
  static double get errorText => AppLayout.mainPingErrorText.sp;
  static double get refreshIcon => AppLayout.mainPingRefreshIcon.sp;
  static double get refreshSlot => AppLayout.mainPingRefreshSlot.w;
  static double get rowHeight => icon * lineHeight;
  static double get barRadius => AppLayout.mainPingBarRadius.r;
  static double get iconRadius => AppLayout.mainPingIconRadius.r;
}

/// Exit address and latency while connected, centred above the dial.
class ConnectionInfoWidget extends ConsumerWidget {
  const ConnectionInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionProvider);
    final ipInfoAsync = ref.watch(ipInfoProvider);
    final pingAsync = ref.watch(pingProvider);
    final premium = ref.watch(premiumProvider);
    final servers = ref.watch(premiumServersProvider);
    final visible = connectionState.status == ConnectionStatus.connected;
    final stalled = visible && ref.watch(tunnelLivenessProvider).isDead;
    final serverFlagCode = homeSurfaceChoice(premium, servers)?.flagCode;
    // A stalled tunnel's card asks for something to be done, so it wears the
    // warning tint rather than the one it shares with the server row.
    final surfaceBorder = stalled
        ? MainPalette.of(
            context,
          ).stalled.withValues(alpha: PremiumPalette.liveAlpha)
        : homeSurfaceBorderColor(
            PremiumPalette.of(context),
            premium: premium,
            servers: servers,
            status: connectionState.status,
          );

    return SoftEnter(
      visible: visible,
      alignment: Alignment.center,
      slide: const Offset(0, 0.06),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.mainPanelOuterInset.w,
        ),
        child: Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: AppLayout.mainPanelGlassWidth.w,
            child: AppGlassPanel(
              style: AppGlass.homeSurface(
                context.palette,
                cornerRadius: AppLayout.mainPanelCornerRadius,
                borderColor: surfaceBorder,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // A stalled card's taps belong to its two actions.
                onTap: stalled
                    ? null
                    : () => ref.read(pingProvider.notifier).measure(),
                child: Padding(
                  padding: _IpMetrics.padding,
                  child: SizedBox.fromSize(
                    size: _IpMetrics.contentSize,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: <Widget>[...previous, ?current],
                      ),
                      child: stalled
                          ? KeyedSubtree(
                              key: const ValueKey('stalled'),
                              child: _buildStalledState(context, ref),
                            )
                          : ipInfoAsync.when(
                              data: (result) => switch (result) {
                                null => KeyedSubtree(
                                  key: const ValueKey('ip-loading'),
                                  child: _buildLoadingState(context),
                                ),
                                Left(value: final failure) => KeyedSubtree(
                                  key: const ValueKey('ip-error'),
                                  child: _buildErrorState(
                                    context,
                                    failure.userFacingKey,
                                    pingAsync,
                                  ),
                                ),
                                Right(value: final ipInfo) => KeyedSubtree(
                                  key: ValueKey('ip-${ipInfo.ip}'),
                                  child: _buildIpInfo(
                                    context,
                                    ipInfo,
                                    pingAsync,
                                    serverFlagCode: serverFlagCode,
                                  ),
                                ),
                              },
                              loading: () => KeyedSubtree(
                                key: const ValueKey('ip-loading'),
                                child: _buildLoadingState(context),
                              ),
                              error: (error, _) => KeyedSubtree(
                                key: const ValueKey('ip-error'),
                                child: _buildErrorState(
                                  context,
                                  resolveUserFacingErrorKey(error),
                                  pingAsync,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Drops the dead tunnel and quick-connects again, explaining a refusal the
  /// way a tap on the dial does.
  Future<void> _switchServer(BuildContext context, WidgetRef ref) async {
    final outcome = await ref.read(mainScreenProvider).switchServer();
    if (!context.mounted || !outcome.needsExplaining) return;
    await showConnectTapExplanation(
      context,
      ref,
      outcome,
      status: ConnectionStatus.ready,
    );
  }

  /// A tunnel that is up but carries no traffic, laid out on the exit
  /// reading's own lines: the warning where the address was, and the two
  /// ways out where the ping was.
  Widget _buildStalledState(BuildContext context, WidgetRef ref) {
    final palette = MainPalette.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _StallMark(),
            SizedBox(width: _IpMetrics.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.tunnelStalledTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.stalled,
                      fontSize: _IpMetrics.country * _stallTitleScale,
                      fontWeight: FontWeight.w700,
                      height: _IpMetrics.lineHeight,
                    ),
                  ),
                  SizedBox(height: _IpMetrics.countryGap),
                  Text(
                    l10n.tunnelStalledHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: _IpMetrics.country,
                      fontWeight: FontWeight.w500,
                      height: _IpMetrics.lineHeight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: _IpMetrics.sectionGap),
        _Divider(),
        SizedBox(height: _IpMetrics.dividerGap),
        Row(
          children: [
            Expanded(
              child: _StallAction(
                label: l10n.tunnelStalledSwitch,
                accent: palette.stalled,
                onTap: () => _switchServer(context, ref),
              ),
            ),
            SizedBox(width: AppLayout.mainStallActionGap.w),
            Expanded(
              child: _StallAction(
                label: l10n.disconnect,
                onTap: () => ref.read(mainScreenProvider).stopConnection(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The stalled card's title, a step above the hint under it.
  static const _stallTitleScale = 1.2;

  Widget _buildIpInfo(
    BuildContext context,
    IpInfo ipInfo,
    AsyncValue<int?> pingAsync, {
    required String? serverFlagCode,
  }) {
    final palette = MainPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _FlagBox(emoji: ipInfo.flagEmoji, serverFlagCode: serverFlagCode),
            SizedBox(width: _IpMetrics.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ipInfo.maskedIp,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: monoFamilyOf(context),
                            color: palette.readingInk,
                            fontSize: _IpMetrics.address,
                            // The mono face is set at the design's medium;
                            // the body face keeps its bold.
                            fontWeight: monoFamilyOf(context) == null
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: _IpMetrics.addressSpacing,
                            height: _IpMetrics.lineHeight,
                          ),
                        ),
                      ),
                      SizedBox(width: _IpMetrics.badgeGap),
                      _IpVersionBadge(ipInfo: ipInfo),
                    ],
                  ),
                  SizedBox(height: _IpMetrics.countryGap),
                  Text(
                    ipInfo.country,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: _IpMetrics.country,
                      fontWeight: FontWeight.w500,
                      height: _IpMetrics.lineHeight,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: _IpMetrics.gap),
            _ConnectedBadge(),
          ],
        ),
        SizedBox(height: _IpMetrics.sectionGap),
        _Divider(),
        SizedBox(height: _IpMetrics.dividerGap),
        _buildPingLine(context, pingAsync),
      ],
    );
  }

  Widget _buildPingLine(BuildContext context, AsyncValue<int?> pingAsync) {
    return pingAsync.when(
      data: (ping) => ping == null
          ? _buildTapToMeasure(context)
          : _buildPingDisplay(context, ping),
      loading: () => _buildPingLoading(context),
      error: (_, _) => _buildPingError(context),
    );
  }

  Widget _buildPingDisplay(BuildContext context, int ping) {
    final quality = PingQuality.forLatency(ping);
    final pingColor = quality.colorIn(MainPalette.of(context));

    return SizedBox(
      height: _PingMetrics.rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LeadingMark(
            child: Icon(
              Iconsax.speedometer_copy,
              color: pingColor,
              size: _PingMetrics.icon,
            ),
          ),
          SizedBox(width: _PingMetrics.gap),
          Expanded(
            child: _OnTheGlyphsLine(
              fontSize: _PingMetrics.value,
              family: monoFamilyOf(context),
              child: Text(
                '${context.l10n.pingMs(ping)} · ${quality.label(context.l10n)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: monoFamilyOf(context),
                  color: pingColor.withValues(alpha: 0.95),
                  fontSize: _PingMetrics.value,
                  fontWeight: FontWeight.w600,
                  height: _PingMetrics.lineHeight,
                ),
              ),
            ),
          ),
          const _RefreshMark(),
        ],
      ),
    );
  }

  Widget _buildTapToMeasure(BuildContext context) {
    final palette = MainPalette.of(context);

    return SizedBox(
      height: _PingMetrics.rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LeadingMark(
            child: Icon(
              Iconsax.speedometer_copy,
              color: palette.textSecondary,
              size: _PingMetrics.icon,
            ),
          ),
          SizedBox(width: _PingMetrics.gap),
          Expanded(
            child: _OnTheGlyphsLine(
              fontSize: _PingMetrics.idleText,
              child: Text(
                context.l10n.tapToTestFor(Theme.of(context).platform),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: _PingMetrics.idleText,
                  fontWeight: FontWeight.w500,
                  height: _PingMetrics.lineHeight,
                ),
              ),
            ),
          ),
          const _RefreshMark(drawn: false),
        ],
      ),
    );
  }

  Widget _buildPingLoading(BuildContext context) {
    final palette = MainPalette.of(context);

    return Shimmer.fromColors(
      baseColor: palette.shimmerBase,
      highlightColor: palette.shimmerHighlight,
      child: const _PingLineShimmer(),
    );
  }

  Widget _buildPingError(BuildContext context) {
    final palette = MainPalette.of(context);

    return SizedBox(
      height: _PingMetrics.rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LeadingMark(
            child: Icon(
              Iconsax.danger_copy,
              color: palette.failed.withValues(
                alpha: _IpMetrics.errorGlyphAlpha,
              ),
              size: _PingMetrics.errorIcon,
            ),
          ),
          SizedBox(width: _PingMetrics.errorGap),
          Expanded(
            child: _OnTheGlyphsLine(
              fontSize: _PingMetrics.errorText,
              child: Text(
                context.l10n.tapToRetryFor(Theme.of(context).platform),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.readingInk.withValues(alpha: 0.6),
                  fontSize: _PingMetrics.errorText,
                  height: _PingMetrics.lineHeight,
                ),
              ),
            ),
          ),
          const _RefreshMark(drawn: false),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final palette = MainPalette.of(context);

    return Shimmer.fromColors(
      baseColor: palette.shimmerBase,
      highlightColor: palette.shimmerHighlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: _IpMetrics.flagBox,
                height: _IpMetrics.flagBox,
                decoration: BoxDecoration(
                  color: palette.readingInk.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(_IpMetrics.flagBoxRadius),
                ),
              ),
              SizedBox(width: _IpMetrics.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _IpMetrics.addressBar.width,
                      height: _IpMetrics.addressBar.height,
                      decoration: BoxDecoration(
                        color: palette.readingInk,
                        borderRadius: BorderRadius.circular(
                          _IpMetrics.barRadius,
                        ),
                      ),
                    ),
                    SizedBox(height: _IpMetrics.textBarGap),
                    Container(
                      width: _IpMetrics.countryBar.width,
                      height: _IpMetrics.countryBar.height,
                      decoration: BoxDecoration(
                        color: palette.readingInk,
                        borderRadius: BorderRadius.circular(
                          _IpMetrics.barRadius,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(_IpMetrics.checkPadding),
                decoration: BoxDecoration(
                  color: palette.readingInk,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: _IpMetrics.checkIcon),
              ),
            ],
          ),
          SizedBox(height: _IpMetrics.sectionGap),
          _Divider(),
          SizedBox(height: _IpMetrics.dividerGap),
          const _PingLineShimmer(),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String errorKey,
    AsyncValue<int?> pingAsync,
  ) {
    final dimmed = MainPalette.of(
      context,
    ).readingInk.withValues(alpha: _IpMetrics.errorInkAlpha);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeadingMark(
              child: Icon(
                Iconsax.info_circle_copy,
                color: dimmed,
                size: _IpMetrics.errorIcon,
              ),
            ),
            SizedBox(width: _IpMetrics.errorGap),
            Expanded(
              child: Text(
                context.l10n.translateError(errorKey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dimmed,
                  fontSize: _IpMetrics.errorText,
                  height: _IpMetrics.lineHeight,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: _IpMetrics.sectionGap),
        _Divider(),
        SizedBox(height: _IpMetrics.dividerGap),
        _buildPingLine(context, pingAsync),
      ],
    );
  }
}

/// The country the tunnel comes out in.
///
/// Where the server row names a server, this is that server's own flag, drawn
/// as the row draws it, so the two cards cannot disagree about one tunnel.
/// Where it names none — the free tier, or a server list never loaded — it is
/// the country the address lookup answered with.
class _FlagBox extends StatelessWidget {
  const _FlagBox({required this.emoji, this.serverFlagCode});

  /// The address lookup's country, as a flag.
  final String emoji;

  /// The named server's flag code, when there is one.
  final String? serverFlagCode;

  @override
  Widget build(BuildContext context) {
    final serverFlagCode = this.serverFlagCode;
    if (serverFlagCode != null) {
      return PremiumServerIcon(
        size: _IpMetrics.flagBox,
        flagCode: serverFlagCode,
      );
    }

    return Container(
      width: _IpMetrics.flagBox,
      height: _IpMetrics.flagBox,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MainPalette.of(context).flagBox,
        borderRadius: BorderRadius.circular(_IpMetrics.flagBoxRadius),
      ),
      child: Text(
        emoji,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'NotoColorEmoji',
          fontSize: _IpMetrics.flagEmoji,
          height: 1,
        ),
      ),
    );
  }
}

/// The stalled card's leading mark: the flag tile's footprint, washed in the
/// warning ink, so the card keeps its shape while it says something else.
class _StallMark extends StatelessWidget {
  const _StallMark();

  @override
  Widget build(BuildContext context) {
    final stalled = MainPalette.of(context).stalled;

    return Container(
      width: _IpMetrics.flagBox,
      height: _IpMetrics.flagBox,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: stalled.withValues(alpha: _IpMetrics.checkFill),
        borderRadius: BorderRadius.circular(_IpMetrics.flagBoxRadius),
      ),
      child: Icon(
        Iconsax.warning_2_copy,
        color: stalled,
        size: AppLayout.mainStallGlyph.sp,
      ),
    );
  }
}

/// One of the stalled card's two ways out.
///
/// Built as every small marker on this screen is — a wash with the rim
/// carrying the edge — at the ping row's height, since the card's box is
/// fixed. With an [accent] it is the action the card leads with; without, the
/// quiet one beside it.
class _StallAction extends StatelessWidget {
  const _StallAction({required this.label, required this.onTap, this.accent});

  final String label;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette = MainPalette.of(context);
    final accent = this.accent;
    final radius = BorderRadius.circular(AppLayout.mainStallActionRadius.r);

    return Material(
      color: accent == null
          ? palette.flagBox
          : accent.withValues(alpha: _IpMetrics.checkFill),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: accent == null
              ? palette.divider
              : accent.withValues(alpha: _IpMetrics.badgeRim),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppLayout.mainStallActionHeight.h,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.mainStallActionPadH.w,
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent ?? palette.textSecondary,
                  fontSize: AppLayout.mainStallActionText.sp,
                  fontWeight: accent == null
                      ? FontWeight.w500
                      : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IpVersionBadge extends StatelessWidget {
  const _IpVersionBadge({required this.ipInfo});

  final IpInfo ipInfo;

  @override
  Widget build(BuildContext context) {
    // One colour for both versions, where this used to be blue for v4 and
    // purple for v6. The purple was the only one in the app and it was the
    // only thing it distinguished — the chip says "IPv4" or "IPv6" in words,
    // which is the part a reader uses. Colour here was carrying no meaning
    // that the label was not already carrying better.
    final palette = MainPalette.of(context);

    return Container(
      padding: _IpMetrics.badgePadding,
      decoration: BoxDecoration(
        color: palette.connected.withValues(alpha: _IpMetrics.badgeFill),
        borderRadius: BorderRadius.circular(_IpMetrics.badgeRadius),
        border: Border.all(
          color: palette.connected.withValues(alpha: _IpMetrics.badgeRim),
        ),
      ),
      child: Text(
        ipInfo.ipVersion,
        style: TextStyle(
          color: palette.connected,
          fontFamily: monoFamilyOf(context),
          fontSize: _IpMetrics.badgeText,
          fontWeight: FontWeight.w700,
          height: _IpMetrics.lineHeight,
        ),
      ),
    );
  }
}

class _ConnectedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final verified = MainPalette.of(context).verified;

    return Container(
      padding: EdgeInsets.all(_IpMetrics.checkPadding),
      decoration: BoxDecoration(
        color: verified.withValues(alpha: _IpMetrics.checkFill),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Iconsax.tick_circle_copy,
        color: verified,
        size: _IpMetrics.checkIcon,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: MainPalette.of(context).divider);
  }
}

/// Shimmer placeholders for the speed icon and the reading beside it — same
/// row footprint as [_buildPingDisplay], not one bar across the full width.
class _PingLineShimmer extends StatelessWidget {
  const _PingLineShimmer();

  @override
  Widget build(BuildContext context) {
    final bar = MainPalette.of(context).readingInk;

    return SizedBox(
      height: _PingMetrics.rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LeadingMark(
            child: Container(
              width: _PingMetrics.icon,
              height: _PingMetrics.icon,
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(_PingMetrics.iconRadius),
              ),
            ),
          ),
          SizedBox(width: _PingMetrics.gap),
          Container(
            width: _IpMetrics.pingTextBar.width,
            height: _IpMetrics.pingTextBar.height,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(_PingMetrics.barRadius),
            ),
          ),
          const Spacer(),
          const _RefreshMark(drawn: false),
        ],
      ),
    );
  }
}

/// A line of text dropped onto the centre line of the glyph beside it.
///
/// A [Row] centres the em box a font declares, and that is not where the
/// letters are — see [kOpticalTextDrop], which is the whole of the
/// correction. Applied to the text rather than the glyph on purpose: an
/// Iconsax glyph is already centred in its box, so nudging one would only
/// move a mark that is right to meet one that is wrong, and any glyph drawn
/// inside a shape — the connected tick in its disc — would come off centre
/// to pay for it.
class _OnTheGlyphsLine extends StatelessWidget {
  const _OnTheGlyphsLine({
    required this.fontSize,
    required this.child,
    this.family,
  });

  /// The size the text is set at. The drop is a fraction of it, so the three
  /// readings this row can show all land level at their three sizes.
  final double fontSize;

  /// The face the text is set in, when it is not the one it inherits. The
  /// drop is the face's own: Geist needs none.
  final String? family;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(
        0,
        fontSize *
            opticalTextDropFor(
              family ?? DefaultTextStyle.of(context).style.fontFamily,
            ),
      ),
      child: child,
    );
  }
}

/// A mark in the panel's leading column.
///
/// Sized to [AppLayout.mainIpLeadingGutter] rather than to the glyph inside
/// it, so every row hangs off the same gutter: the marks share a centre line
/// and every line of text starts under the one above it.
class _LeadingMark extends StatelessWidget {
  const _LeadingMark({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _IpMetrics.leadingGutter,
      child: Center(child: child),
    );
  }
}

/// The mark at the trailing end of the ping row.
///
/// Sized to the connected tick in the row above rather than to its own glyph,
/// so the two things in that column share a centre line. The three ping
/// states that have nothing to offer keep the slot and leave it empty, so the
/// reading beside it does not shift as the row changes state.
class _RefreshMark extends StatelessWidget {
  const _RefreshMark({this.drawn = true});

  final bool drawn;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _PingMetrics.refreshSlot,
      child: drawn
          ? Center(
              child: Icon(
                Iconsax.refresh_copy,
                color: MainPalette.of(context).textTertiary,
                size: _PingMetrics.refreshIcon,
              ),
            )
          : null,
    );
  }
}

extension on PingQuality {
  String label(AppLocalizations l10n) => switch (this) {
    PingQuality.excellent => l10n.pingExcellent,
    PingQuality.good => l10n.pingGood,
    PingQuality.fair => l10n.pingFair,
    PingQuality.poor => l10n.pingPoor,
  };
}
