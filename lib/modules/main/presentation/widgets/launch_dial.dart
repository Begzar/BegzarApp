import 'dart:ui' show lerpDouble;

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A circle of [diameter] round the centre of whatever it clips, however
/// small that is.
class _CentredCircle extends CustomClipper<Rect> {
  const _CentredCircle(this.diameter);

  final double diameter;

  @override
  Rect getClip(Size size) => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: diameter,
    height: diameter,
  );

  @override
  bool shouldReclip(_CentredCircle oldClipper) =>
      oldClipper.diameter != diameter;
}

/// The resting dial as the launch window shows it: at
/// [AppLayout.launchDialSize] whatever the screen's width, cut to the circle
/// Android 12 shows of its launch icon.
///
/// One drawing for three places: `tool/splash/render_launch_dial_test.dart`
/// renders the platforms' launch images from it, and the app shell's launch
/// cover draws it over the first frames and carries it to the home dial, so
/// the hand-over never changes what is on screen.
///
/// It draws no invite rings, which fall outside that circle anyway; the home
/// dial brings them in when it takes over.
class LaunchDial extends StatelessWidget {
  const LaunchDial({super.key, this.opening = 0});

  /// How far the circle the dial is cut to has opened, from Android 12's
  /// launch circle at zero to the whole icon canvas at one, which holds all
  /// of the dial's shadow. The cover opens it on the way to the home dial,
  /// so the two match where it lays one over the other.
  final double opening;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      clipper: _CentredCircle(
        lerpDouble(
          AppLayout.launchShownCircle,
          AppLayout.launchIconCanvas,
          opening,
        )!,
      ),
      child: SizedBox.square(
        dimension: AppLayout.launchShownCircle,
        // Centred rather than set in an OverflowBox: an OverflowBox hands
        // the circle's tight size down as a minimum, which drew the disc at
        // the circle's width instead of its own.
        child: Center(
          child: SizedBox.square(
            dimension: AppLayout.launchDialSize,
            child: const FittedBox(
              child: ConnectionDial(
                status: ConnectionStatus.ready,
                pressed: false,
                invite: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the home dial sits, for the launch cover to land on.
///
/// While the cover is up, the dial under it is laid out but not drawn: the
/// cover draws its own and carries it here. Once the home dial has been laid
/// out it reports its place, and it shows itself in the frame the cover goes.
/// By then the cover's dial is the same picture in the same place, except
/// for the invite rings, so [builder] is told the dial is covered until then
/// and the home dial brings its rings in once it is not.
class LaunchDialSlot extends ConsumerStatefulWidget {
  const LaunchDialSlot({super.key, required this.builder});

  /// Builds the home dial, knowing whether the cover is still over it.
  final Widget Function(BuildContext context, bool covered) builder;

  @override
  ConsumerState<LaunchDialSlot> createState() => _LaunchDialSlotState();
}

class _LaunchDialSlotState extends ConsumerState<LaunchDialSlot> {
  void _reportPlace() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    ref
        .read(launchCoverProvider.notifier)
        .land(box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  void initState() {
    super.initState();
    if (ref.read(launchCoverProvider).phase == LaunchCoverPhase.covering) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportPlace());
    }
  }

  @override
  Widget build(BuildContext context) {
    final covered = ref.watch(
      launchCoverProvider.select(
        (cover) => cover.phase != LaunchCoverPhase.done,
      ),
    );
    // Always wrapped, so the dial below keeps its state when the cover goes.
    return Opacity(
      opacity: covered ? 0 : 1,
      child: widget.builder(context, covered),
    );
  }
}
