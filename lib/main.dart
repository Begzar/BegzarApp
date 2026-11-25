import 'dart:io' show Platform;

import 'package:begzar/app/app.dart';
import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/core/security/security_gate.dart';
import 'package:begzar/modules/main/presentation/widgets/glass_bird.dart';
import 'package:begzar/core/services/firebase_platform.dart';
import 'package:begzar/modules/notifications/application/services/firebase_service.dart';
import 'package:begzar/app/app_initializer.dart';
import 'package:begzar/firebase_options.dart';
import 'package:begzar/l10n/initial_locale.dart';
import 'package:begzar/l10n/locale_provider.dart';
import 'package:begzar/modules/settings/data/datasources/initial_theme_mode.dart';
import 'package:begzar/modules/settings/presentation/controllers/theme_mode_notifier.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/date_symbol_data_local.dart';

/// Starts the app. [overrides] are added to the root scope's, which is how
/// `tool/fake_backend/main.dart` runs the app against an in-memory backend;
/// a release build starts from [main] and passes none.
Future<void> runBegzar({List<Override> overrides = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // One column, everywhere: the dial, the server lists and the app bar are all
  // laid out down the screen, and none of them has a landscape design to fall
  // back on.
  //
  // The manifest and the plist say the same thing, and they are the half that
  // matters at launch: the native splash is on screen before any of this runs,
  // so a device already held sideways would open the app sideways and only
  // turn once Dart got this far.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // `DateFormat` carries only English until this runs, and it does not say so:
  // it throws on the first non-English locale asked of it. The symbols are
  // compiled in rather than fetched, so this is a load and not a request.
  await initializeDateFormatting();

  await SecurityGate.enforce();

  if (isFirebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  final initialLocale = await loadInitialLocale();
  final initialThemeMode = await loadInitialThemeMode();

  // Android and iOS show the resting dial on their launch window, and the
  // app's first frames hold the same picture until it can be carried into
  // the home dial. The bird is decoded first, so no frame draws the dial
  // without it.
  final hasLaunchWindow = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (hasLaunchWindow) await GlassBird.precacheArtwork();

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(
          () => LocaleNotifier(
            initialLocale: initialLocale.locale,
            languageSaved: initialLocale.saved,
          ),
        ),
        themeModeProvider.overrideWith(
          () => ThemeModeNotifier(initial: initialThemeMode),
        ),
        launchCoverProvider.overrideWith(
          () => LaunchCoverNotifier(
            initial: hasLaunchWindow
                ? LaunchCoverPhase.covering
                : LaunchCoverPhase.done,
          ),
        ),
        ...overrides,
      ],
      child: AppInitializer(child: const App()),
    ),
  );
}

Future<void> main() => runBegzar();
