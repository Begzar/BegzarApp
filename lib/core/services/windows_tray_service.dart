import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Windows system-tray bridge (native runner plugin).
///
/// One direction only: the tray reports its Disconnect click up to Dart, and
/// Dart tells it nothing back. Showing and hiding the window are handled
/// natively from window messages — `WM_CLOSE` hides to tray, a left click on
/// the tray icon restores — so there is nothing for this side to drive.
///
/// Deciding what a Disconnect click should do belongs to whoever owns the
/// connection, so the wiring lives in `lib/app/windows_tray_handler.dart`
/// rather than here.
class WindowsTrayService {
  WindowsTrayService._();

  static final WindowsTrayService instance = WindowsTrayService._();

  static const _channel = MethodChannel('begzar/system_tray');

  bool get isSupported => !kIsWeb && Platform.isWindows;

  VoidCallback? _onDisconnectRequested;
  bool _handlerAttached = false;

  /// Registers the native → Dart disconnect callback once.
  void attach({required VoidCallback onDisconnectRequested}) {
    if (!isSupported) return;
    _onDisconnectRequested = onDisconnectRequested;
    if (_handlerAttached) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'disconnectRequested') {
        _onDisconnectRequested?.call();
      }
    });
  }
}
