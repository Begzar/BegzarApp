import 'package:begzar/modules/ads/presentation/controllers/ad_skip_warning_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_gate_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/post_connect_ad_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Answers the system back press on behalf of the ad overlays.
///
/// The overlays are painted from `MaterialApp.builder`, above the router, so
/// there is no `ModalRoute` in their context for a `PopScope` to register with
/// — one placed among them registers nothing and never fires. Left unanswered,
/// the press falls through to Android, which finishes the activity: the app
/// closes mid-ad and takes the tunnel with it, because a detached app is read
/// as one that walked out on the wait.
///
/// So the press is answered here, and the screen that owns the back button asks
/// this before doing anything of its own. Returning true means the press was
/// spent on an overlay and must go no further.
class AdOverlayBackHandler {
  const AdOverlayBackHandler(this._ref);

  final Ref _ref;

  bool handleBack() {
    // Asked in painting order, topmost first: the warning is drawn over the ad.
    if (_ref.read(adSkipWarningVisibleProvider)) {
      _ref.read(adSkipWarningVisibleProvider.notifier).hide();
      return true;
    }

    final ad = _ref.read(postConnectAdProvider);
    if (ad == null) return false;

    // Back is the close knob, and the knob is locked until the wait is served.
    // Swallowing the press rather than passing it on is the point: the screen
    // behind must not act on a press aimed at the ad covering it.
    final locked =
        ad.isLoading ||
        (ad.enforceWait && !_ref.read(connectionAdGateProvider).canClose);
    if (locked) return true;

    _ref.read(postConnectAdProvider.notifier).dismiss();
    return true;
  }
}

final adOverlayBackHandlerProvider = Provider<AdOverlayBackHandler>(
  AdOverlayBackHandler.new,
);
