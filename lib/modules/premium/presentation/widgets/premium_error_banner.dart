import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/core/theme/surface_alpha.dart';
import 'package:begzar/core/errors/error_presentation.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/core/support/support_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A failure a premium dialog or sheet shows in place, beside the control that
/// was refused. The account screen itself reports through the error toast; a
/// modal keeps its reason because the modal is what the user is looking at.
///
/// Takes an l10n key, never a message: everything below presentation reports
/// failures as keys, and resolving one is this widget's job.
/// A banner states a failure without shouting it: the fill is a tint of the
/// destructive colour rather than the colour itself, and the rim carries the
/// weight.
const _fillAlpha = 0.15;
const _rimAlpha = 0.35;

class PremiumErrorBanner extends StatelessWidget {
  const PremiumErrorBanner({super.key, required this.errorKey});

  final String? errorKey;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    final error = ErrorPresentation.fromKey(errorKey, l10n);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.premiumNoticePadH.w,
        vertical: AppLayout.premiumNoticePadV.h,
      ),
      decoration: BoxDecoration(
        color: palette.red.withValues(alpha: _fillAlpha),
        borderRadius: BorderRadius.circular(AppLayout.premiumInnerRadius.r),
        border: Border.all(color: palette.red.withValues(alpha: _rimAlpha)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error.message,
            style: TextStyle(color: palette.red, fontSize: AppLayout.textLg.sp),
          ),
          if (error.hint != null) ...[
            SizedBox(height: AppLayout.premiumNoticeLineGap.h),
            Text(
              error.hint!,
              style: TextStyle(
                color: palette.red.withValues(
                  alpha: SurfaceAlpha.textSecondary,
                ),
                fontSize: AppLayout.textBase.sp,
              ),
            ),
          ],
          // Shown only for failures a person can actually resolve, so the
          // support link does not become background noise.
          if (error.showPremiumHelp) ...[
            SizedBox(height: AppLayout.premiumNoticeBlockGap.h),
            SupportLink(message: l10n.premiumSupportMessage),
          ],
        ],
      ),
    );
  }
}
