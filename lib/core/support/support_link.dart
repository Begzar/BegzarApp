import 'package:begzar/core/support/support_contact.dart';
import 'package:begzar/core/support/telegram_mark.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The way out of a failure, wherever one is shown.
///
/// Four screens offered this link and each drew it differently — three shades
/// of red between them and, on the empty server list, a bare [TextButton]
/// wearing whatever the theme handed it. They already shared
/// [openSupportTelegram]; there is no reason they should not share what it
/// looks like.
///
/// It is deliberately not painted in the error colour. The message and the
/// hint above it carry the failure; this is the one thing on screen that
/// undoes it, and an escape hatch drawn in the same red as the problem reads
/// as more of the problem. White at [_labelAlpha] holds its contrast on all
/// three grounds it lands on: the account banner's red wash, the toast's dark
/// red, and the empty list's plain gradient.
class SupportLink extends StatelessWidget {
  /// Opens the support chat, carrying [message] for the caller.
  const SupportLink({super.key, required String message})
    : _message = message,
      _onTap = null;

  /// Runs [onTap] instead of opening the chat here.
  ///
  /// The error toast needs this. It has to take itself off screen before the
  /// chat opens — nobody should come back from Telegram to a stale popup —
  /// and by that point this widget's own context is gone, so the toast opens
  /// against the context that put the overlay up in the first place.
  const SupportLink.deferred({super.key, required VoidCallback onTap})
    : _message = null,
      _onTap = onTap;

  final String? _message;
  final VoidCallback? _onTap;

  /// Smaller than the 18 the offer buttons use. A filled mark carries more
  /// ink than a stroked glyph of the same size, and beside a 12sp label at
  /// this weight an 18 plane stops being a mark and becomes the loudest thing
  /// in the banner.
  static const _markSize = 14.0;

  static const _gap = 6.0;
  static const _fontSize = 12.0;
  static const _labelAlpha = 0.95;

  @override
  Widget build(BuildContext context) {
    final ink = context.palette.veil.withValues(alpha: _labelAlpha);

    return GestureDetector(
      // The gap between mark and label is part of the target rather than a
      // hole in it.
      behavior: HitTestBehavior.opaque,
      onTap: _onTap ?? () => openSupportTelegram(context, message: _message!),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TelegramMark(size: _markSize.w, color: ink),
          SizedBox(width: _gap.w),
          Text(
            context.l10n.getHelp,
            style: TextStyle(
              color: ink,
              fontSize: _fontSize.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
