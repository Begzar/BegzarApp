import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/widgets/app_glass_dialog.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/ink_dialog.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Asks for the DNS server the tunnel resolves through, with the common
/// public resolvers a tap away.
Future<void> showDnsServerDialog(BuildContext context, String currentDns) {
  return showDialog<void>(
    context: context,
    barrierColor: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
    builder: (dialogContext) => _DnsServerDialog(currentDns: currentDns),
  );
}

typedef _DnsSuggestion = ({
  String address,
  String Function(AppLocalizations) label,
});

const _suggestions = <_DnsSuggestion>[
  (address: '8.8.8.8', label: _googleLabel),
  (address: '1.1.1.1', label: _cloudflareLabel),
  (address: '4.2.2.4', label: _level3Label),
  (address: '208.67.222.222', label: _openDnsLabel),
];

String _googleLabel(AppLocalizations l10n) => l10n.dnsGoogle;
String _cloudflareLabel(AppLocalizations l10n) => l10n.dnsCloudflare;
String _level3Label(AppLocalizations l10n) => l10n.dnsLevel3;
String _openDnsLabel(AppLocalizations l10n) => l10n.dnsOpenDns;

class _DnsServerDialog extends ConsumerStatefulWidget {
  const _DnsServerDialog({required this.currentDns});

  final String currentDns;

  @override
  ConsumerState<_DnsServerDialog> createState() => _DnsServerDialogState();
}

class _DnsServerDialogState extends ConsumerState<_DnsServerDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentDns,
  );

  bool _showInvalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final accepted = await ref
        .read(settingsProvider.notifier)
        .setDnsServer(_controller.text);
    if (!mounted) return;

    if (!accepted) {
      setState(() => _showInvalid = true);
      return;
    }
    Navigator.of(context).pop();
  }

  void _useSuggestion(String address) {
    setState(() {
      _controller.text = address;
      _showInvalid = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = SettingsPalette.of(context);

    return AppGlassDialog(
      padding: EdgeInsets.all(AppLayout.inkDialogPad.w),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: InkDialogEmblem(
                icon: Iconsax.shield_tick_copy,
                color: palette.accent,
              ),
            ),
            SizedBox(height: AppLayout.inkDialogEmblemGap.h),
            InkDialogText(
              title: l10n.dnsDialogTitle,
              message: l10n.dnsDialogPrompt,
              textAlign: TextAlign.start,
            ),
            SizedBox(height: AppLayout.inkDialogSectionGap.h),
            TextField(
              controller: _controller,
              style: InkInput.text(context.palette),
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              cursorColor: palette.accent,
              onChanged: (_) {
                if (_showInvalid) setState(() => _showInvalid = false);
              },
              onSubmitted: (_) => _save(),
              decoration: InkInput.decoration(
                context.palette,
                accent: palette.accent,
                hint: '8.8.8.8',
                invalid: _showInvalid,
              ),
            ),
            if (_showInvalid) ...[
              SizedBox(height: AppLayout.settingsDnsInvalidGap.h),
              Text(
                l10n.dnsDialogInvalid,
                style: TextStyle(
                  color: palette.invalidInput,
                  fontSize: AppLayout.textMd.sp,
                ),
              ),
            ],
            SizedBox(height: AppLayout.inkDialogSectionGap.h),
            Text(
              l10n.dnsDialogCommon,
              style: TextStyle(
                color: palette.sectionLabel,
                fontSize: AppLayout.textMd.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppLayout.settingsDnsSuggestTop.h),
            Wrap(
              spacing: AppLayout.inkChipGap.w,
              runSpacing: AppLayout.inkChipGap.h,
              children: [
                for (final suggestion in _suggestions)
                  _chip(palette, l10n, suggestion),
              ],
            ),
            SizedBox(height: AppLayout.inkDialogActionsGap.h),
            InkDialogActions(
              cancelLabel: l10n.cancel,
              onCancel: () => Navigator.of(context).pop(),
              action: InkFilledButton(
                label: l10n.save,
                color: palette.accent,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A resolver to fill the field with, marked while it is the one typed.
  Widget _chip(
    SettingsPalette palette,
    AppLocalizations l10n,
    _DnsSuggestion suggestion,
  ) {
    final chosen = _controller.text.trim() == suggestion.address;
    final radius = BorderRadius.circular(AppLayout.inkChipRadius.r);

    return Material(
      color: chosen
          ? palette.accent.withValues(alpha: _chosenFillAlpha)
          : palette.cardRaised,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: chosen
              ? palette.accent.withValues(alpha: _chosenRimAlpha)
              : palette.borderSoft,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _useSuggestion(suggestion.address),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.inkChipPadH.w,
            vertical: AppLayout.inkChipPadV.h,
          ),
          child: Text(
            l10n.dnsChipLabel(suggestion.label(l10n), suggestion.address),
            style: TextStyle(
              color: chosen ? palette.accent : palette.textSecondary,
              fontSize: AppLayout.textBase.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  static const _chosenFillAlpha = 0.12;
  static const _chosenRimAlpha = 0.35;
}
