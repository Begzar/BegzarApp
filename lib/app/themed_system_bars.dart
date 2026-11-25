import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks the platform for status and navigation bar icons that read on the
/// theme [child] is drawn in.
///
/// Nothing asked before the light theme: the dark launch theme gave light
/// icons, which disappear on a light page. Both bars stay clear, so the page
/// runs under them in either theme — Material's presets paint the navigation
/// bar black, which older Android draws under a light page as it is.
class ThemedSystemBars extends StatelessWidget {
  const ThemedSystemBars({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final style = light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    final icons = light ? Brightness.dark : Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: icons,
      ),
      child: child,
    );
  }
}
