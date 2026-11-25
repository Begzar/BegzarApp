import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:flutter/widgets.dart';

/// The quiet line between two sections of a premium card: the sign-in card's
/// header and form, and the account panel's parts.
class PremiumSectionDivider extends StatelessWidget {
  const PremiumSectionDivider({super.key});

  /// One logical pixel, unscaled: it is a line, not a shape.
  static const _thickness = 1.0;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Container(height: _thickness, color: palette.divider);
  }
}
