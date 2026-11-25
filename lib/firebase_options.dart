// lib/firebase_options.dart as the public repository has it: the same class
// the FlutterFire CLI writes, naming no Firebase project, so the build has no
// Firebase at all (see lib/core/services/firebase_platform.dart).
//
// To build with your own project, run `flutterfire configure`, which replaces
// lib/firebase_options.dart and adds the platform config files.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions _none = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
  );

  static const FirebaseOptions web = _none;
  static const FirebaseOptions android = _none;
  static const FirebaseOptions ios = _none;
  static const FirebaseOptions macos = _none;
}
