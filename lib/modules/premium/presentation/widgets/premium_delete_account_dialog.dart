import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/services/native_url_launcher.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/di/app_update_providers.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_buttons.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_dialog_frame.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_error_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Where a Play subscriber cancels, which deleting the account does not do.
const _playSubscriptionsUrl =
    'https://play.google.com/store/account/subscriptions?package=cloud.begzar.begzar';

/// Asks for the password, then deletes the account.
///
/// Drawn in the frame every premium popup shares. It stays open until the
/// server has answered, so a refusal is read where the password was typed,
/// and says so once the account is gone. [accent] is the account panel's, so
/// the field looks like the ones behind it.
Future<void> showDeleteAccountDialog(
  BuildContext context,
  PremiumAccent accent,
) {
  return showDialog<void>(
    context: context,
    barrierColor: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
    builder: (_) => _DeleteAccountDialog(accent: accent),
  );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog({required this.accent});

  final PremiumAccent accent;

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _isDeleting = false;
  String? _errorKey;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_isDeleting) return;
    final l10n = context.l10n;
    // Taken before the wait: the dialog is gone by the time there is
    // anything to say.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isDeleting = true;
      _errorKey = null;
    });

    final refusal = await ref
        .read(premiumProvider.notifier)
        .deleteAccount(_passwordController.text);
    if (!mounted) return;

    if (refusal == null) {
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
      return;
    }
    setState(() {
      _isDeleting = false;
      _errorKey = refusal;
    });
  }

  List<Widget> _playNote(PremiumPalette palette, AppLocalizations l10n) {
    return [
      Text(
        l10n.deleteAccountPlayNote,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.textTertiary,
          fontSize: AppLayout.textBase.sp,
          height: 1.45,
        ),
      ),
      PremiumTextLink(
        label: l10n.manageGooglePlaySubscription,
        color: widget.accent.primary,
        onPressed: () => NativeUrlLauncher.open(_playSubscriptionsUrl),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = PremiumPalette.of(context);
    final isPlayBuild =
        ref.watch(appDistributionSourceProvider) ==
        AppDistributionSource.googlePlay;

    return PopScope(
      canPop: !_isDeleting,
      child: PremiumDialogFrame(
        icon: Iconsax.trash,
        iconColor: palette.red,
        iconBackground: palette.red.withValues(
          alpha: PremiumDialogFrame.iconBackgroundAlpha,
        ),
        title: l10n.deleteAccountTitle,
        message: l10n.deleteAccountMessage,
        body: [
          if (isPlayBuild) ..._playNote(palette, l10n),
          PremiumTextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            label: l10n.password,
            icon: Iconsax.lock,
            accent: widget.accent,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: _delete,
          ),
          if (_errorKey != null) PremiumErrorBanner(errorKey: _errorKey),
        ],
        onCancel: _isDeleting ? null : () => Navigator.of(context).pop(),
        action: PremiumDialogAction(
          label: _isDeleting ? l10n.deletingAccount : l10n.deleteAccountConfirm,
          color: palette.red,
          onPressed: _isDeleting ? null : _delete,
        ),
      ),
    );
  }
}
