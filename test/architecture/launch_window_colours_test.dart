import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:begzar/core/theme/app_palette.dart';
import 'package:flutter_test/flutter_test.dart';

/// The launch window is drawn by the platform before Dart runs, so its ground
/// is written into native resources rather than read from [AppPalette]. It
/// has to be the page the first frame paints, or the handover flashes; this
/// reads the native files and holds them to the palette.

const _androidDay = 'android/app/src/main/res/values/colors.xml';
const _androidNight = 'android/app/src/main/res/values-night/colors.xml';
const _appleColourSet =
    'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json';

/// The `splash_background` an Android colours file names.
Color _androidSplashBackground(String path) {
  final match = RegExp(
    r'<color name="splash_background">#([0-9A-Fa-f]{8})</color>',
  ).firstMatch(File(path).readAsStringSync());
  expect(match, isNotNull, reason: '$path names no splash_background');
  return Color(int.parse(match!.group(1)!, radix: 16));
}

/// The colour an Apple colour set holds for an appearance: `null` for the
/// default one, `dark` for dark.
Color _appleLaunchBackground(String? luminosity) {
  final contents =
      jsonDecode(File(_appleColourSet).readAsStringSync())
          as Map<String, dynamic>;
  final entry = (contents['colors'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((entry) {
        final appearances = (entry['appearances'] as List?) ?? const [];
        final named = appearances.cast<Map<String, dynamic>>().map(
          (appearance) => appearance['value'],
        );
        return luminosity == null ? named.isEmpty : named.contains(luminosity);
      });
  final components =
      (entry['color'] as Map<String, dynamic>)['components']
          as Map<String, dynamic>;
  int channel(String name) => int.parse(components[name] as String);
  return Color.fromARGB(
    0xFF,
    channel('red'),
    channel('green'),
    channel('blue'),
  );
}

void main() {
  group('Launch window colours', () {
    test('should ground Android in the light page by day', () {
      expect(_androidSplashBackground(_androidDay), AppPalette.light.page);
    });

    test('should ground Android in the dark page by night', () {
      expect(_androidSplashBackground(_androidNight), AppPalette.dark.page);
    });

    test('should ground iOS in the light page in the light appearance', () {
      expect(_appleLaunchBackground(null), AppPalette.light.page);
    });

    test('should ground iOS in the dark page in the dark appearance', () {
      expect(_appleLaunchBackground('dark'), AppPalette.dark.page);
    });
  });
}
