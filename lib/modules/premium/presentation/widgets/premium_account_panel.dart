import 'dart:async';

import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/core/errors/error_presentation.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/support/support_link.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/l10n/localized_date.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/domain/premium_connect_validation.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_devices_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_purchase_launcher.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_devices_state.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_buttons.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_delete_account_dialog.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_device_row.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_pass_card.dart';
import 'package:begzar/modules/premium/presentation/widgets/purchase_destination_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// Signed-in account: the pass, the two account actions, the devices and the
/// binding note, stacked straight on the page.
class PremiumAccountPanel extends ConsumerStatefulWidget {
  const PremiumAccountPanel({
    super.key,
    required this.state,
    required this.accent,
  });

  final PremiumState state;
  final PremiumAccent accent;

  @override
  ConsumerState<PremiumAccountPanel> createState() =>
      _PremiumAccountPanelState();
}

class _PremiumAccountPanelState extends ConsumerState<PremiumAccountPanel> {
  static const _expiringSoonDays = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(premiumDevicesProvider.notifier).loadIfNeeded(force: true);
    });
  }

  /// A never-paid or lapsed account is offered the way to buy on the pass
  /// itself. Where the tap goes is the launcher's answer — the paywall on a
  /// Play build, the bot or the website elsewhere — so the pass never decides
  /// that for itself. A disabled account is support's to answer, not a
  /// purchase's.
  bool _offersPurchase(PremiumConnectValidation standing) =>
      standing == PremiumConnectValidation.notSubscribed ||
      standing == PremiumConnectValidation.subscriptionExpired;

  /// Runs [action], then raises the error toast for the reason it left on the
  /// account, if it left one.
  ///
  /// Read back from the state rather than returned: the controller publishes
  /// every refusal there, and the connect gate reads a failed entitlement
  /// check the same way.
  Future<void> _reportRefusal(Future<void> Function() action) async {
    await action();
    // A sign-out that went through has already swapped this panel for the
    // sign-in form.
    if (!mounted) return;
    final errorKey = ref.read(premiumProvider).errorMessage;
    if (errorKey != null) showTopErrorPopup(context, errorKey);
  }

  /// Re-reads the subscription and, beside it, the devices: the one Refresh
  /// on the tab covers both, so there is no second control for the list.
  Future<void> _refresh() async {
    unawaited(
      ref.read(premiumDevicesProvider.notifier).loadIfNeeded(force: true),
    );
    await ref.read(premiumProvider.notifier).refreshSubscription();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devicesState = ref.watch(premiumDevicesProvider);
    final standing = _standing();
    final busy = widget.state.isLoading || widget.state.isLoggingOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pass(l10n, standing, busy),
        SizedBox(height: AppLayout.premiumActionsTopGap.h),
        Row(
          children: [
            Expanded(
              child: PremiumSecondaryButton(
                label: l10n.refresh,
                icon: Iconsax.refresh,
                onPressed: busy ? null : () => _reportRefusal(_refresh),
              ),
            ),
            SizedBox(width: AppLayout.premiumActionsColumnGap.w),
            Expanded(
              child: PremiumSecondaryButton(
                label: widget.state.isLoggingOut
                    ? l10n.signingOut
                    : l10n.signOut,
                icon: Iconsax.logout,
                isLoading: widget.state.isLoggingOut,
                isDestructive: true,
                onPressed: busy
                    ? null
                    : () => _reportRefusal(
                        ref.read(premiumProvider.notifier).logout,
                      ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppLayout.premiumActionsBottomGap.h),
        _DevicesHeader(state: devicesState),
        SizedBox(height: AppLayout.premiumSectionHeadGap.h),
        _DevicesBody(state: devicesState),
        SizedBox(height: AppLayout.premiumNoteTopGap.h),
        _DeviceBindingNote(text: l10n.deviceBindingInfo),
        SizedBox(height: AppLayout.premiumDangerTopGap.h),
        _DeleteAccountButton(
          label: l10n.deleteAccount,
          onPressed: busy
              ? null
              : () => showDeleteAccountDialog(context, widget.accent),
        ),
      ],
    );
  }

  Widget _pass(
    AppLocalizations l10n,
    PremiumConnectValidation standing,
    bool busy,
  ) {
    final username = widget.state.username ?? l10n.unknown;
    final email = widget.state.account?.email;

    switch (standing) {
      case PremiumConnectValidation.allowed:
        return PremiumPassCard(
          tone: PremiumPassTone.entitled,
          planLabel: l10n.planPremium,
          username: username,
          email: email,
          statusLabel: l10n.translateUserStatus(widget.state.userStatus),
          isBusy: busy,
          body: _EntitledFigure(
            daysLeft: _daysLeft(),
            expiry: _formattedExpiry(l10n.localeName),
            expiringSoonDays: _expiringSoonDays,
          ),
        );
      case PremiumConnectValidation.notSubscribed:
        return PremiumPassCard(
          tone: PremiumPassTone.open,
          planLabel: l10n.planBasic,
          username: username,
          email: email,
          tierLabel: l10n.planFree,
          isBusy: busy,
          body: _PassMessage(
            title: l10n.premiumNoSubscription,
            hint: l10n.premiumNoSubscriptionHintFor(Theme.of(context).platform),
            action: _purchaseButton(l10n, standing, busy),
          ),
        );
      case PremiumConnectValidation.subscriptionExpired:
        return PremiumPassCard(
          tone: PremiumPassTone.lapsed,
          planLabel: l10n.planPremium,
          username: username,
          email: email,
          statusLabel: l10n.expired,
          isBusy: busy,
          body: _PassMessage(
            title: l10n.premiumAccountInactive,
            hint: l10n.premiumExpiredHint,
            action: _purchaseButton(l10n, standing, busy),
          ),
        );
      case PremiumConnectValidation.accountInactive:
      case PremiumConnectValidation.notLoggedIn:
      case PremiumConnectValidation.skipped:
      case PremiumConnectValidation.checkFailed:
        return PremiumPassCard(
          tone: PremiumPassTone.lapsed,
          planLabel: l10n.planPremium,
          username: username,
          email: email,
          statusLabel: l10n.translateUserStatus('inactive'),
          isBusy: busy,
          body: _PassMessage(
            title: l10n.premiumAccountInactive,
            hint: l10n.premiumInactiveHint,
            action: SupportLink(message: l10n.premiumSupportMessage),
          ),
        );
    }
  }

  /// In the colour the tab sells in, not the account's: a lapsed pass is
  /// red, and renewing is not a destructive act.
  Widget? _purchaseButton(
    AppLocalizations l10n,
    PremiumConnectValidation standing,
    bool busy,
  ) {
    if (!_offersPurchase(standing)) return null;
    final renewal = standing == PremiumConnectValidation.subscriptionExpired;

    return PremiumPrimaryButton(
      label: renewal ? l10n.renewSubscription : l10n.buyPremium,
      accent: PremiumAccent.signedOut(PremiumPalette.of(context)),
      compact: true,
      leading: PurchaseDestinationMark(size: AppLayout.premiumCtaGlyph.sp),
      onPressed: busy
          ? null
          : () => unawaited(
              ref.read(premiumPurchaseLauncherProvider).open(renewal: renewal),
            ),
    );
  }

  /// Where the account stands, by the rule the connect gate uses, so the
  /// panel and the gate never disagree about it — a disabled account reads
  /// as disabled here even when it has never paid.
  PremiumConnectValidation _standing() {
    final account = widget.state.account;
    if (account == null) return PremiumConnectValidation.notLoggedIn;
    return PremiumConnectValidation.forAccount(account);
  }

  DateTime? _expiresAt() {
    final raw = widget.state.expireDate;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int? _daysLeft() => _expiresAt()?.difference(DateTime.now()).inDays;

  String _formattedExpiry(String localeName) {
    final date = _expiresAt();
    if (date == null) return widget.state.expireDate ?? '-';
    return LocalizedDate.day(date.toLocal(), localeName);
  }
}

/// The entitled pass's reading: the days left large, and the date they run
/// out on beside them.
class _EntitledFigure extends StatelessWidget {
  const _EntitledFigure({
    required this.daysLeft,
    required this.expiry,
    required this.expiringSoonDays,
  });

  final int? daysLeft;
  final String expiry;
  final int expiringSoonDays;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    final days = daysLeft;
    final expiringSoon = days != null && days <= expiringSoonDays;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                days == null
                    ? l10n.unknown
                    : NumberFormat.decimalPattern(l10n.localeName).format(days),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: displayFamilyOf(context),
                  fontSize: AppLayout.premiumPassFigure.sp,
                  fontWeight: FontWeight.w600,
                  height: AppLayout.premiumPassFigureLineHeight,
                  letterSpacing: AppLayout.premiumPassFigureTracking,
                  color: expiringSoon ? palette.offerRenew : palette.accent,
                ),
              ),
              SizedBox(height: AppLayout.premiumPassCaptionGap.h),
              Text(
                l10n.remaining,
                style: TextStyle(
                  fontSize: AppLayout.premiumPassCaption.sp,
                  fontWeight: FontWeight.w500,
                  color: PremiumPassCaption.of(
                    context,
                  ).withValues(alpha: PremiumPalette.passCaptionAlpha),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: AppLayout.premiumAccountGap.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.expires,
              style: TextStyle(
                fontSize: AppLayout.premiumPassCaption.sp,
                color: PremiumPassCaption.of(
                  context,
                ).withValues(alpha: PremiumPalette.passDateCaptionAlpha),
              ),
            ),
            SizedBox(height: AppLayout.premiumPassDateGap.h),
            Text(
              expiry,
              style: TextStyle(
                fontFamily: monoFamilyOf(context),
                fontSize: AppLayout.premiumPassDate.sp,
                fontWeight: FontWeight.w500,
                color: palette.inkText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// What a pass without a live subscription says: where the account stands,
/// one line on what to do, and the way to do it.
class _PassMessage extends StatelessWidget {
  const _PassMessage({required this.title, required this.hint, this.action});

  final String title;
  final String hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: AppLayout.premiumPassTitleTopGap.h),
        Text(
          title,
          style: TextStyle(
            fontFamily: displayFamilyOf(context),
            fontSize: AppLayout.premiumPassTitle.sp,
            fontWeight: FontWeight.w600,
            color: palette.inkText,
          ),
        ),
        SizedBox(height: AppLayout.premiumPassTitleGap.h),
        Text(
          hint,
          style: TextStyle(
            fontSize: AppLayout.premiumPassSub.sp,
            color: palette.inkMuted,
          ),
        ),
        if (action != null) ...[
          SizedBox(height: AppLayout.premiumPassCtaTopGap.h),
          action!,
        ],
      ],
    );
  }
}

class _DevicesHeader extends StatelessWidget {
  const _DevicesHeader({required this.state});

  final PremiumDevicesState state;

  /// More seats than this and the meter would outgrow the row; the count
  /// beside it says the same thing.
  static const _maxSeatsDrawn = 6;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    final active = state.activeDevices;
    final max = state.maxDevices;
    final showCount = state.hasLoaded && active != null && max != null;
    final numbers = NumberFormat.decimalPattern(l10n.localeName);

    // Inset as far as the cards' contents are: the title over their glyphs,
    // the count ending with their chips. Run to the cards' outer edge, the
    // meter passed their rounded corners and read as wider than the cards.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.premiumDeviceCardPad.w,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.linkedDevices,
              style: TextStyle(
                fontSize: AppLayout.premiumSectionHead.sp,
                fontWeight: FontWeight.w600,
                color: palette.inkText,
              ),
            ),
          ),
          if (state.isLoading)
            SizedBox.square(
              dimension: AppLayout.premiumAccountTick.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.inkFaint,
              ),
            )
          else if (showCount) ...[
            if (max > 0 && max <= _maxSeatsDrawn) ...[
              _SeatMeter(active: active, max: max),
              SizedBox(width: AppLayout.premiumSlotsLabelGap.w),
            ],
            Text(
              '${numbers.format(active)} / ${numbers.format(max)}',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: monoFamilyOf(context),
                fontSize: AppLayout.premiumSlotsLabel.sp,
                color: palette.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One short bar per seat on the account, lit for each one taken.
class _SeatMeter extends StatelessWidget {
  const _SeatMeter({required this.active, required this.max});

  final int active;
  final int max;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var seat = 0; seat < max; seat++) ...[
          if (seat > 0) SizedBox(width: AppLayout.premiumSlotGap.w),
          Container(
            width: AppLayout.premiumSlotWidth.w,
            height: AppLayout.premiumSlotHeight.h,
            decoration: BoxDecoration(
              color: seat < active ? palette.good : palette.inkLineStrong,
              borderRadius: BorderRadius.circular(
                AppLayout.premiumSlotRadius.r,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DevicesBody extends ConsumerWidget {
  const _DevicesBody({required this.state});

  final PremiumDevicesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;

    if (state.isLoading && !state.hasLoaded) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppLayout.premiumAccountActionPadV.h,
        ),
        child: Center(
          child: SizedBox(
            width: AppLayout.premiumAccountSpinner.w,
            height: AppLayout.premiumAccountSpinner.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.inkFaint,
            ),
          ),
        ),
      );
    }

    // An empty list that failed to load says which list it is and offers the
    // retry, but not the reason: the tab's Refresh reloads it, and the error
    // toast already reports why. Repeating the reason here showed one
    // failure twice.
    if (state.errorMessage != null && state.devices.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InlineMessage(errorKey: UserFacingErrorKeys.loadDevices),
          SizedBox(height: AppLayout.premiumAccountNoteGap.h),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref
                  .read(premiumDevicesProvider.notifier)
                  .loadIfNeeded(force: true),
              style: TextButton.styleFrom(
                foregroundColor: palette.inkMuted,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.tryAgain,
                style: TextStyle(fontSize: AppLayout.textBase.sp),
              ),
            ),
          ),
        ],
      );
    }

    if (state.devices.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: AppLayout.premiumAccountSecondaryPadV.h,
        ),
        child: Text(
          l10n.noLinkedDevices,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppLayout.textBase.sp,
            color: palette.inkFaint,
          ),
        ),
      );
    }

    final devices = _currentFirst(state);

    // A reload that failed over a list already shown keeps the list and says
    // nothing here: the tab's one Refresh reloads it, and the error toast
    // already reports that refusal. Printing it above the list as well
    // showed one failure twice.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, device) in devices.indexed) ...[
          if (index > 0) SizedBox(height: AppLayout.premiumDeviceListGap.h),
          PremiumDeviceRow(
            device: device,
            isCurrent: device.deviceId == state.currentDeviceId,
            isRemoving: state.removingDeviceId == device.deviceId,
            canRemove:
                device.deviceId != state.currentDeviceId &&
                state.removingDeviceId == null,
          ),
        ],
      ],
    );
  }

  List<PremiumDevice> _currentFirst(PremiumDevicesState state) {
    return [...state.devices]..sort((a, b) {
      final aCurrent = a.deviceId == state.currentDeviceId;
      final bCurrent = b.deviceId == state.currentDeviceId;
      if (aCurrent == bCurrent) return 0;
      return aCurrent ? -1 : 1;
    });
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.errorKey});

  final String? errorKey;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    final error = ErrorPresentation.fromKey(errorKey, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          error.message,
          style: TextStyle(
            fontSize: AppLayout.textMd.sp,
            color: palette.danger,
          ),
        ),
        if (error.hint != null) ...[
          SizedBox(height: AppLayout.premiumAccountLabelGap.h),
          Text(
            error.hint!,
            style: TextStyle(
              fontSize: AppLayout.textMd.sp,
              color: palette.danger.withValues(
                alpha: PremiumPalette.dangerRestAlpha,
              ),
            ),
          ),
        ],
        if (error.showPremiumHelp) ...[
          SizedBox(height: AppLayout.premiumAccountHintGap.h),
          SupportLink(message: l10n.premiumSupportMessage),
        ],
      ],
    );
  }
}

/// The note on what binding to a device means, in a recessed well with the
/// shield that says it is a protection rather than a warning.
class _DeviceBindingNote extends StatelessWidget {
  const _DeviceBindingNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.premiumNotePadH.w,
        vertical: AppLayout.premiumNotePadV.h,
      ),
      decoration: BoxDecoration(
        color: palette.pageInk,
        borderRadius: BorderRadius.circular(AppLayout.premiumNoteRadius.r),
        border: Border.all(color: palette.inkLineStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Iconsax.shield_tick_copy,
            color: palette.accent,
            size: AppLayout.premiumNoteGlyph.sp,
          ),
          SizedBox(width: AppLayout.premiumNoteGap.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppLayout.premiumNoteLabel.sp,
                color: palette.inkMuted,
                height: AppLayout.premiumNoteLineHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deleting the account: the tab's last and quietest control, which the
/// dialog it opens then makes plain.
class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final tone = palette.danger.withValues(
      alpha: onPressed == null
          ? PremiumPalette.disabledAlpha
          : PremiumPalette.dangerRestAlpha,
    );

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(Iconsax.trash, size: AppLayout.premiumDangerGlyph.sp),
      label: Text(
        label,
        style: TextStyle(
          fontSize: AppLayout.premiumDangerLabel.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: tone,
        disabledForegroundColor: tone,
        overlayColor: palette.danger.withValues(
          alpha: PremiumPalette.dangerPressAlpha,
        ),
        minimumSize: Size.fromHeight(AppLayout.premiumDangerHeight.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.premiumDangerRadius.r),
        ),
      ),
    );
  }
}
