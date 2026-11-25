import 'dart:async';

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/services/native_url_launcher.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/domain/sign_up.dart';
import 'package:begzar/modules/premium/presentation/controllers/sign_up_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/sign_up_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_buttons.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_field_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Where creating an account sends the reader to read what is kept about them.
const _privacyPolicyUrl = 'https://begzar.app/privacy';

/// Creating an account, in the place the sign-in form stands: the details,
/// then the code that was emailed. The switch above it goes back to signing
/// in.
class PremiumSignUpSection extends ConsumerStatefulWidget {
  const PremiumSignUpSection({
    super.key,
    required this.accent,
    this.emailController,
  });

  final PremiumAccent accent;

  /// The email field's text, when whoever raises this section keeps it —
  /// the sign-in form does, so an address survives switching away and back
  /// and can be handed between the two forms. Left null, the section keeps
  /// its own, and disposes of it.
  final TextEditingController? emailController;

  @override
  ConsumerState<PremiumSignUpSection> createState() =>
      _PremiumSignUpSectionState();
}

class _PremiumSignUpSectionState extends ConsumerState<PremiumSignUpSection>
    with PremiumFieldReveal<PremiumSignUpSection> {
  /// The resend countdown is shown in whole seconds, so it only has to be
  /// redrawn once a second.
  static const _countdownTick = Duration(seconds: 1);

  /// The palette the section's helpers draw in, read from the theme it sits
  /// in.
  PremiumPalette get palette => PremiumPalette.of(context);

  late final TextEditingController _emailController =
      widget.emailController ?? TextEditingController();
  late final bool _ownsEmailController = widget.emailController == null;
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();
  final _codeFocus = FocusNode();
  bool _obscurePassword = true;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    revealWhenFocused([
      _emailFocus,
      _passwordFocus,
      _confirmationFocus,
      _codeFocus,
    ]);
    _countdown = Timer.periodic(_countdownTick, (_) {
      if (ref.read(signUpProvider).step == SignUpStep.code) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    if (_ownsEmailController) _emailController.dispose();
    for (final controller in [
      _passwordController,
      _confirmationController,
      _codeController,
    ]) {
      controller.dispose();
    }
    for (final node in [
      _emailFocus,
      _passwordFocus,
      _confirmationFocus,
      _codeFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  void _submitDetails() {
    FocusScope.of(context).unfocus();
    ref
        .read(signUpProvider.notifier)
        .submitDetails(
          email: _emailController.text,
          password: _passwordController.text,
          confirmation: _confirmationController.text,
        );
  }

  void _verify() {
    FocusScope.of(context).unfocus();
    ref.read(signUpProvider.notifier).verify(_codeController.text);
  }

  void _editEmail() {
    _codeController.clear();
    ref.read(signUpProvider.notifier).editEmail();
  }

  /// Whole seconds until another code may be asked for, or zero once it may.
  int _secondsUntilResend(SignUpState state) {
    final availableAt = state.resendAvailableAt;
    if (availableAt == null) return 0;
    final remaining = availableAt.difference(DateTime.now());
    if (remaining.isNegative) return 0;
    return (remaining.inMilliseconds / Duration.millisecondsPerSecond).ceil();
  }

  String? _fieldErrorText(
    AppLocalizations l10n,
    SignUpFieldError? error,
    SignUpFieldError owner,
  ) {
    if (error != owner) return null;
    return switch (owner) {
      SignUpFieldError.emailInvalid => l10n.errEmailFormat,
      SignUpFieldError.passwordTooShort => l10n.errPasswordLength(
        SignUpDetails.minimumPasswordLength,
      ),
      SignUpFieldError.passwordMismatch => l10n.errPasswordMismatch,
      SignUpFieldError.codeFormat => l10n.errCodeFormat,
    };
  }

  Widget _passwordVisibilityToggle() {
    return PremiumPasswordEye(
      obscured: _obscurePassword,
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
    );
  }

  List<Widget> _detailsStep(AppLocalizations l10n, SignUpState state) {
    return [
      PremiumTextField(
        controller: _emailController,
        focusNode: _emailFocus,
        label: l10n.email,
        icon: Iconsax.sms,
        accent: widget.accent,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textDirection: TextDirection.ltr,
        errorText: _fieldErrorText(
          l10n,
          state.fieldError,
          SignUpFieldError.emailInvalid,
        ),
        textInputAction: TextInputAction.next,
        onSubmitted: _passwordFocus.requestFocus,
      ),
      SizedBox(height: AppLayout.premiumFieldGap.h),
      PremiumTextField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        label: l10n.password,
        icon: Iconsax.lock,
        accent: widget.accent,
        obscureText: _obscurePassword,
        suffix: _passwordVisibilityToggle(),
        autofillHints: const [AutofillHints.newPassword],
        errorText: _fieldErrorText(
          l10n,
          state.fieldError,
          SignUpFieldError.passwordTooShort,
        ),
        // Redraws the strength meter under the field.
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.next,
        onSubmitted: _confirmationFocus.requestFocus,
      ),
      SizedBox(height: AppLayout.premiumFieldGap.h),
      _StrengthMeter(password: _passwordController.text),
      SizedBox(height: AppLayout.premiumFieldGap.h),
      PremiumTextField(
        controller: _confirmationController,
        focusNode: _confirmationFocus,
        label: l10n.confirmPassword,
        icon: Iconsax.lock,
        accent: widget.accent,
        obscureText: _obscurePassword,
        autofillHints: const [AutofillHints.newPassword],
        errorText: _fieldErrorText(
          l10n,
          state.fieldError,
          SignUpFieldError.passwordMismatch,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: _submitDetails,
      ),
      SizedBox(height: AppLayout.premiumCtaTopGap.h),
      PremiumPrimaryButton(
        label: state.isSubmitting ? l10n.creatingAccount : l10n.createAccount,
        accent: widget.accent,
        onPressed: state.isSubmitting ? null : _submitDetails,
      ),
      SizedBox(height: AppLayout.premiumMeterGap.h),
      TextButton(
        onPressed: () => NativeUrlLauncher.open(_privacyPolicyUrl),
        style: TextButton.styleFrom(foregroundColor: palette.inkMuted),
        child: Text(
          l10n.signUpPrivacyNotice,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppLayout.premiumFine.sp,
            height: AppLayout.premiumSubLineHeight,
            decoration: TextDecoration.underline,
            decorationColor: palette.inkMuted,
          ),
        ),
      ),
    ];
  }

  List<Widget> _codeStep(AppLocalizations l10n, SignUpState state) {
    final secondsUntilResend = _secondsUntilResend(state);

    return [
      // The line sits where the locale starts; the address inside it always
      // reads left to right.
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          state.email ?? '',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontSize: AppLayout.textLg.sp,
            fontWeight: FontWeight.w600,
            color: widget.accent.primary,
          ),
        ),
      ),
      SizedBox(height: AppLayout.premiumSegmentBottomGap.h),
      PremiumTextField(
        controller: _codeController,
        focusNode: _codeFocus,
        label: l10n.confirmationCode,
        icon: Iconsax.password_check,
        accent: widget.accent,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        textDirection: TextDirection.ltr,
        errorText: _fieldErrorText(
          l10n,
          state.fieldError,
          SignUpFieldError.codeFormat,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: _verify,
      ),
      SizedBox(height: AppLayout.premiumCtaTopGap.h),
      PremiumPrimaryButton(
        label: state.isSubmitting ? l10n.confirmingCode : l10n.confirmCode,
        accent: widget.accent,
        onPressed: state.isSubmitting ? null : _verify,
      ),
      PremiumTextLink(
        label: secondsUntilResend > 0
            ? l10n.resendCodeIn(secondsUntilResend)
            : l10n.resendCode,
        color: widget.accent.primary,
        onPressed: secondsUntilResend > 0 || state.isSubmitting
            ? null
            : ref.read(signUpProvider.notifier).resendCode,
      ),
      PremiumTextLink(
        label: l10n.changeEmail,
        color: widget.accent.primary,
        onPressed: state.isSubmitting ? null : _editEmail,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(signUpProvider);
    // Every try clears the last refusal before it asks, so each refusal
    // arrives as a change, the same one twice included.
    ref.listen(signUpProvider.select((signUpState) => signUpState.errorKey), (
      _,
      errorKey,
    ) {
      if (errorKey != null) showTopErrorPopup(context, errorKey);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (state.step) {
        SignUpStep.details => _detailsStep(l10n, state),
        SignUpStep.code => _codeStep(l10n, state),
      },
    );
  }
}

/// Four bars under the new password, lit by how hard it would be to guess.
///
/// A nudge, not a rule: the only thing the server refuses is a password
/// shorter than [SignUpDetails.minimumPasswordLength], and the field says
/// that itself when it happens.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.password});

  final String password;

  static const _bars = 4;
  static final _lower = RegExp('[a-z]');
  static final _upper = RegExp('[A-Z]');
  static final _digit = RegExp(r'\d');
  static final _symbol = RegExp(r'[^A-Za-z0-9]');

  /// Extra length, past the minimum, that a symbol has to come with before
  /// it earns the last bar.
  static const _strongMargin = 2;

  /// How many bars to light, from none for an empty field to all four.
  int get _score {
    if (password.isEmpty) return 0;
    final long = password.length >= SignUpDetails.minimumPasswordLength;
    final hasLetter = _lower.hasMatch(password) || _upper.hasMatch(password);
    var score = 1;
    if (long) score++;
    if (hasLetter && _digit.hasMatch(password)) score++;
    if (long &&
        _symbol.hasMatch(password) &&
        password.length >=
            SignUpDetails.minimumPasswordLength + _strongMargin) {
      score++;
    }
    return score > _bars ? _bars : score;
  }

  Color _colourFor(PremiumPalette palette, int score) => switch (score) {
    1 => palette.danger,
    2 => palette.accentDeep,
    3 => palette.accent,
    _ => palette.good,
  };

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final score = _score;

    // Inset as far as the field's glyph is: flat bars running to the field's
    // outer edge pass its rounded corners and read as wider than the field.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.premiumFieldPadStart.w,
      ),
      child: Row(
        children: [
          for (var bar = 0; bar < _bars; bar++) ...[
            if (bar > 0) SizedBox(width: AppLayout.premiumMeterGap.w),
            Expanded(
              child: AnimatedContainer(
                duration: PremiumPalette.stateChange,
                height: AppLayout.premiumMeterHeight.h,
                decoration: BoxDecoration(
                  color: bar < score
                      ? _colourFor(palette, score)
                      : palette.inkLineStrong,
                  borderRadius: BorderRadius.circular(AppLayout.radiusPill.r),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
