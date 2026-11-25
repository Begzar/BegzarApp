import 'package:begzar/firebase_options.dart';
import 'package:flutter/foundation.dart';

/// Whether this build uses Firebase: only on Android, iOS and macOS (never
/// Windows or Linux), and only when the build names a Firebase project.
///
/// The public repository names none: its `lib/firebase_options.dart` has every
/// value empty, so it builds and runs without Firebase: no analytics, no push
/// and no in-app messages.
bool get isFirebaseSupported => _platformUsesFirebase && _projectConfigured;

bool get _platformUsesFirebase {
  if (kIsWeb) {
    return true;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}

bool get _projectConfigured =>
    DefaultFirebaseOptions.currentPlatform.apiKey.isNotEmpty;
