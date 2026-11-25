import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/modules/app_update/presentation/app_update_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The dot that marks a newer release: on the settings tab's glyph and on the
/// icon of the row that offers it, for as long as the release waits.
///
/// One widget for both places, so the dot the user follows from the nav bar is
/// the dot they find in settings.
class UpdateDot extends StatelessWidget {
  const UpdateDot({super.key, this.semanticLabel});

  /// What a screen reader hears. Given on the nav bar, where the dot is the
  /// only thing saying there is news; left out on a row whose title already
  /// says it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dot = SizedBox.square(
      dimension: AppLayout.updateDot.w,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppUpdatePalette.of(context).notice,
          shape: BoxShape.circle,
        ),
      ),
    );

    final label = semanticLabel;
    if (label == null) return dot;
    return Semantics(label: label, child: dot);
  }
}
