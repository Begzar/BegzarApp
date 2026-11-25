import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A mood-gradient-free dialog shell: one glass panel over the scrim.
class AppGlassDialog extends StatelessWidget {
  const AppGlassDialog({
    super.key,
    required this.child,
    this.radius = AppLayout.coreDialogRadius,
    this.padding,
    this.insetPadding,
    this.style,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsets? insetPadding;
  final AppGlassStyle? style;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      insetPadding:
          insetPadding ??
          EdgeInsets.symmetric(horizontal: AppLayout.coreDialogInsetH.w),
      content: AppGlassPanel(
        style: style ?? AppGlass.dialog(context.palette, cornerRadius: radius),
        child: Padding(
          padding: padding ?? EdgeInsets.all(AppLayout.coreDialogPad.w),
          child: child,
        ),
      ),
    );
  }
}
