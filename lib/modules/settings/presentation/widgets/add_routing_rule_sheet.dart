import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/widgets/app_sheet_handle.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/ink_dialog.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/settings/application/services/routing_rules_service.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:begzar/modules/settings/presentation/controllers/custom_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Raises the sheet that adds one site or address to [action]'s list.
Future<void> showAddRoutingRuleSheet(
  BuildContext context,
  RoutingAction action,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SettingsPalette.of(context).sheetSurface,
    barrierColor: AppPalette.scrim.withValues(alpha: AppLayout.scrimAlpha),
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppLayout.mainPickerRadius.r),
      ),
    ),
    builder: (_) => _AddRoutingRuleSheet(action: action),
  );
}

class _AddRoutingRuleSheet extends ConsumerStatefulWidget {
  const _AddRoutingRuleSheet({required this.action});

  final RoutingAction action;

  @override
  ConsumerState<_AddRoutingRuleSheet> createState() =>
      _AddRoutingRuleSheetState();
}

class _AddRoutingRuleSheetState extends ConsumerState<_AddRoutingRuleSheet> {
  final _controller = TextEditingController();
  RoutingEntryType _entryType = RoutingEntryType.domain;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final outcome = await ref
        .read(customRoutingProvider.notifier)
        .addRule(
          action: widget.action,
          type: _entryType,
          rawValue: _controller.text,
        );

    if (!mounted) return;

    // A rule that is already listed is not an error, but closing silently
    // would look like the entry was added twice.
    final message = switch (outcome) {
      RoutingRuleOutcome.added => null,
      RoutingRuleOutcome.alreadyPresent => l10n.routingAlreadyListed,
      RoutingRuleOutcome.rejected => l10n.routingInvalidInput,
    };

    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = SettingsPalette.of(context);
    // The rule's own colour: what this list does to traffic.
    final tone = widget.action.colorIn(palette);

    return Padding(
      padding: EdgeInsets.only(
        left: AppLayout.settingsSheetPadH.w,
        right: AppLayout.settingsSheetPadH.w,
        // Keeps the field and its button above the keyboard the field just
        // raised.
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            AppLayout.settingsSheetPadBottom.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AppSheetHandle()),
          SizedBox(height: AppLayout.settingsSheetPadTop.h),
          Row(
            children: [
              InkDialogEmblem(
                icon: _entryType == RoutingEntryType.domain
                    ? Iconsax.global
                    : Iconsax.code,
                color: tone,
              ),
              SizedBox(width: AppLayout.inkActionsGap.w),
              Expanded(
                child: InkDialogText(
                  title: l10n.routingAddRule,
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
          SizedBox(height: AppLayout.inkDialogSectionGap.h),
          InkSegmented<RoutingEntryType>(
            accent: palette.accent,
            selected: _entryType,
            onChanged: (type) => setState(() => _entryType = type),
            segments: [
              (
                value: RoutingEntryType.domain,
                icon: Iconsax.global,
                label: l10n.routingEntryDomain,
              ),
              (
                value: RoutingEntryType.ip,
                icon: Iconsax.code,
                label: l10n.routingEntryIp,
              ),
            ],
          ),
          SizedBox(height: AppLayout.settingsSheetFieldGap.h),
          TextField(
            controller: _controller,
            style: InkInput.text(context.palette),
            textDirection: TextDirection.ltr,
            cursorColor: palette.accent,
            onSubmitted: (_) => _save(),
            decoration: InkInput.decoration(
              context.palette,
              accent: palette.accent,
              hint: _entryType == RoutingEntryType.domain
                  ? l10n.routingDomainHint
                  : l10n.routingIpHint,
            ),
          ),
          SizedBox(height: AppLayout.inkDialogActionsGap.h),
          InkFilledButton(
            label: l10n.save,
            color: palette.accent,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
