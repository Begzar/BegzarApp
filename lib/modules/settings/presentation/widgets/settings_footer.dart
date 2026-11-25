import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Says that nothing on this screen takes effect mid-connection.
///
/// A note rather than a warning: none of these settings can be applied to a
/// tunnel that is already up, and nothing has gone wrong.
class SettingsReconnectNote extends StatelessWidget {
  const SettingsReconnectNote({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);

    return SettingsGlassPanel(
      style: SettingsGlass.panel(
        palette,
        cornerRadius: AppLayout.settingsDialogFieldRadius.r,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.settingsFooterPadH.w,
          vertical: AppLayout.settingsFooterPadV.h,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Iconsax.info_circle_copy,
              color: palette.textMuted,
              size: AppLayout.settingsFooterGlyph.sp,
            ),
            SizedBox(width: AppLayout.settingsFooterGap.w),
            Expanded(
              child: Text(
                context.l10n.settingsInfoReconnect,
                style: TextStyle(
                  fontSize: AppLayout.textMd.sp,
                  color: palette.textTertiary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
