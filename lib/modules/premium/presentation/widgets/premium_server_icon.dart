import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// A server's flag, falling back to a globe when the code is missing or the
/// asset is not shipped — a broken-image box would read as a broken server.
///
/// Shared rather than drawn twice: the list card and the home row both open
/// with this, and a fallback that differed between them would say the two
/// screens disagree about whether the server is reachable.
class PremiumServerIcon extends StatelessWidget {
  const PremiumServerIcon({super.key, required this.size, this.flagCode});

  /// The box's side. Both call sites pass a `.w` value, so the artwork keeps
  /// its proportions on every panel.
  final double size;

  /// Two-letter country code from the first config name, already lowercased.
  final String? flagCode;

  /// Proportional to the box, so the fallback reads as filling the same slot
  /// the flag would rather than as a smaller thing left in it.
  static const _glyphRatio = 0.45;

  static const _assetDir = 'assets/flags';

  /// Filenames under [_assetDir], without `.png`. A code not in this set is
  /// the globe, rather than a failed asset load.
  static const _shipped = {
    'at',
    'bg',
    'ca',
    'de',
    'dk',
    'fi',
    'fr',
    'in',
    'nl',
    'no',
    'ro',
    'se',
    'si',
    'sp',
    'sw',
    'tr',
    'uk',
    'us',
  };

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final code = flagCode?.trim().toLowerCase();
    final asset = code != null && _shipped.contains(code)
        ? '$_assetDir/$code.png'
        : null;
    final fallback = Icon(
      Iconsax.global,
      color: palette.textSecondary,
      size: size * _glyphRatio,
    );

    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: asset == null
            ? fallback
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
