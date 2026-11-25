import 'package:begzar/core/support/telegram_mark.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_purchase_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The glyph on a purchase button: Telegram's plane when the tap opens the
/// bot, a globe when it opens the website, Play's mark on a Play build.
///
/// The square is reserved before the answer is known and the glyph fades in
/// once it is, so the button's label does not move. For a device that places
/// itself that is a platform-channel round trip; only a buyer whose address
/// has to be asked waits on the network, and only on the first dialog of a
/// run.
class PurchaseDestinationMark extends ConsumerWidget {
  const PurchaseDestinationMark({super.key, required this.size});

  /// The same number an [Icon] would be given — see [TelegramMark.size].
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(purchaseDestinationProvider).value;
    return SizedBox.square(
      dimension: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: switch (destination) {
          null => const SizedBox.shrink(),
          PurchaseDestination.telegramBot => TelegramMark(
            key: const ValueKey(PurchaseDestination.telegramBot),
            size: size,
          ),
          PurchaseDestination.website => Icon(
            Iconsax.global,
            key: const ValueKey(PurchaseDestination.website),
            size: size,
          ),
          PurchaseDestination.googlePlay => Icon(
            Iconsax.google_play,
            key: const ValueKey(PurchaseDestination.googlePlay),
            size: size,
          ),
        },
      ),
    );
  }
}
