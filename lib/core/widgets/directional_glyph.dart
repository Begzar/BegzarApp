import 'package:flutter/widgets.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The glyphs that have to point the way the text runs.
///
/// Material declares its chevron and its back arrow with `matchTextDirection`,
/// so they turned themselves round in Persian without anybody asking. Iconsax
/// carries no such flag — every glyph in the set is drawn one way and stays
/// that way — so swapping one family for the other without handling this would
/// have sent the reader's eye the wrong way in the language most of them read,
/// and it would have looked deliberate.
///
/// Two glyphs, opposite senses, which is the part worth writing down: a
/// chevron closing a row points *forward*, in the direction the reader is
/// travelling, while a back control points *backward*. In Persian that makes
/// them the same arrow pointing opposite ways.
abstract final class DirectionalGlyph {
  static bool _isRtl(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  /// The chevron closing a row that opens something. Points the way the reader
  /// is going.
  static IconData chevron(BuildContext context) =>
      _isRtl(context) ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy;

  /// The control that goes back a screen. Points the way the reader came.
  static IconData back(BuildContext context) =>
      _isRtl(context) ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy;
}
