import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The ad-skip warning travels through three in-memory flags, because the
/// moment it is earned is not a moment a dialog can be shown.
///
/// 1. [adSkipWarningPendingProvider] — the user backgrounded the app while the
///    gate was counting down. Set while the app is on its way out.
/// 2. [adSkipWarningShowRequestProvider] — the app came back. Asks the widget
///    layer to present once the navigator is idle.
/// 3. [adSkipWarningVisibleProvider] — the dialog is on screen.
///
/// They were split across two files before this module existed; they are one
/// sequence and belong together.
class AdSkipWarningPendingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markPending() => state = true;

  void clear() => state = false;
}

/// Set on background, read on resume: a warning is owed to the user.
final adSkipWarningPendingProvider =
    NotifierProvider<AdSkipWarningPendingNotifier, bool>(
      AdSkipWarningPendingNotifier.new,
    );

class AdSkipWarningShowRequestNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void clear() => state = false;
}

/// Signals the UI layer to present the ad-skip warning dialog safely.
final adSkipWarningShowRequestProvider =
    NotifierProvider<AdSkipWarningShowRequestNotifier, bool>(
      AdSkipWarningShowRequestNotifier.new,
    );

class AdSkipWarningVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;

  void hide() => state = false;
}

/// True while the warning dialog is on screen.
final adSkipWarningVisibleProvider =
    NotifierProvider<AdSkipWarningVisibleNotifier, bool>(
      AdSkipWarningVisibleNotifier.new,
    );
