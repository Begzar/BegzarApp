import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/widgets/app_glass_dialog.dart';
import 'package:begzar/core/widgets/ink_dialog.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The one filled action a premium popup asks for.
///
/// A null [onPressed] disables it, for an action already under way; the fill
/// dims rather than disappearing, so the row does not reflow.
class PremiumDialogAction extends StatelessWidget {
  const PremiumDialogAction({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.mark,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  /// Where the tap goes — the bot, the website — drawn beside the label.
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    return InkFilledButton(
      label: label,
      color: color,
      onPressed: onPressed,
      leading: mark,
    );
  }
}

/// The frame every premium popup shares: a lit glyph, a centred title and
/// message, whatever the popup needs in between, then Cancel beside the one
/// action it is asking for.
///
/// The purchase, renewal, account-inactive and delete-account popups are all
/// drawn from this, so none of them can drift into a look of its own.
class PremiumDialogFrame extends StatelessWidget {
  const PremiumDialogFrame({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    required this.action,
    required this.onCancel,
    this.body = const [],
  });

  /// How strongly a popup's glyph colour tints the tile behind it.
  static const iconBackgroundAlpha = 0.12;

  final IconData icon;
  final Color iconColor;

  /// The glyph's tile.
  final Color iconBackground;
  final String title;
  final String message;

  /// Between the message and the buttons: a field, a note, an error.
  final List<Widget> body;

  final PremiumDialogAction action;

  /// Null disables Cancel, while the action is under way.
  final VoidCallback? onCancel;

  /// Everything from the glyph to the buttons.
  Widget _content(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: InkDialogEmblem(
            icon: icon,
            color: iconColor,
            fill: iconBackground,
          ),
        ),
        SizedBox(height: AppLayout.inkDialogEmblemGap.h),
        InkDialogText(title: title, message: message),
        for (final part in body) ...[
          SizedBox(height: AppLayout.premiumDialogBodyGap.h),
          part,
        ],
        SizedBox(height: AppLayout.inkDialogActionsGap.h),
        InkDialogActions(
          cancelLabel: l10n.cancel,
          onCancel: onCancel,
          action: action,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _content(context.l10n);

    return AppGlassDialog(
      padding: EdgeInsets.all(AppLayout.inkDialogPad.w),
      // A popup with a field in it can be taller than what the keyboard
      // leaves, so it scrolls rather than overflowing.
      child: SingleChildScrollView(child: content),
    );
  }
}
