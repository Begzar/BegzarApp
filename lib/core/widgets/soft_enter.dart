import 'package:flutter/material.dart';

/// Lightweight enter/leave motion: fade + slight slide + soft scale.
class SoftEnter extends StatelessWidget {
  const SoftEnter({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 480),
    this.delay = Duration.zero,
    this.slide = const Offset(-0.18, 0.08),
    this.curve = Curves.easeOutCubic,
    this.alignment = Alignment.centerLeft,
  });

  final bool visible;
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset slide;
  final Curve curve;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
      duration: duration + delay,
      curve: softEnterCurve(curve, delay, duration + delay),
      builder: (context, value, child) {
        final t = value.clamp(0.0, 1.0);
        // A child faded all the way out stays mounted, so anything animating
        // in it would keep the screen drawing frames nobody can see.
        return TickerMode(
          enabled: t > 0,
          child: IgnorePointer(
            ignoring: t < 0.02,
            child: Opacity(
              opacity: Curves.easeOut.transform(t),
              child: Transform.translate(
                offset: Offset(
                  slide.dx * 56 * (1 - t),
                  slide.dy * 40 * (1 - t),
                ),
                child: Transform.scale(
                  scale: 0.94 + (0.06 * t),
                  alignment: alignment,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

Curve softEnterCurve(Curve curve, Duration delay, Duration total) {
  if (delay == Duration.zero || total.inMilliseconds == 0) {
    return curve;
  }
  final start = delay.inMilliseconds / total.inMilliseconds;
  return Interval(start.clamp(0.0, 0.85), 1.0, curve: curve);
}

/// Staggered fade/slide for list rows.
class SoftListItem extends StatelessWidget {
  const SoftListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 380),
  });

  final int index;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final delayMs = (index * 45).clamp(0, 280);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration + Duration(milliseconds: delayMs),
      curve: Interval(
        (delayMs / (duration.inMilliseconds + delayMs)).clamp(0.0, 0.7),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        final t = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
