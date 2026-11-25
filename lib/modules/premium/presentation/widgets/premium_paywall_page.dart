import 'dart:math' as math;

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/domain/surface_mood.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/support/support_contact.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_buttons.dart';
import 'package:begzar/core/widgets/directional_glyph.dart';
import 'package:begzar/core/widgets/plan_badge.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_paywall_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_paywall_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_buttons.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_error_banner.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_paywall_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' show BidiFormatter, Intl, NumberFormat;

/// The frosted square a picture or a glyph sits in, lit from the top-left
/// corner, as the home screen and the premium list draw theirs.
BoxDecoration _iconBox(PremiumPalette palette) => BoxDecoration(
  borderRadius: BorderRadius.circular(AppLayout.radiusLg.r),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [palette.iconBoxHigh, palette.iconBoxLow],
  ),
);

Color _accentTint(PremiumPalette palette) =>
    palette.paywallAccent.withValues(alpha: PremiumPalette.paywallTintAlpha);

/// [price] marked to read left to right inside a sentence that may not, so
/// Persian keeps "$19.20" whole instead of turning it into "19.20$".
String _inLine(BuildContext context, String price) =>
    Directionality.of(context) == TextDirection.rtl
    ? BidiFormatter.RTL().wrapWithUnicode(price)
    : price;

/// A small rounded label: what a plan saves, or that it is the best value.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.premiumPaywallChipPadH.w,
        vertical: AppLayout.premiumPaywallChipPadV.h,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppLayout.radiusPill.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: AppLayout.textMd.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The page's top edge: the way out, and Basic leading to Premium in the
/// badges the app bar shows the plan with.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final control = AppLayout.premiumPaywallControl.w;
    final badgeGap = SizedBox(width: AppLayout.premiumPaywallBadgeGap.w);

    return SizedBox(
      height: AppLayout.premiumPaywallTopBar.h,
      child: Row(
        children: [
          // The close knob the post-connect ad and the error toast use.
          IconButton(
            onPressed: onClose,
            tooltip: context.l10n.close,
            icon: Icon(
              Iconsax.close_circle_copy,
              size: AppLayout.premiumPaywallCloseGlyph.sp,
            ),
            color: palette.textSecondary,
            style: IconButton.styleFrom(
              fixedSize: Size.square(control),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PlanBadge(isPremium: false),
                badgeGap,
                Icon(
                  DirectionalGlyph.chevron(context),
                  color: palette.textSecondary,
                  size: AppLayout.premiumPaywallControlGlyph.sp,
                ),
                badgeGap,
                const PlanBadge(isPremium: true),
              ],
            ),
          ),
          // Balances the close button, so the badges sit in the middle.
          SizedBox(width: control),
        ],
      ),
    );
  }
}

/// A table column as wide as the longest word in it, so its cells may wrap
/// between words but never inside one, however large the reader's text is.
class _LongestWordWidth extends TableColumnWidth {
  const _LongestWordWidth();

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      cells.fold(
        0,
        (widest, cell) =>
            math.max(widest, cell.getMinIntrinsicWidth(double.infinity)),
      );

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      minIntrinsicWidth(cells, containerWidth);
}

/// One row of the comparison: what it is about, then what Basic and Premium
/// each do about it.
typedef _Feature = ({
  PaywallArt art,
  String label,
  Widget basic,
  Widget premium,
});

/// Basic against Premium, a row per thing Premium changes, Premium's column
/// tinted in the page's accent.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.mostDevices});

  /// The most devices Play sells a plan for, once it has said; the devices
  /// row waits for it.
  final int? mostDevices;

  TextStyle _basicStyle(PremiumPalette palette) =>
      TextStyle(color: palette.textSecondary, fontSize: AppLayout.textLg.sp);

  TextStyle _premiumStyle(PremiumPalette palette) => TextStyle(
    color: palette.paywallAccent,
    fontSize: AppLayout.textLg.sp,
    fontWeight: FontWeight.w600,
  );

  /// Every cell counts towards its row's height, and Basic's and Premium's
  /// stretch to it, so Premium's tint runs down the table unbroken and a value
  /// that wraps onto two lines is never cut off.
  Widget _cell(
    PremiumPalette palette,
    Widget child, {
    bool premium = false,
    bool start = false,
  }) {
    return TableCell(
      verticalAlignment: start
          ? TableCellVerticalAlignment.middle
          : TableCellVerticalAlignment.intrinsicHeight,
      child: Container(
        color: premium ? _accentTint(palette) : null,
        alignment: start ? AlignmentDirectional.centerStart : Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.premiumPaywallCellPadH.w,
          vertical: AppLayout.premiumPaywallCellPadV.h,
        ),
        child: child,
      ),
    );
  }

  /// What Basic or Premium does, centred in its column even when it wraps
  /// onto a second line.
  Widget _value(String text, TextStyle style) =>
      Text(text, style: style, textAlign: TextAlign.center);

  /// A tick or a dash that says it in words to a screen reader.
  Widget _mark(IconData icon, Color color, String meaning) {
    return Semantics(
      label: meaning,
      excludeSemantics: true,
      child: Icon(icon, color: color, size: AppLayout.premiumPaywallTick.sp),
    );
  }

  List<_Feature> _features(PremiumPalette palette, AppLocalizations l10n) {
    final mostDevices = this.mostDevices;
    return [
      (
        art: PaywallArt.adWait,
        label: l10n.paywallRowAds,
        basic: _value(l10n.paywallBasicAds, _basicStyle(palette)),
        premium: _value(l10n.paywallPremiumAds, _premiumStyle(palette)),
      ),
      (
        art: PaywallArt.countries,
        label: l10n.paywallRowCountry,
        basic: _value(l10n.paywallBasicCountry, _basicStyle(palette)),
        premium: _mark(
          Iconsax.tick_circle_copy,
          palette.paywallAccent,
          l10n.paywallIncluded,
        ),
      ),
      (
        art: PaywallArt.speed,
        label: l10n.paywallRowServers,
        basic: _value(l10n.paywallBasicServers, _basicStyle(palette)),
        premium: _value(l10n.paywallPremiumServers, _premiumStyle(palette)),
      ),
      if (mostDevices != null)
        (
          art: PaywallArt.devices,
          label: l10n.paywallRowDevices,
          basic: _mark(
            Iconsax.minus_copy,
            palette.textMuted,
            l10n.paywallNotIncluded,
          ),
          premium: _value(
            l10n.paywallPremiumDevices(mostDevices),
            _premiumStyle(palette),
          ),
        ),
    ];
  }

  TableRow _row(
    PremiumPalette palette,
    AppLocalizations l10n,
    _Feature feature,
  ) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      children: [
        _cell(
          palette,
          Row(
            children: [
              Container(
                width: AppLayout.premiumPaywallArtTile.w,
                height: AppLayout.premiumPaywallArtTile.w,
                alignment: Alignment.center,
                decoration: _iconBox(palette),
                child: PremiumPaywallArt(
                  art: feature.art,
                  size: AppLayout.premiumPaywallArt.w,
                  adLabel: l10n.adBadge,
                ),
              ),
              SizedBox(width: AppLayout.premiumPaywallArtGap.w),
              Flexible(
                child: Text(
                  feature.label,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: AppLayout.textLg.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          start: true,
        ),
        _cell(palette, feature.basic),
        _cell(palette, feature.premium, premium: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    final heading = TextStyle(
      fontSize: AppLayout.textLg.sp,
      fontWeight: FontWeight.w700,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.cardInset,
        borderRadius: BorderRadius.circular(
          AppLayout.premiumPaywallCardRadius.r,
        ),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Table(
        // Basic's and Premium's columns are as wide as their values on one
        // line, up to a share of the table, and never narrower than their
        // longest word: "Full speed" stays on one line, and a longer value
        // or larger text wraps between words rather than inside one.
        columnWidths: {
          for (final column in const [1, 2])
            column: MaxColumnWidth(
              const _LongestWordWidth(),
              MinColumnWidth(
                const IntrinsicColumnWidth(),
                const FractionColumnWidth(
                  AppLayout.premiumPaywallValueColumnShare,
                ),
              ),
            ),
        },
        children: [
          TableRow(
            children: [
              _cell(
                palette,
                Text(
                  l10n.paywallCompareHeading,
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontSize: AppLayout.textBase.sp,
                  ),
                ),
                start: true,
              ),
              _cell(
                palette,
                Text(
                  l10n.planBasic,
                  style: heading.copyWith(color: palette.paywallBasic),
                ),
              ),
              _cell(
                palette,
                Text(
                  l10n.planPremium,
                  style: heading.copyWith(color: palette.paywallAccent),
                ),
                premium: true,
              ),
            ],
          ),
          for (final feature in _features(palette, l10n))
            _row(palette, l10n, feature),
        ],
      ),
    );
  }
}

/// One billing period, a card in a two-column grid: what it costs in all and a
/// month, what it saves, and whether it is the best value, ringed in the
/// page's accent when selected. A grid rather than a list, so the whole page
/// fits a phone without scrolling.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.offer,
    required this.periods,
    required this.isSelected,
    required this.isBestValue,
    required this.onTap,
  });

  final PremiumPlanOffer offer;

  /// Every period offered for the same device count, to say what this one
  /// saves against the monthly plan.
  final List<PremiumPlanOffer> periods;
  final bool isSelected;
  final bool isBestValue;
  final VoidCallback? onTap;

  /// Play states amounts in millionths of the currency's unit.
  static const _microsPerUnit = 1000000;

  /// The number format used when the device's language has none of its own.
  static const _fallbackLocale = 'en';

  /// What a month of [offer] costs, in Play's currency, formatted the way
  /// Play formats the total beside it: in the device's language rather than
  /// the app's, so the two prices in a row use the same digits. Play's own
  /// string is still what the total reads.
  String _perMonth(BuildContext context) {
    final locale = Intl.verifiedLocale(
      WidgetsBinding.instance.platformDispatcher.locale.toString(),
      NumberFormat.localeExists,
      onFailure: (_) => _fallbackLocale,
    );
    final format = NumberFormat.simpleCurrency(
      locale: locale,
      name: offer.currencyCode,
    );
    return _inLine(
      context,
      format.format(offer.perMonthMicros / _microsPerUnit),
    );
  }

  Widget _radio(PremiumPalette palette) {
    final size = AppLayout.premiumPaywallRadio.sp;
    if (isSelected) {
      return Icon(
        Iconsax.tick_circle_copy,
        color: palette.paywallAccent,
        size: size,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: palette.textMuted,
          width: AppLayout.premiumPaywallRowRing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    final saving = savingsPercent(offer, periods);

    final lineGap = SizedBox(height: AppLayout.premiumPaywallCardLineGap.h);

    final card = AnimatedContainer(
      duration: PremiumPalette.stateChange,
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.premiumPaywallRowPadH.w,
        vertical: AppLayout.premiumPaywallRowPadV.h,
      ),
      decoration: BoxDecoration(
        color: isSelected ? _accentTint(palette) : palette.cardInset,
        borderRadius: BorderRadius.circular(
          AppLayout.premiumPaywallRowRadius.r,
        ),
        border: Border.all(
          color: isSelected ? palette.paywallAccent : palette.borderSoft,
          width: AppLayout.premiumPaywallRowRing,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.paywallMonths(offer.months),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: AppLayout.text2xl.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _radio(palette),
            ],
          ),
          lineGap,
          Text(
            offer.price,
            style: TextStyle(
              color: isSelected ? palette.paywallAccent : palette.textPrimary,
              fontSize: AppLayout.text4xl.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          lineGap,
          // The device count is the stepper's, just above the cards, so a
          // card says only what a month costs and stays one line tall.
          Text(
            l10n.paywallPerMonth(_perMonth(context)),
            style: TextStyle(
              color: palette.textTertiary,
              fontSize: AppLayout.textBase.sp,
            ),
          ),
          if (saving != null) ...[
            lineGap,
            _Chip(
              label: l10n.paywallSave(saving),
              background: palette.paywallAccent.withValues(
                alpha: PremiumPalette.paywallChipAlpha,
              ),
              foreground: palette.paywallAccent,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      selected: isSelected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Fills its grid cell, so both cards in a row are as tall as the
        // taller of them.
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            card,
            if (isBestValue)
              PositionedDirectional(
                top: -AppLayout.premiumPaywallBestValueRise.h,
                start: AppLayout.premiumPaywallRowPadH.w,
                child: _Chip(
                  label: l10n.paywallBestValue,
                  background: palette.paywallBestValue,
                  foreground: AppPalette.labelOn(palette.paywallBestValue),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The device count and its periods as one card: the stepper is the card's
/// top section and the periods sit under it, priced for that count, so a
/// change to one reads as a change to the plan.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.state,
    required this.onDevices,
    required this.onMonths,
  });

  final PremiumPaywallState state;

  /// Null while a purchase is under way, which locks the choice.
  final ValueChanged<int>? onDevices;
  final ValueChanged<int>? onMonths;

  /// The count a step takes the stepper to: the next one sold, or null at
  /// either end. Counts Play does not sell are stepped over.
  int? _step(int by) {
    final counts = state.offers.keys.toList();
    final next = counts.indexOf(state.devices) + by;
    return next >= 0 && next < counts.length ? counts[next] : null;
  }

  VoidCallback? _onStep(int by) {
    final onDevices = this.onDevices;
    final target = _step(by);
    if (onDevices == null || target == null) return null;
    return () => onDevices(target);
  }

  /// Both stepper buttons are outlined; [ink] colours the glyph and [rim] the
  /// outline, so adding a device reads in the page's accent and taking one
  /// away in white.
  ButtonStyle _stepperStyle({required Color ink, required Color rim}) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        AppLayout.premiumPaywallStepperRadius.r,
      ),
    );
    return IconButton.styleFrom(
      fixedSize: Size.square(AppLayout.premiumPaywallControl.w),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: shape,
      foregroundColor: ink,
      disabledForegroundColor: ink.withValues(
        alpha: PremiumPalette.disabledAlpha,
      ),
      side: BorderSide(color: rim),
    );
  }

  Widget _stepper(BuildContext context) {
    final l10n = context.l10n;
    final palette = PremiumPalette.of(context);
    final digits = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    final glyph = AppLayout.premiumPaywallControlGlyph.sp;
    final gap = SizedBox(width: AppLayout.premiumPaywallStepperGap.w);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _onStep(-1),
          tooltip: l10n.paywallFewerDevices,
          icon: Icon(Iconsax.minus_copy, size: glyph),
          style: _stepperStyle(ink: palette.textPrimary, rim: palette.border),
        ),
        gap,
        SizedBox(
          width: AppLayout.premiumPaywallCount.w,
          child: Text(
            digits.format(state.devices),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: AppLayout.text5xl.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        gap,
        IconButton(
          onPressed: _onStep(1),
          tooltip: l10n.paywallMoreDevices,
          icon: Icon(Iconsax.add_copy, size: glyph),
          style: _stepperStyle(
            ink: palette.paywallAccent,
            rim: palette.paywallAccent,
          ),
        ),
      ],
    );
  }

  Widget _devices(BuildContext context) {
    final l10n = context.l10n;
    final palette = PremiumPalette.of(context);
    final tile = AppLayout.premiumPaywallArtTile.w;

    return Container(
      color: palette.cardInset,
      padding: EdgeInsets.all(AppLayout.premiumPaywallDevicesPad.w),
      child: Row(
        children: [
          // The comparison's devices picture, drawn with as many devices as
          // the count beside it, so it grows as the stepper is pressed.
          Container(
            width: tile,
            height: tile,
            alignment: Alignment.center,
            decoration: _iconBox(palette),
            child: PremiumPaywallArt(
              art: PaywallArt.devices,
              size: AppLayout.premiumPaywallArt.w,
              deviceCount: state.devices,
            ),
          ),
          SizedBox(width: AppLayout.premiumNoticeGap.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.paywallDevices(state.devices),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: AppLayout.text3xl.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l10n.paywallDevicesHint,
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontSize: AppLayout.textBase.sp,
                  ),
                ),
              ],
            ),
          ),
          _stepper(context),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final periods = state.periods;
    final best = bestValue(periods);
    final onMonths = this.onMonths;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(
          AppLayout.premiumPaywallCardRadius.r,
        ),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          _devices(context),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.divider)),
            ),
            padding: EdgeInsets.all(AppLayout.premiumPaywallPeriodsPad.w),
            child: Column(
              children: [
                for (var first = 0; first < periods.length; first += 2) ...[
                  if (first > 0)
                    SizedBox(height: AppLayout.premiumPaywallRowGap.h),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (column, offer) in [
                          periods[first],
                          ?periods.elementAtOrNull(first + 1),
                        ].indexed) ...[
                          if (column > 0)
                            SizedBox(width: AppLayout.premiumPaywallRowGap.w),
                          Expanded(
                            child: _PeriodCard(
                              offer: offer,
                              periods: periods,
                              isSelected: offer.months == state.months,
                              isBestValue: offer == best,
                              onTap: onMonths == null
                                  ? null
                                  : () => onMonths(offer.months),
                            ),
                          ),
                        ],
                        // A last period alone keeps a card's width, not the
                        // row's.
                        if (first + 1 >= periods.length) ...[
                          SizedBox(width: AppLayout.premiumPaywallRowGap.w),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar pinned to the foot of the page, so the price and the way to pay it
/// stay in reach however far the page is scrolled: the button that names what
/// the chosen plan costs, the renewal terms and where to get help.
class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.state,
    required this.onSubscribe,
    required this.onHelp,
  });

  final PremiumPaywallState state;
  final VoidCallback? onSubscribe;
  final VoidCallback onHelp;

  /// The button's words for [offer]: a month, a year, or so many months, with
  /// the price kept whole in a right-to-left sentence.
  String _continueLabel(BuildContext context, PremiumPlanOffer offer) {
    final period = switch (offer.months) {
      1 => 'month',
      12 => 'year',
      _ => 'other',
    };
    return context.l10n.paywallContinue(
      period,
      _inLine(context, offer.price),
      offer.months,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    final selected = state.selected;
    final gap = SizedBox(height: AppLayout.premiumPaywallBarGap.h);

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppLayout.premiumPaywallPadH.w,
        AppLayout.premiumPaywallBarPadTop.h,
        AppLayout.premiumPaywallPadH.w,
        AppLayout.premiumPaywallBarPadBottom.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              label: selected == null
                  ? l10n.paywallTitle
                  : _continueLabel(context, selected),
              color: palette.paywallAccent,
              icon: Iconsax.google_play,
              isLoading: state.isPurchasing,
              onPressed: onSubscribe,
            ),
          ),
          gap,
          // The renewal terms in the page's smallest type: there to be read,
          // without competing with the price above them.
          Text(
            l10n.subscriptionAutoRenews,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textTertiary,
              fontSize: AppLayout.textXs.sp,
            ),
          ),
          // A link rather than a button, so it is there for a buyer whose
          // payment fails without competing with the one that pays.
          PremiumTextLink(
            label: l10n.paymentProblemsLink,
            color: palette.textSecondary,
            onPressed: onHelp,
            opensPage: true,
          ),
        ],
      ),
    );
  }
}

/// Sells premium on a Play build, on a page of its own: Basic against
/// Premium, then the plan — a device count and a period, each priced by Play
/// — and the one button that opens Play's sheet.
class _PremiumPaywall extends ConsumerStatefulWidget {
  const _PremiumPaywall({required this.renewal, required this.selecting});

  final bool renewal;
  final PremiumPlan? selecting;

  @override
  ConsumerState<_PremiumPaywall> createState() => _PremiumPaywallState();
}

class _PremiumPaywallState extends ConsumerState<_PremiumPaywall> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(premiumPaywallProvider.notifier)
          .load(selecting: widget.selecting);
    });
  }

  /// Closes, then says why: the page is gone by the time anyone reads it.
  void _closeWith(String message) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _onOutcome(PlayPurchaseOutcome? previous, PlayPurchaseOutcome? next) {
    if (next == PlayPurchaseOutcome.granted) {
      _closeWith(context.l10n.purchaseGranted);
    }
  }

  Future<void> _subscribe() async {
    final l10n = context.l10n;
    final result = await ref.read(premiumPaywallProvider.notifier).subscribe();
    if (!mounted) return;
    // The root screen takes the buyer to sign in, and brings the paywall
    // back on the same plan once they have.
    if (result == PaywallSubscribe.needsSignIn) {
      _closeWith(l10n.signInToSubscribe);
    }
  }

  /// The palette the page's helpers draw in, read from the theme it sits in.
  PremiumPalette get palette => PremiumPalette.of(context);

  Widget _note(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: AppLayout.textMd.sp,
      ),
    );
  }

  /// Why a renewal opened. A first purchase needs no heading: the badges at
  /// the top already say where it leads.
  Widget _renewalHeader(AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.subscriptionExpiredTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: AppLayout.text7xl.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppLayout.premiumPaywallTitleGap.h),
        Text(
          l10n.subscriptionExpiredMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: AppLayout.textXl.sp,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  /// What stands in the plan card's place until there is one: a spinner
  /// while Play prices the plans, and the plans-unavailable banner when there
  /// is nothing to sell.
  Widget _standIn(PremiumPaywallState state) {
    if (state.isLoading) {
      return Center(
        child: SizedBox.square(
          dimension: AppLayout.premiumPaywallSpinner.w,
          child: CircularProgressIndicator(
            color: palette.paywallAccent,
            strokeWidth: AppLayout.premiumPaywallSpinnerStroke,
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.premiumPaywallPadH.w,
        ),
        child: const PremiumErrorBanner(
          errorKey: UserFacingErrorKeys.plansUnavailable,
        ),
      ),
    );
  }

  /// The plan card, once Play has priced it.
  Widget _plans(PremiumPaywallState state) {
    final paywall = ref.read(premiumPaywallProvider.notifier);
    final canChange = !state.isPurchasing;
    return _PlanCard(
      state: state,
      onDevices: canChange ? paywall.selectDevices : null,
      onMonths: canChange ? paywall.selectMonths : null,
    );
  }

  /// What came of the last purchase. A payment still clearing is news, not
  /// a failure, so it is told in plain text rather than in a banner.
  Widget? _status(AppLocalizations l10n, PlayPurchaseOutcome? outcome) {
    return switch (outcome) {
      PlayPurchaseOutcome.pending => _note(l10n.purchasePending),
      PlayPurchaseOutcome.confirmLater => _note(l10n.purchaseConfirmLater),
      PlayPurchaseOutcome.alreadyOwned => const PremiumErrorBanner(
        errorKey: UserFacingErrorKeys.playAlreadyOwned,
      ),
      PlayPurchaseOutcome.failed => const PremiumErrorBanner(
        errorKey: UserFacingErrorKeys.purchaseFailed,
      ),
      PlayPurchaseOutcome.granted ||
      PlayPurchaseOutcome.canceled ||
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(premiumPaywallProvider);
    ref.listen<PlayPurchaseOutcome?>(
      premiumPaywallProvider.select((paywall) => paywall.outcome),
      _onOutcome,
    );
    final status = _status(l10n, state.outcome);
    final padH = AppLayout.premiumPaywallPadH.w;
    final sectionGapHeight = AppLayout.premiumPaywallSectionGap.h;
    final sectionGap = SizedBox(height: sectionGapHeight);

    // Closing stays open while a purchase is under way: the purchase listener
    // sees it through whether the page is up or not, and a purchase that
    // never reports back must not leave the buyer with no way out.
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: context.palette.pageGradient(SurfaceMood.idle),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: padH),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TopBar(onClose: () => Navigator.of(context).pop()),
                            if (widget.renewal) ...[
                              _renewalHeader(l10n),
                              sectionGap,
                            ] else
                              SizedBox(
                                height: AppLayout.premiumPaywallTitleGap.h,
                              ),
                            _Comparison(
                              mostDevices: state.offers.keys.lastOrNull,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Until there is a plan card, what stands in for it takes
                    // what the table leaves above the pay bar and sits in the
                    // middle of it. No purchase can have an outcome then,
                    // since nothing is priced to buy.
                    if (state.isLoading || state.isUnavailable)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: sectionGapHeight,
                          ),
                          child: _standIn(state),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          padH,
                          sectionGapHeight,
                          padH,
                          sectionGapHeight,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _plans(state),
                              if (status != null) ...[sectionGap, status],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _PayBar(
                state: state,
                onSubscribe: state.selected != null && !state.isPurchasing
                    ? _subscribe
                    : null,
                onHelp: () => openSupportTelegram(
                  context,
                  message: l10n.premiumSupportMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the paywall as a page over everything, the navigation bar included.
///
/// [renewal] titles it for a subscription that ran out; [selecting] opens it
/// on a plan picked before a sign-in.
Future<void> showPremiumPaywall(
  BuildContext context, {
  bool renewal = false,
  PremiumPlan? selecting,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PremiumPaywall(renewal: renewal, selecting: selecting),
    ),
  );
}
