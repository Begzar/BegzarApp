import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a cold start's hand-over from the launch window stands.
///
/// The platform draws the launch window before Dart runs: the resting dial
/// at the window's centre. The app shell covers its first frames with the
/// same picture, so nothing flashes while the first screen settles, and lifts
/// the cover one of two ways. The home dial reports where it was laid out and
/// the cover carries its dial there, arriving as the same picture as the home
/// dial, which takes over in place; or a screen that is not home — a
/// question asked before home — dismisses it, and it fades where it is.
enum LaunchCoverPhase { covering, landing, leaving, done }

@immutable
class LaunchCoverState {
  const LaunchCoverState(this.phase, {this.target});

  final LaunchCoverPhase phase;

  /// Where the home dial was laid out, in global coordinates, once it has
  /// reported.
  final Rect? target;
}

/// Takes the first answer, with one exception: a landing can still be called
/// off for leaving, but a cover that is leaving never lands, and once it is
/// done nothing covers again.
class LaunchCoverNotifier extends Notifier<LaunchCoverState> {
  LaunchCoverNotifier({LaunchCoverPhase initial = LaunchCoverPhase.done})
    : _initial = initial;

  final LaunchCoverPhase _initial;

  bool get _covering => state.phase == LaunchCoverPhase.covering;

  @override
  LaunchCoverState build() => LaunchCoverState(_initial);

  /// The home dial is laid out at [target]: carry the launch dial there.
  void land(Rect target) {
    if (!_covering) return;
    state = LaunchCoverState(LaunchCoverPhase.landing, target: target);
  }

  /// The first screen is not home, or something has opened over it — the
  /// forced update's dialog — so fade the cover where it is, mid-flight
  /// included: the dial must not carry on across what opened.
  void dismiss() {
    if (!_covering && state.phase != LaunchCoverPhase.landing) return;
    state = const LaunchCoverState(LaunchCoverPhase.leaving);
  }

  /// The cover is gone.
  void finish() => state = const LaunchCoverState(LaunchCoverPhase.done);
}

/// Done unless `main` started the process under a cover, which it does only
/// where the platform draws a launch window to hand over from.
final launchCoverProvider =
    NotifierProvider<LaunchCoverNotifier, LaunchCoverState>(
      LaunchCoverNotifier.new,
    );
