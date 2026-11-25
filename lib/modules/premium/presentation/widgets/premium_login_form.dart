import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/widgets/top_error_popup.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_notifier.dart';
import 'package:begzar/modules/premium/presentation/controllers/sign_up_notifier.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:begzar/modules/premium/presentation/states/sign_up_state.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_buttons.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_field_reveal.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_pass_card.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_segmented_switch.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_sign_up_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The signed-out half of the account screen: the emblem, the heading for
/// whichever form is showing, a switch between signing in and creating an
/// account, and the form itself.
class PremiumLoginForm extends ConsumerStatefulWidget {
  const PremiumLoginForm({
    super.key,
    required this.state,
    required this.accent,
  });

  final PremiumState state;
  final PremiumAccent accent;

  @override
  ConsumerState<PremiumLoginForm> createState() => _PremiumLoginFormState();
}

class _PremiumLoginFormState extends ConsumerState<PremiumLoginForm>
    with PremiumFieldReveal<PremiumLoginForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  /// The create-account form's email field, kept here rather than in that
  /// form so the address outlives it: switching to sign in and back finds it
  /// where it was left, and either form can hand its address to the other.
  final _signUpEmailController = TextEditingController();

  /// What the showing form's address field held when the reader arrived on
  /// it. Leaving with it unchanged means they did not type there, so there
  /// is nothing to hand over — and handing it anyway would overwrite what
  /// they did type in the other form since.
  String _arrivedWith = '';
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  /// Whether the tab is creating an account instead of signing in to one.
  /// Kept here rather than in a controller: it is which half of this form is
  /// showing, and nothing else in the app asks.
  bool _creatingAccount = false;

  @override
  void initState() {
    super.initState();
    revealWhenFocused([_usernameFocus, _passwordFocus]);
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _signUpEmailController.dispose();
    super.dispose();
  }

  /// Signs in, and raises the error toast for whatever refused it.
  ///
  /// Read back from the state once the attempt is over rather than listened
  /// for: an empty sign-in is refused with the same state each time, so a
  /// second press would change nothing a listener could hear.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(premiumProvider.notifier)
        .login(_usernameController.text, _passwordController.text);
    // A sign-in that went through has already swapped this form for the
    // account panel.
    if (!mounted) return;
    final errorKey = ref.read(premiumProvider).errorMessage;
    if (errorKey != null) showTopErrorPopup(context, errorKey);
  }

  /// Something with one `@` and text either side — loose on purpose. It
  /// only decides whether what was typed to sign in is an address worth
  /// carrying over; the sign-up form judges the address itself.
  static final _addressShape = RegExp(r'^[^@\s]+@[^@\s]+$');

  void _showCreatingAccount(bool creatingAccount) {
    // A tap on the half already showing is not a switch, and carrying would
    // run backwards.
    if (creatingAccount == _creatingAccount) return;
    FocusScope.of(context).unfocus();
    _carryAddress(toCreatingAccount: creatingAccount);
    setState(() => _creatingAccount = creatingAccount);
  }

  /// Hands the address typed in one form to the other, so nobody types the
  /// same email twice because they picked the wrong tab first.
  ///
  /// Into the create-account form only an address goes: a username in its
  /// email field would just be refused. Back the other way any address does,
  /// since signing in takes either. Nothing typed leaves the other form as it
  /// was, and passwords never travel.
  void _carryAddress({required bool toCreatingAccount}) {
    final (from, into) = toCreatingAccount
        ? (_usernameController, _signUpEmailController)
        : (_signUpEmailController, _usernameController);
    final typed = from.text.trim();
    final carries =
        typed.isNotEmpty &&
        typed != _arrivedWith.trim() &&
        typed != into.text.trim() &&
        (!toCreatingAccount || _addressShape.hasMatch(typed));

    if (carries) {
      into.value = TextEditingValue(
        text: typed,
        // The caret waits at the end, where someone correcting it would
        // start.
        selection: TextSelection.collapsed(offset: typed.length),
      );
    }
    _arrivedWith = into.text;
  }

  /// The title and line over the form, for whichever form is showing.
  (String, String) _heading(AppLocalizations l10n, SignUpStep step) {
    if (!_creatingAccount) {
      return (l10n.signInToPremium, l10n.usePremiumCredentials);
    }
    return switch (step) {
      SignUpStep.details => (l10n.createAccountTitle, l10n.createAccountHint),
      SignUpStep.code => (l10n.verifyEmailTitle, l10n.verifyEmailHint),
    };
  }

  List<Widget> _signInFields(AppLocalizations l10n) {
    final state = widget.state;
    final accent = widget.accent;

    return [
      PremiumTextField(
        controller: _usernameController,
        focusNode: _usernameFocus,
        label: l10n.emailOrUsername,
        icon: Iconsax.user,
        accent: accent,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        textDirection: TextDirection.ltr,
        textInputAction: TextInputAction.next,
        onSubmitted: _passwordFocus.requestFocus,
      ),
      SizedBox(height: AppLayout.premiumFieldGap.h),
      PremiumTextField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        label: l10n.password,
        icon: Iconsax.lock,
        accent: accent,
        obscureText: _obscurePassword,
        suffix: PremiumPasswordEye(
          obscured: _obscurePassword,
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onSubmitted: _submit,
      ),
      SizedBox(height: AppLayout.premiumCtaTopGap.h),
      PremiumPrimaryButton(
        label: state.isLoading ? l10n.signingIn : l10n.signIn,
        accent: accent,
        onPressed: state.isLoading ? null : _submit,
      ),
      SizedBox(height: AppLayout.premiumPerkTopGap.h),
      const _PremiumPerks(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = widget.accent;
    final signUp = ref.watch(signUpProvider);
    // The code step has its own way back, to the details it was sent for;
    // leaving for the sign-in form from there would strand the code.
    final onCodeStep = _creatingAccount && signUp.step == SignUpStep.code;
    final locked = widget.state.isLoading || signUp.isSubmitting;
    final (title, hint) = _heading(l10n, signUp.step);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: AppLayout.premiumEmblemTopGap.h),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _Emblem(accent: accent),
        ),
        SizedBox(height: AppLayout.premiumEmblemGap.h),
        _Eyebrow(text: l10n.premiumHeroTitle, color: accent.primary),
        SizedBox(height: AppLayout.premiumHeadingGap.h),
        PremiumFormHeading(title: title, hint: hint),
        SizedBox(height: AppLayout.premiumSubBottomGap.h),
        if (!onCodeStep) ...[
          PremiumSegmentedSwitch(
            startLabel: l10n.signIn,
            endLabel: l10n.createAccount,
            endSelected: _creatingAccount,
            onChanged: locked ? null : _showCreatingAccount,
          ),
          SizedBox(height: AppLayout.premiumSegmentBottomGap.h),
        ],
        AnimatedSwitcher(
          duration: PremiumPalette.swap,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.topStart,
            children: [...previous, ?current],
          ),
          child: _creatingAccount
              ? PremiumSignUpSection(
                  key: const ValueKey('sign-up'),
                  accent: accent,
                  emailController: _signUpEmailController,
                )
              : Column(
                  key: const ValueKey('sign-in'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _signInFields(l10n),
                ),
        ),
      ],
    );
  }
}

/// The tab's mark: a lit key-stone in two rings, the pass the form leads to.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.accent});

  final PremiumAccent accent;

  @override
  Widget build(BuildContext context) {
    final size = AppLayout.premiumEmblem.w;
    final step = AppLayout.premiumEmblemStep.w;

    BoxDecoration ring(double alpha, double radius) => BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.primary.withValues(alpha: alpha)),
    );

    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: ring(
                PremiumPalette.emblemOuterAlpha,
                AppLayout.premiumEmblemRadius.r,
              ),
            ),
          ),
          Positioned.fill(
            left: step,
            top: step,
            right: step,
            bottom: step,
            child: DecoratedBox(
              decoration: ring(
                PremiumPalette.emblemInnerAlpha,
                AppLayout.premiumEmblemMidRadius.r,
              ),
            ),
          ),
          Positioned.fill(
            left: step * 2,
            top: step * 2,
            right: step * 2,
            bottom: step * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  AppLayout.premiumEmblemCoreRadius.r,
                ),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [accent.primary, accent.secondary],
                ),
              ),
              child: Icon(
                Iconsax.crown_1,
                size: AppLayout.premiumEmblemGlyph.sp,
                color: accent.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small tracked line over the heading that names what the tab is for.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Letter-spacing pulls Persian's joined letters apart.
    final tracked = Localizations.localeOf(context).languageCode != 'fa';

    // A label, so the body face it inherits: the mono face is for readings.
    return Text(
      tracked ? text.toUpperCase() : text,
      style: TextStyle(
        fontSize: AppLayout.premiumEyebrow.sp,
        fontWeight: FontWeight.w500,
        letterSpacing: tracked ? AppLayout.premiumEyebrowTracking : null,
        color: color,
      ),
    );
  }
}

/// What Premium brings, in three dashed tiles under the sign-in button.
class _PremiumPerks extends StatelessWidget {
  const _PremiumPerks();

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final l10n = context.l10n;
    final glyph = AppLayout.premiumPerkGlyph.sp;
    final perks = <(Widget, String)>[
      (
        Icon(Iconsax.driver_2_copy, size: glyph, color: palette.accent),
        l10n.premiumPerkServers,
      ),
      (
        Icon(Iconsax.global_copy, size: glyph, color: palette.accent),
        l10n.premiumPerkStaticIp,
      ),
      (
        Icon(Iconsax.gallery_slash_copy, size: glyph, color: palette.accent),
        l10n.premiumPerkNoAds,
      ),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (mark, label)) in perks.indexed) ...[
            if (index > 0) SizedBox(width: AppLayout.premiumPerkGap.w),
            Expanded(
              child: CustomPaint(
                foregroundPainter: PremiumDashedRimPainter(
                  colour: palette.inkLineStrong,
                  radius: AppLayout.premiumPerkRadius.r,
                  dash: AppLayout.premiumPassDash.w,
                  gap: AppLayout.premiumPassDashGap.w,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.premiumPerkPadH.w,
                    vertical: AppLayout.premiumPerkPadV.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      mark,
                      SizedBox(height: AppLayout.premiumPerkGap.h),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: AppLayout.premiumPerkLabel.sp,
                          color: palette.inkMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
