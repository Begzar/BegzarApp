import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/main/presentation/widgets/launch_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the launch window's picture over the app's first frames, and hands
/// it over to the home dial.
///
/// The platform's launch window is the page with the resting dial at the
/// window's centre. Whatever the app draws first — a gate checking a
/// permission, home still laying out — would replace that picture with
/// another, so the cover draws the same one over it until the first screen
/// is settled. Home lands it: the dial is carried from the centre into the
/// home dial's place, the page under it fading in over the last of the way.
/// It arrives as the same picture as the home dial — opened out of the
/// launch circle so its shadow is whole, with no invite rings — and the home
/// dial takes over in the frame the cover goes, bringing its rings in itself.
/// Nothing is ever drawn over its own copy: two see-through dials stacked
/// double the shadow, the rim and the glass. A question asked before home
/// dismisses the cover, and it fades where it is.
class LaunchCover extends ConsumerStatefulWidget {
  const LaunchCover({super.key, required this.child});

  final Widget child;

  /// The dial carried from the window's centre into the home dial's place.
  static const flight = Duration(milliseconds: 600);

  /// The cover fading where it is, when the first screen is not home.
  static const leave = Duration(milliseconds: 300);

  /// How long the cover waits for an answer before it lets go on its own. A
  /// first screen that never answers must not leave the reader behind it.
  static const giveUpAfter = Duration(seconds: 3);

  /// Where in the flight the page under the cover starts to come through.
  ///
  /// Not before: the status line sits just under the home dial's place, and
  /// a dial still on its way down to it would be drawn over the line. By
  /// here the eased flight has carried the dial three quarters of the way,
  /// close enough that the two no longer meet.
  static const _revealFrom = 0.6;

  /// The page under the cover, for a test to read.
  static const pageKey = Key('launch-cover-page');

  @override
  ConsumerState<LaunchCover> createState() => _LaunchCoverState();
}

class _LaunchCoverState extends ConsumerState<LaunchCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  Timer? _giveUp;

  /// Where the flight last drew the dial and the page, for a cover that
  /// leaves partway through it to fade from. A cover that leaves before it
  /// flew fades from the window's centre.
  Offset? _heldCentre;
  double _heldScale = 1;
  double _heldPage = 1;
  double _heldOpening = 0;

  void _hold(Offset centre, double scale, double page, double opening) {
    _heldCentre = centre;
    _heldScale = scale;
    _heldPage = page;
    _heldOpening = opening;
  }

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this);
    if (ref.read(launchCoverProvider).phase == LaunchCoverPhase.covering) {
      _giveUp = Timer(
        LaunchCover.giveUpAfter,
        () => ref.read(launchCoverProvider.notifier).dismiss(),
      );
    }
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    _motion.dispose();
    super.dispose();
  }

  /// Runs one stretch of the cover's motion, then moves it on with [then].
  void _run(Duration duration, void Function(LaunchCoverNotifier) then) {
    _giveUp?.cancel();
    _motion.duration = duration;
    _motion.forward(from: 0).whenComplete(() {
      if (mounted) then(ref.read(launchCoverProvider.notifier));
    });
  }

  void _follow(LaunchCoverState? previous, LaunchCoverState next) {
    if (previous?.phase == next.phase) return;
    switch (next.phase) {
      case LaunchCoverPhase.landing:
        _run(LaunchCover.flight, (cover) => cover.finish());
      case LaunchCoverPhase.leaving:
        _run(LaunchCover.leave, (cover) => cover.finish());
      case LaunchCoverPhase.done:
        _giveUp?.cancel();
      case LaunchCoverPhase.covering:
        break;
    }
  }

  /// The cover at this point of its motion: the page, and the dial on it.
  Widget _cover(LaunchCoverState cover) {
    final window = MediaQuery.sizeOf(context).center(Offset.zero);
    final progress = _motion.value;

    var centre = _heldCentre ?? window;
    var scale = _heldScale;
    var page = _heldPage;
    var dial = 1.0;
    var opening = _heldOpening;
    switch (cover.phase) {
      case LaunchCoverPhase.landing:
        final target = cover.target!;
        final travelled = Curves.easeInOutCubic.transform(progress);
        centre = Offset.lerp(window, target.center, travelled)!;
        opening = travelled;
        scale = lerpDouble(
          1,
          target.width / AppLayout.launchDialSize,
          travelled,
        )!;
        page =
            1 - const Interval(LaunchCover._revealFrom, 1).transform(progress);
        _hold(centre, scale, page, opening);
      case LaunchCoverPhase.leaving:
        // From wherever the dial had got to: a flight called off midway
        // fades there rather than jumping back to the centre.
        page *= 1 - progress;
        dial = 1 - progress;
      case LaunchCoverPhase.covering || LaunchCoverPhase.done:
        break;
    }

    const shown = AppLayout.launchShownCircle;
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(
            key: LaunchCover.pageKey,
            opacity: page,
            child: ColoredBox(color: context.palette.page),
          ),
        ),
        Positioned(
          left: centre.dx - shown / 2,
          top: centre.dy - shown / 2,
          child: Opacity(
            opacity: dial,
            child: Transform.scale(
              scale: scale,
              child: LaunchDial(opening: opening),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(launchCoverProvider, _follow);
    final cover = ref.watch(launchCoverProvider);

    // Always a stack with the app first, so the app keeps its state when the
    // cover goes.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (cover.phase != LaunchCoverPhase.done)
          Positioned.fill(
            child: AbsorbPointer(
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) => _cover(cover),
              ),
            ),
          ),
      ],
    );
  }
}
