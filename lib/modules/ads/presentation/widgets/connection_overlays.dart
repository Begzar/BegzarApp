import 'dart:async';

import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/modules/ads/presentation/ads_palette.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/modules/ads/di/ads_providers.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/modules/ads/presentation/controllers/ad_skip_warning_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_gate_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/post_connect_ad_notifier.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_purchase_launcher.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/purchase_destination_mark.dart';
import 'package:begzar/core/widgets/ink_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:begzar/core/services/native_url_launcher.dart';
import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// Renders post-connect ad and ad-skip warning as overlays (no Navigator routes).
class ConnectionOverlays extends ConsumerWidget {
  const ConnectionOverlays({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adState = ref.watch(postConnectAdProvider);
    final showWarning = ref.watch(adSkipWarningVisibleProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (adState != null)
          Positioned.fill(
            child: adState.isLoading
                ? const _PostConnectAdLoadingLayer()
                : _PostConnectAdLayer(
                    ad: adState.ad!,
                    enforceWait: adState.enforceWait,
                  ),
          ),
        if (showWarning) const Positioned.fill(child: _AdSkipWarningLayer()),
      ],
    );
  }
}

class _PostConnectAdLoadingLayer extends StatelessWidget {
  const _PostConnectAdLoadingLayer();

  @override
  Widget build(BuildContext context) {
    final palette = AdsPalette.of(context);

    return Material(
      color: palette.overlay,
      child: SafeArea(
        child: Shimmer.fromColors(
          baseColor: palette.shimmerBase,
          highlightColor: palette.shimmerHighlight,
          child: Column(
            children: [
              // Stands in for the gate row, at the size the gate row will be,
              // so the shell does not promise a layout the ad then changes.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.adGatePadH.w,
                  AppLayout.adGatePadTop.h,
                  AppLayout.adGatePadH.w,
                  AppLayout.adGatePadBottom.h,
                ),
                child: _ShimmerBox(
                  width: double.infinity,
                  height: AppLayout.adGateHeight.w,
                  radius: (AppLayout.adGateHeight / 2).r,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.adContentPadH.w,
                    vertical: AppLayout.gap8.h,
                  ),
                  child: _ShimmerBox(
                    width: double.infinity,
                    height: double.infinity,
                    radius: AppLayout.adBannerRadius.r,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.adBottomPad.w,
                  AppLayout.gap16.h,
                  AppLayout.adBottomPad.w,
                  AppLayout.adBottomPad.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ShimmerBox(
                        width: AppLayout.adSkeletonTitleWidth.w,
                        height: AppLayout.adSkeletonTitleHeight.h,
                        radius: AppLayout.adSkeletonRadius.r,
                      ),
                    ),
                    SizedBox(height: AppLayout.adSkeletonTitleGap.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ShimmerBox(
                        width: AppLayout.adSkeletonBodyWidth.w,
                        height: AppLayout.adSkeletonLineHeight.h,
                        radius: AppLayout.adSkeletonRadius.r,
                      ),
                    ),
                    SizedBox(height: AppLayout.adSkeletonLineGap.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ShimmerBox(
                        width: AppLayout.adSkeletonTailWidth.w,
                        height: AppLayout.adSkeletonLineHeight.h,
                        radius: AppLayout.adSkeletonRadius.r,
                      ),
                    ),
                    SizedBox(height: AppLayout.adBodyGap.h),
                    _ShimmerBox(
                      width: double.infinity,
                      height: AppLayout.gap48.h,
                      radius: AppLayout.radiusXl.r,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.veil,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _PostConnectAdLayer extends ConsumerStatefulWidget {
  const _PostConnectAdLayer({required this.ad, required this.enforceWait});

  final Advertisement ad;
  final bool enforceWait;

  @override
  ConsumerState<_PostConnectAdLayer> createState() =>
      _PostConnectAdLayerState();
}

class _PostConnectAdLayerState extends ConsumerState<_PostConnectAdLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _unlockController = AnimationController(
    vsync: this,
    duration: AdsPalette.unlockPulse,
  );

  /// Out and back, rather than a settle onto a new size: the knob is the same
  /// size before and after, and the beat is what marks the moment it opens.
  late final Animation<double> _unlockScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: AdsPalette.unlockPeak,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: AdsPalette.unlockPeak,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 55,
    ),
  ]).animate(_unlockController);

  @override
  void dispose() {
    _unlockController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    final color = hex.length == 6 ? 'FF$hex' : hex;
    return Color(int.parse(color, radix: 16));
  }

  void _close() {
    ref.read(postConnectAdProvider.notifier).dismiss();
  }

  /// The palette the layer's helpers draw in, read from the theme it sits in.
  AdsPalette get palette => AdsPalette.of(context);

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(connectionAdGateProvider);

    ref.listen(connectionAdGateProvider, (previous, next) {
      if (next.forceClosed) {
        ref.read(postConnectAdProvider.notifier).dismiss();
      }
      // The one moment on this screen the reader is waiting for.
      if (!(previous?.canClose ?? false) && next.canClose) {
        _unlockController.forward(from: 0);
      }
    });

    final canClose = !widget.enforceWait || gate.canClose;

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: kAdPopupFontFamily),
      child: Material(
        color: palette.overlay,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.1),
              radius: 1.1,
              colors: palette.glow,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildGateRow(canClose, gate.remainingSeconds),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      vertical: AppLayout.adCloseRowPadV.h,
                    ),
                    child: _buildBannerImage(),
                  ),
                ),
                _buildBottomContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The ADS badge, the wait and the close control, as one capsule.
  ///
  /// The rail between the badge and the knob is the wait: it fills towards the
  /// control it is holding shut, and arriving is what opens it. Stating it as a
  /// distance rather than a sentence is what lets the row say the same thing in
  /// every locale at the same size.
  Widget _buildGateRow(bool canClose, int remainingSeconds) {
    final gateInner = AppLayout.adGateHeight - AppLayout.adGatePadding * 2;
    final gateInnerRadius = gateInner / 2;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.gap12.w,
        AppLayout.gap10.h,
        AppLayout.gap12.w,
        AppLayout.gap6.h,
      ),
      child: AppGlassPanel(
        style: AppGlass.panel(
          context.palette,
          cornerRadius: AppLayout.adGateHeight / 2,
          color: palette.capsuleHigh,
        ),
        child: SizedBox(
          height: AppLayout.adGateHeight.w,
          child: Padding(
            padding: EdgeInsets.all(AppLayout.adGatePadding.w),
            child: Row(
              children: [
                _buildAdBadge(canClose, gateInner, gateInnerRadius),
                Expanded(child: _buildWaitRail(canClose, remainingSeconds)),
                _buildCloseKnob(canClose, remainingSeconds, gateInner),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdBadge(
    bool canClose,
    double gateInner,
    double gateInnerRadius,
  ) {
    return AnimatedContainer(
      duration: AdsPalette.settle,
      height: gateInner.w,
      padding: EdgeInsets.symmetric(horizontal: AppLayout.adGateBadgePadding.w),
      decoration: BoxDecoration(
        color: canClose ? palette.badgeSpent : palette.badge,
        borderRadius: BorderRadius.circular(gateInnerRadius.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.star_1_copy,
            color: palette.badgeGlyph,
            size: AppLayout.adGateBadgeGlyph.sp,
          ),
          SizedBox(width: AppLayout.adGateBadgeGap.w),
          // No tracking, in any locale: the label is set in Estedad on a
          // Persian screen, and letter-spacing pulls a joined script apart.
          Text(
            context.l10n.adBadge,
            style: TextStyle(
              color: palette.badgeLabel,
              fontSize: AppLayout.adGateBadgeLabel.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitRail(bool canClose, int remainingSeconds) {
    final total = widget.ad.duration;
    final crossed = canClose || total <= 0
        ? 1.0
        : ((total - remainingSeconds) / total).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppLayout.adGateRailGap.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.adGateRailRadius.r),
        child: ColoredBox(
          color: palette.railTrack,
          child: SizedBox(
            height: AppLayout.adGateRailHeight.h,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: crossed),
              // An ad that enforces no wait opens closed, so there is no
              // distance for the rail to cross and nothing to animate.
              duration: widget.enforceWait
                  ? AdsPalette.railSweep
                  : Duration.zero,
              curve: Curves.linear,
              builder: (context, crossedSoFar, child) => FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: crossedSoFar,
                child: child,
              ),
              child: AnimatedContainer(
                duration: AdsPalette.settle,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    AppLayout.adGateRailRadius.r,
                  ),
                  gradient: LinearGradient(
                    colors: canClose ? palette.railSpent : palette.railRunning,
                    stops: AdsPalette.railStops,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseKnob(
    bool canClose,
    int remainingSeconds,
    double gateInner,
  ) {
    final l10n = context.l10n;

    return Semantics(
      button: canClose,
      // The sentence the wait banner used to carry. A reader who cannot see the
      // rail is the one reader who still needs it in words.
      label: canClose ? l10n.close : l10n.adCloseCountdown(remainingSeconds),
      child: ScaleTransition(
        scale: _unlockScale,
        child: InkWell(
          onTap: canClose ? _close : null,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: AdsPalette.settle,
            width: gateInner.w,
            height: gateInner.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: canClose ? palette.knobUnlocked : AdsPalette.knobLocked,
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: AdsPalette.swap,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: AdsPalette.swapScale,
                    end: 1,
                  ).animate(animation),
                  child: child,
                ),
              ),
              // Both children keep a constant key, so the digits change in
              // place every second and only the last one animates away.
              child: canClose
                  ? Icon(
                      Iconsax.close_circle_copy,
                      key: const ValueKey('close'),
                      color: palette.knobGlyph,
                      size: AppLayout.adGateKnobGlyph.sp,
                    )
                  : Text(
                      l10n.adCloseSeconds(remainingSeconds),
                      key: const ValueKey('remaining'),
                      style: TextStyle(
                        color: palette.knobDigits,
                        fontSize: AppLayout.adGateKnobDigits.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// A load can fail after the overlay closed, when nobody saw the stand-in.
  void _recordBannerFailed(Object _) {
    if (!mounted) return;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logPromotionBannerFailed(
            promotionId: widget.ad.id,
            promotionName: widget.ad.title,
          ),
    );
  }

  Widget _buildBannerImage() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppLayout.adContentPadH.w),
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppLayout.adBannerRadius.r),
          border: Border.all(color: palette.bannerRim),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppLayout.adBannerRadius.r),
          child: CachedNetworkImage(
            imageUrl: widget.ad.bannerUrl,
            cacheManager: ref.read(adBannerCacheProvider),
            width: double.infinity,
            fit: BoxFit.fitWidth,
            // A prewarmed banner is already decoded; fading it in would read as
            // loading a picture that is in fact ready.
            fadeInDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            // Once per failed load, not per build: the countdown rebuilds this
            // every second, and so would anything recorded from errorWidget.
            errorListener: _recordBannerFailed,
            placeholder: (_, _) => _buildBannerStandIn(
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(palette.spinner),
                ),
              ),
            ),
            errorWidget: (_, _, _) => _buildBannerStandIn(
              Icon(
                Iconsax.gallery_slash_copy,
                color: palette.bannerBroken,
                size: AppLayout.adBrokenGlyph.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerStandIn(Widget child) {
    return SizedBox(
      height: AppLayout.adBannerStandInHeight.h,
      child: ColoredBox(color: palette.bannerStandIn, child: child),
    );
  }

  Widget _buildBottomContent() {
    final action = _hexToColor(widget.ad.buttonColor);
    // The ad's own colour, lit the way every other filled button now is,
    // with whichever ink reads on it.
    final actionInk = AppPalette.labelOn(action);
    final actionRadius = BorderRadius.circular(AppLayout.adActionRadius.r);
    // The card reads in the ad's own script rather than the app's: a version
    // picked for the user's language can still differ from the app's locale.
    final readsRightToLeft = widget.ad.readsRightToLeft;
    final family = readsRightToLeft
        ? kAdPopupFontFamily
        : appFontFamilyFor(Localizations.localeOf(context));

    return Directionality(
      textDirection: readsRightToLeft ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppLayout.adCardMargin.w,
          AppLayout.gap12.h,
          AppLayout.adCardMargin.w,
          AppLayout.adCardMargin.h,
        ),
        child: Container(
          padding: EdgeInsets.all(AppLayout.adCardPad.w),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppLayout.adCardRadius.r),
            border: Border.all(color: palette.cardRim),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.ad.title,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: family,
                  fontSize: AppLayout.text5xl.sp,
                  fontWeight: FontWeight.w600,
                  color: palette.title,
                ),
              ),
              SizedBox(height: AppLayout.adTitleGap.h),
              Text(
                widget.ad.description,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: family,
                  fontSize: AppLayout.textXl.sp,
                  color: palette.description,
                  height: 1.5,
                ),
              ),
              SizedBox(height: AppLayout.adBodyGap.h),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: actionRadius,
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      Color.lerp(
                        action,
                        AppPalette.lift,
                        AppLayout.adActionLift,
                      )!,
                      action,
                    ],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () => _handleAdClick(widget.ad),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    foregroundColor: actionInk,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: AppLayout.adActionPadV.h,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: actionRadius),
                  ),
                  child: Text(
                    widget.ad.action,
                    style: TextStyle(
                      fontFamily: family,
                      fontSize: AppLayout.text3xl.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAdClick(Advertisement ad) async {
    // Read before the launch: the overlay can be gone by the time it returns.
    final analytics = ref.read(analyticsServiceProvider);
    final gate = ref.read(connectionAdGateProvider);
    final canClose = !widget.enforceWait || gate.canClose;
    if (!canClose) {
      // Mark before launchUrl — the app may pause before this future returns.
      ref.read(connectionAdGateProvider.notifier).markOpenedAdClick();
    }

    final launched = await NativeUrlLauncher.open(ad.clickUrl);
    unawaited(
      analytics.logPromotionSelected(
        promotionId: ad.id,
        promotionName: ad.title,
        duringWait: !canClose,
        opened: launched,
      ),
    );
    if (!mounted) return;
    if (launched) {
      if (canClose) _close();
      return;
    }
    if (!canClose) {
      ref.read(connectionAdGateProvider.notifier).clearOpenedAdClick();
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.linkOpenFailed)));
  }
}

class _AdSkipWarningLayer extends ConsumerWidget {
  const _AdSkipWarningLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Material(
      color: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.coreDialogInsetH.w,
          ),
          child: AppGlassPanel(
            style: AppGlass.dialog(
              context.palette,
              cornerRadius: AppLayout.coreDialogRadius.r,
            ),
            child: Padding(
              padding: EdgeInsets.all(AppLayout.inkDialogPad.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: InkDialogEmblem(
                      icon: Iconsax.warning_2,
                      color: AdsPalette.of(context).warningGlyph,
                    ),
                  ),
                  SizedBox(height: AppLayout.inkDialogEmblemGap.h),
                  InkDialogText(
                    title: l10n.adSkipWarningTitle,
                    message: l10n.adSkipWarningMessage,
                  ),
                  SizedBox(height: AppLayout.inkDialogActionsGap.h),
                  InkDialogActions(
                    cancelLabel: l10n.cancel,
                    onCancel: () =>
                        ref.read(adSkipWarningVisibleProvider.notifier).hide(),
                    // The colour every other offer of premium is made in.
                    action: InkFilledButton(
                      label: l10n.buyPremium,
                      color: PremiumPalette.of(context).offerBuy,
                      leading: PurchaseDestinationMark(
                        size: AppLayout.inkButtonGlyph.sp,
                      ),
                      onPressed: () async {
                        // Read before hiding: hiding takes this layer, and the
                        // ref it would be read through, off screen.
                        final purchase = ref.read(
                          premiumPurchaseLauncherProvider,
                        );
                        ref.read(adSkipWarningVisibleProvider.notifier).hide();
                        await purchase.open();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
