import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Which plan the account is on: beside the app name, and at the top of the
/// paywall, where Basic leads to Premium.
///
/// In core rather than in the home screen's module because both screens show
/// it, and two copies of one badge would drift apart.
///
/// A small tracked tag rather than a pill, outlined either way: the accent
/// for Premium, a hairline and a muted label for Basic.
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key, required this.isPremium});

  final bool isPremium;

  /// How long the badge takes to change colour when the plan changes.
  static const _stateChange = Duration(milliseconds: 220);

  /// The weight the label is set in. A word in a small tag needs a step more
  /// than the body text around it to hold its shape.
  static const _premiumWeight = FontWeight.w600;
  static const _basicWeight = FontWeight.w500;

  /// Where `پایه` looks centred, up from its baseline as a fraction of the
  /// font size.
  ///
  /// The face's number suits `پریمیوم`, which is what a reader judged on
  /// device. `پایه` carries more of its weight high, and on that number it
  /// sat high in its badge. What a word's position is judged by is the
  /// weight of its letters rather than the box round them: `پایه`'s ink box
  /// was already centred, and `پریمیوم`'s, which looks right, is a pixel
  /// low. So the two are placed by their ink's centroid — 0.162em above the
  /// baseline for `پایه` and 0.083em for `پریمیوم` — each the same distance
  /// from the middle of its badge as the one that reads as centred.
  static const _persianBasicCentre = 0.205;

  @override
  Widget build(BuildContext context) {
    final fontSize = AppLayout.planBadgeFont.sp;
    // A plan name is a word, not a reading, so it keeps the body face it
    // inherits; the mono face is for addresses, latencies and clocks.
    final family = DefaultTextStyle.of(context).style.fontFamily;
    final centre = !isPremium && family == 'Estedad'
        ? _persianBasicCentre
        : opticalCentreAboveBaselineFor(family);
    // Tracking and capitals are a Latin-script treatment; they would pull a
    // joined script apart.
    final tracked = !joinsLetters(family);
    final label = isPremium ? context.l10n.planPremium : context.l10n.planBasic;
    final palette = context.palette;

    return AnimatedContainer(
      duration: _stateChange,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: AppLayout.planBadgePadH.w),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPremium ? palette.planPremiumRim : palette.planBasicRim,
        ),
        borderRadius: BorderRadius.circular(AppLayout.planBadgeRadius.r),
      ),
      child: SizedBox(
        height: AppLayout.planBadgeHeight.w,
        child: Baseline(
          baseline: AppLayout.planBadgeHeight.w / 2 + fontSize * centre,
          baselineType: TextBaseline.alphabetic,
          child: Text(
            tracked ? label.toUpperCase() : label,
            style: TextStyle(
              color: isPremium ? palette.accent : palette.planBasicInk,
              fontWeight: isPremium ? _premiumWeight : _basicWeight,
              fontSize: fontSize,
              letterSpacing: tracked ? AppLayout.planBadgeTracking : null,
            ),
          ),
        ),
      ),
    );
  }
}
