import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The frosted panel every section of the account screen sits in.
///
/// Translucent on purpose: the connection-status gradient behind it is what
/// tells the user whether the tunnel is up, and an opaque card would hide it.
class PremiumGlassCard extends StatelessWidget {
  const PremiumGlassCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AppGlassPanel(
      style: AppGlass.panel(
        context.palette,
        cornerRadius: AppLayout.premiumCardRadius.r,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(AppLayout.premiumCardInnerPad.w),
        child: child,
      ),
    );
  }
}
