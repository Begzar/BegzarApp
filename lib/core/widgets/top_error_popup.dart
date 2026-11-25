import 'package:begzar/core/theme/app_palette.dart';
import 'dart:async';

import 'package:begzar/core/errors/error_presentation.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/core/support/support_contact.dart';
import 'package:begzar/core/support/support_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Soft toast for connection / premium errors (message + hint + optional help).
/// Nearly opaque, not glass: an error toast is drawn over whatever failed,
/// and the failure must not read through the message explaining it.
const _toastOpacity = 0.96;

/// The rim, strong enough to separate the toast from a dark screen behind it.
const _toastRimAlpha = 0.45;

/// How long the toast stays up unless closed.
///
/// Nothing else on screen repeats the reason, so the toast is the only place
/// an error is ever read. Four seconds was too short for a message, a hint
/// and a help link; this sits in the upper half of Material's 4–10 second
/// range for a snackbar.
const _onScreenFor = Duration(seconds: 8);

/// Takes the toast on screen away, or null when there is none.
///
/// Every toast is drawn at the same spot, so a second one stacked on the first
/// would paint one reason over the other. A new toast replaces the old one,
/// whichever tone either of them is.
VoidCallback? _dismissShown;

/// What a toast is telling the reader, which decides how it is painted.
///
/// Error styling is kept for errors: a notice that something happened, where
/// nothing failed, takes the warning colour instead.
enum _ToastTone {
  error,
  notice;

  Color surface(AppPalette palette) => switch (this) {
    _ToastTone.error => palette.errorToast,
    _ToastTone.notice => palette.noticeToast,
  };

  /// The rim and the icon.
  Color accent(AppPalette palette) => switch (this) {
    _ToastTone.error => palette.failedInk,
    _ToastTone.notice => palette.warningInk,
  };
}

/// What the toast casts on the screen under it.
const _toastShadowAlpha = 0.35;
const _toastShadowBlur = 18.0;
const _toastShadowDrop = 8.0;

/// Puts a toast above everything for [_onScreenFor], or until closed, in place
/// of any toast already showing.
///
/// [build] is handed the dismiss callback, for a toast whose own link has to
/// take it off screen first.
void _showToast(
  BuildContext context,
  Widget Function(VoidCallback dismiss) build,
) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _dismissShown?.call();

  late OverlayEntry entry;
  Timer? timer;

  void dismiss() {
    timer?.cancel();
    if (entry.mounted) {
      entry.remove();
    }
    if (_dismissShown == dismiss) _dismissShown = null;
  }

  entry = OverlayEntry(
    builder: (context) {
      final bottom =
          MediaQuery.of(context).padding.bottom +
          AppLayout.coreToastClearance.w;
      return Positioned(
        bottom: bottom,
        left: AppLayout.gap16.w,
        right: AppLayout.gap16.w,
        child: build(dismiss),
      );
    },
  );

  overlay.insert(entry);
  _dismissShown = dismiss;
  timer = Timer(_onScreenFor, dismiss);
}

void showTopErrorPopup(BuildContext context, String? errorKey) {
  final l10n = context.l10n;
  final error = ErrorPresentation.fromKey(errorKey, l10n);
  if (error.message.trim().isEmpty) return;

  final hostContext = context;

  _showToast(
    context,
    (dismiss) => _TopToast(
      tone: _ToastTone.error,
      message: error.message,
      hint: error.hint,
      onHelp: error.showPremiumHelp
          ? () {
              dismiss();
              if (!hostContext.mounted) return;
              openSupportTelegram(
                hostContext,
                message: l10n.premiumSupportMessage,
              );
            }
          : null,
      onClose: dismiss,
    ),
  );
}

/// The same toast for something the user should know happened, where nothing
/// failed — painted in the warning colour rather than as an error.
void showTopNoticePopup(BuildContext context, String message) {
  if (message.trim().isEmpty) return;

  _showToast(
    context,
    (dismiss) =>
        _TopToast(tone: _ToastTone.notice, message: message, onClose: dismiss),
  );
}

class _TopToast extends StatefulWidget {
  const _TopToast({
    required this.tone,
    required this.message,
    required this.onClose,
    this.hint,
    this.onHelp,
  });

  final _ToastTone tone;
  final String message;
  final String? hint;
  final VoidCallback? onHelp;
  final VoidCallback onClose;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hint = widget.hint;
    final tone = widget.tone;
    final accent = tone.accent(palette);
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.coreErrorToastPadH.w,
              vertical: AppLayout.coreErrorToastPadV.h,
            ),
            decoration: BoxDecoration(
              color: tone.surface(palette).withValues(alpha: _toastOpacity),
              borderRadius: BorderRadius.circular(AppLayout.coreToastRadius.r),
              border: Border.all(
                color: accent.withValues(alpha: _toastRimAlpha),
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: _toastShadowAlpha),
                  blurRadius: _toastShadowBlur,
                  offset: const Offset(0, _toastShadowDrop),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Iconsax.warning_2,
                  color: accent,
                  size: AppLayout.coreErrorToastIcon.sp,
                ),
                SizedBox(width: AppLayout.coreToastGap.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.message,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: AppLayout.textLg.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                        ),
                      ),
                      if (hint != null && hint.isNotEmpty) ...[
                        SizedBox(height: AppLayout.coreErrorToastHintGap.h),
                        Text(
                          hint,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: AppLayout.textBase.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (widget.onHelp != null) ...[
                        SizedBox(height: AppLayout.coreErrorToastHelpGap.h),
                        // Deferred rather than opening the chat itself: the
                        // callback takes this toast off screen first, and
                        // does it against the context that put the overlay
                        // up rather than this one, which is gone by then.
                        SupportLink.deferred(onTap: widget.onHelp!),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppLayout.coreToastCloseGap.w),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Icon(
                    Iconsax.close_circle_copy,
                    color: palette.muted,
                    size: AppLayout.coreErrorToastClose.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
