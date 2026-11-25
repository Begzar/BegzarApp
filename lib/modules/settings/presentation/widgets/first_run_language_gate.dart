import 'dart:async';

import 'package:begzar/core/domain/surface_mood.dart';
import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/app_theme.dart';
import 'package:begzar/core/widgets/app_buttons.dart';
import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/l10n/locale_provider.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';
import 'package:begzar/modules/settings/presentation/widgets/language_dropdown.dart';
import 'package:begzar/modules/settings/presentation/widgets/settings_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Asks for the app's language once, before anything else is shown.
///
/// It stands in front of the notification permission gate, so that request —
/// the first thing a new install asks of anyone — arrives in a language its
/// reader picked. Once a language is saved, here or in Settings, the gate
/// passes straight through.
///
/// The language dropdown Settings uses, with the device's own language picked
/// already — or English where the app has no translation for it — so most
/// people only have to continue. Nothing is saved until they do. A device
/// already in Persian is not asked at all; see [AppLanguage.firstRunAsks].
class FirstRunLanguageGate extends ConsumerStatefulWidget {
  const FirstRunLanguageGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FirstRunLanguageGate> createState() =>
      _FirstRunLanguageGateState();
}

enum _Stage { deciding, asking, done }

class _FirstRunLanguageGateState extends ConsumerState<FirstRunLanguageGate> {
  _Stage _stage = _Stage.deciding;

  /// Set before the screen is first shown, and only read while it is.
  late AppLanguage _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // `main` read storage before the first frame, so anyone who has picked is
    // known here without waiting and never sees this screen, even for a frame.
    if (ref.read(localeProvider.notifier).hasSavedLanguage) {
      _stage = _Stage.done;
    } else {
      unawaited(_decide());
    }
  }

  Future<void> _decide() async {
    final locale = ref.read(localeProvider.notifier);
    try {
      await locale.ensureLoaded();
    } catch (_) {
      // A store that cannot be read cannot keep an answer either, so asking
      // would only ask again next launch — and waiting on it would leave this
      // screen blank for good. The app opens in the device's language.
      if (mounted) setState(() => _stage = _Stage.done);
      return;
    }
    if (!mounted) return;
    if (locale.hasSavedLanguage) {
      setState(() => _stage = _Stage.done);
      return;
    }

    final device = AppLanguage.forDevice(
      WidgetsBinding.instance.platformDispatcher.locale,
    );
    if (!AppLanguage.firstRunAsks(device)) {
      await _choose(device);
      return;
    }
    setState(() {
      _selected = device;
      _stage = _Stage.asking;
    });
    // The question is a screen of its own, with no home dial for the launch
    // cover to land on.
    ref.read(launchCoverProvider.notifier).dismiss();
  }

  Future<void> _choose(AppLanguage language) async {
    if (_saving) return;
    _saving = true;
    try {
      await ref.read(localeProvider.notifier).setLanguage(language);
    } finally {
      // The language is applied before it is written, so even a write that
      // fails has changed it for this run. Move on either way; a write that
      // did not land only means the question is asked again next launch.
      if (mounted) setState(() => _stage = _Stage.done);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.done => widget.child,
      _Stage.deciding => const _Backdrop(),
      _Stage.asking => _FirstRunLanguageScreen(
        selected: _selected,
        onSelected: (language) => setState(() => _selected = language),
        onContinue: () => _choose(_selected),
      ),
    };
  }
}

/// The page gradient every screen paints, with nothing on it yet.
class _Backdrop extends StatelessWidget {
  const _Backdrop({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: context.palette.pageGradient(SurfaceMood.idle),
        ),
        child: SafeArea(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// The question itself.
///
/// Everything on it follows the language picked, so the screen previews the
/// app in it before it is saved. The question and the hint also come in
/// English, one line each beneath, for anyone who does not read the pick —
/// the device's language, at first. Every line is set in its own language's
/// face and direction rather than the app's, which is still whatever the
/// device was in. The dropdown is the one Settings shows, in the same card,
/// so the control met here is the control found again there.
///
/// Nothing on it is laid out to a side. It is one centred column, so it reads
/// the same whichever language the app is in when it appears.
class _FirstRunLanguageScreen extends StatelessWidget {
  const _FirstRunLanguageScreen({
    required this.selected,
    required this.onSelected,
    required this.onContinue,
  });

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelected;
  final VoidCallback onContinue;

  /// Keeps the column phone-sized on a desktop window. Logical pixels, not
  /// design units, and inside the insets: on a phone the insets already hold
  /// the column narrower than this, so it spans what the permission gate's
  /// button does.
  static const _maxWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    final askedIn = AppLanguage.firstRunQuestionLanguages(selected);
    final palette = SettingsPalette.of(context);

    return _Backdrop(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppLayout.firstRunLanguageInsetH.w,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _Mark()),
                SizedBox(height: AppLayout.firstRunLanguageMarkToTitle.h),
                for (final (index, language) in askedIn.indexed) ...[
                  if (index > 0)
                    SizedBox(height: AppLayout.firstRunLanguageTitleGap.h),
                  _InLanguage(
                    language: language,
                    text: (l10n) => l10n.languageDialogTitle,
                    style: index == 0
                        ? TextStyle(
                            color: palette.textPrimary,
                            fontSize: AppLayout.firstRunLanguageTitle.sp,
                            fontWeight: FontWeight.w700,
                          )
                        : TextStyle(
                            color: palette.textSecondary,
                            fontSize: AppLayout.firstRunLanguageSubtitle.sp,
                            fontWeight: FontWeight.w500,
                          ),
                  ),
                ],
                SizedBox(height: AppLayout.firstRunLanguageTitleToPicker.h),
                _InPickedLanguage(
                  language: selected,
                  // A builder, so the button's label is read in the picked
                  // language rather than in the one the screen opened in.
                  child: Builder(
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsGlassPanel(
                          style: SettingsGlass.panel(
                            palette,
                            cornerRadius: AppLayout.settingsTabRadius.r,
                          ),
                          child: LanguageDropdown(
                            selected: selected,
                            onSelected: onSelected,
                          ),
                        ),
                        SizedBox(
                          height: AppLayout.firstRunLanguagePickerToAction.h,
                        ),
                        AppPrimaryButton(
                          label: context.l10n.languageContinue,
                          color: palette.firstRunAction,
                          onColor: palette.onFirstRunAction,
                          onPressed: onContinue,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppLayout.firstRunLanguageActionToHint.h),
                for (final (index, language) in askedIn.indexed) ...[
                  if (index > 0)
                    SizedBox(height: AppLayout.firstRunLanguageHintGap.h),
                  _InLanguage(
                    language: language,
                    text: (l10n) => l10n.languageChoiceHint,
                    style: TextStyle(
                      color: palette.textTertiary,
                      fontSize: AppLayout.firstRunLanguageHint.sp,
                      height: AppLayout.firstRunLanguageHintLineHeight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The globe on its disc, drawn as the permission gate draws its bell.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    final palette = SettingsPalette.of(context);

    return Container(
      width: AppLayout.firstRunLanguageMarkSize.w,
      height: AppLayout.firstRunLanguageMarkSize.w,
      decoration: BoxDecoration(
        color: palette.firstRunMarkFill,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Iconsax.global_copy,
        color: palette.firstRunMark,
        size: AppLayout.firstRunLanguageMarkGlyph.sp,
      ),
    );
  }
}

/// One line of copy in [language], whatever language the app is in.
class _InLanguage extends StatelessWidget {
  const _InLanguage({
    required this.language,
    required this.text,
    required this.style,
  });

  final AppLanguage language;
  final String Function(AppLocalizations l10n) text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text(lookupAppLocalizations(language.locale)),
      textAlign: TextAlign.center,
      textDirection: language.textDirection,
      locale: language.locale,
      style: style.copyWith(fontFamily: appFontFamilyFor(language.locale)),
    );
  }
}

/// [child] as the app will look in [language] once it is saved: its strings,
/// its face and its direction.
///
/// The picked language is not applied until the reader continues, so the
/// rest of the app is still in the device's. Without this, the field and the
/// button under a Persian pick would still speak English, and the screen
/// would hold three languages at once.
class _InPickedLanguage extends StatelessWidget {
  const _InPickedLanguage({required this.language, required this.child});

  final AppLanguage language;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: language.locale,
      // The theme the app is in, re-set in the picked language's face.
      child: Theme(
        data: AppTheme.forBrightness(
          Theme.of(context).brightness,
          fontFamily: appFontFamilyFor(language.locale),
        ),
        child: child,
      ),
    );
  }
}
