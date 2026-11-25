import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tells the platform which theme the next launch window is drawn in.
///
/// The launch window is up before Dart runs, so it cannot read the stored
/// pick; on its own it follows the phone. Android 12 and up lets an app set
/// its own night mode, which the system's splash then honours, so there the
/// pick is handed over. Everywhere else the phone decides and this does
/// nothing.
class LaunchAppearanceChannel {
  const LaunchAppearanceChannel();

  static const _channel = MethodChannel(
    'cloud.begzar.begzar/launch_appearance',
  );

  /// Best effort: a launch window in the other theme is a cosmetic flash,
  /// never a reason for the pick itself to fail.
  Future<void> follow(ThemeMode mode) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('follow', mode.name);
    } catch (_) {}
  }
}
