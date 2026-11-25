import 'package:begzar/app/launch_cover.dart';
import 'package:begzar/app/router/app_router.dart';
import 'package:begzar/app/themed_system_bars.dart';
import 'package:begzar/app/windows_tray_handler.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/theme/app_theme.dart';
import 'package:begzar/app/connection_lifecycle_handler.dart';
import 'package:begzar/core/widgets/dismiss_keyboard_on_tap.dart';
import 'package:begzar/modules/ads/presentation/widgets/ad_skip_warning_presenter.dart';
import 'package:begzar/modules/ads/presentation/widgets/connection_overlays.dart';
import 'package:begzar/l10n/app_locale.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/l10n/locale_provider.dart';
import 'package:begzar/modules/settings/presentation/controllers/theme_mode_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontFamily = appFontFamilyFor(locale);
    final size = MediaQuery.of(context).size;

    final isTablet = size.width > 600;
    final isLargeTablet = size.width > 900;
    final isDesktop = size.width > 1200;

    return ScreenUtilInit(
      designSize: isDesktop
          ? const Size(1440, 900)
          : isLargeTablet
          ? const Size(1024, 768)
          : isTablet
          ? const Size(768, 1024)
          : const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) {
        return MaterialApp.router(
          title: 'BegzarVPN',
          locale: locale,
          supportedLocales: AppLanguage.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(fontFamily: fontFamily),
          darkTheme: AppTheme.dark(fontFamily: fontFamily),
          themeMode: themeMode,
          routerConfig: router,
          builder: (context, child) {
            Widget tree = ConnectionLifecycleHandler(
              child: AdSkipWarningPresenter(
                child: ConnectionOverlays(child: _appBuilder(context, child)),
              ),
            );
            if (!kIsWeb && Platform.isWindows) {
              tree = WindowsTrayHandler(child: tree);
            }
            // Outermost, so nothing the app draws shows over the launch dial.
            return LaunchCover(child: tree);
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  Widget _appBuilder(BuildContext context, Widget? child) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
      child: ThemedSystemBars(
        child: DismissKeyboardOnTap(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
