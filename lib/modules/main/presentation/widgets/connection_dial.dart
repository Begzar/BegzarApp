import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/main/presentation/widgets/glass_bird.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The big circle at the middle of the home screen: a disc of glass tinted
/// with its own light, resting on the page with the rim and shadow of the
/// server row and the IP reading, with the brand's bird set into it.
///
/// Three animations, each meaning something different: the rings say a tunnel
/// is being worked on, and which way they travel says whether it is being
/// reached for or already carrying traffic; the breathe says the app is busy
/// and runs through every in-flight state; and the press-scale is feedback for
/// the touch itself.
///
/// The glass, the bird, the rim and a glow round the dial are lit in the
/// status colour, and the status line under the dial says in words what the
/// colour alone cannot, so nothing is set into the rim. At rest the dial is
/// lit in the blue of the bird's own streaks and the rim is plain glass. A
/// change of status eases the whole dial from one light into the next.
class ConnectionDial extends StatefulWidget {
  const ConnectionDial({
    super.key,
    required this.status,
    required this.pressed,
    this.invite = true,
  });

  static const size = AppLayout.mainDialSize;

  final ConnectionStatus status;

  /// Driven by the parent's gesture detector, since the whole column is the
  /// tap target rather than just this circle.
  final bool pressed;

  /// Whether a dial at rest draws the rings that invite the tap. Off for the
  /// launch dial, which stands for the home dial without being pressable,
  /// and hands the rings over to it.
  final bool invite;

  /// The rings that invite a tap, for a test to find.
  static const inviteKey = Key('dial-invite-rings');

  @override
  State<ConnectionDial> createState() => _ConnectionDialState();
}

class _ConnectionDialState extends State<ConnectionDial>
    with TickerProviderStateMixin {
  static const _waveCount = 4;
  static const _waveDuration = Duration(milliseconds: 3500);
  static const _breatheDuration = Duration(milliseconds: 2000);
  static const _pressDuration = Duration(milliseconds: 150);

  /// A ring at the rim, thinning by [_ringThinning] of its width by the time
  /// it reaches full stretch, so it reads as dissipating rather than merely
  /// fading.
  static const _ringThinning = 0.6;
  static const _ringOpacity = 0.5;

  /// Where the breath sits when it is not running.
  ///
  /// Halfway through the tween, which is the dial at exactly the size the
  /// layout reserves for it. Stopping the controller wherever it happens to
  /// be would leave a resting dial anywhere between 0.95 and 1.05 — and at
  /// the value the tween begins on, 0.95, before it has ever run.
  static const _breatheRest = 0.5;

  /// How faint the bird gets at the low point of a breath while a tunnel is
  /// in flight.
  static const _birdFadeFloor = 0.45;

  /// How strongly the dial's own light shows round it once it is lit.
  static const _glowAlpha = 0.22;

  late final AnimationController _waveController = AnimationController(
    duration: _waveDuration,
    vsync: this,
  );
  late final AnimationController _breatheController = AnimationController(
    duration: _breatheDuration,
    vsync: this,
  );
  late final AnimationController _pressController = AnimationController(
    duration: _pressDuration,
    vsync: this,
  );

  /// One breath of the ring round a dial at rest. A finite run restarted by
  /// a timer rather than a repeating controller, so a dial at rest is at rest
  /// between breaths and a screen holding one can still settle.
  late final AnimationController _inviteController = AnimationController(
    duration: MainPalette.dialInvite,
    vsync: this,
  );
  Timer? _inviteTimer;

  /// How strongly the invite rings are drawn: whole for a dial that invites
  /// from the start, and brought in when one starts inviting later.
  late final AnimationController _inviteShown = AnimationController(
    duration: MainPalette.dialInviteReveal,
    value: widget.invite ? 1 : 0,
    vsync: this,
  );

  late final Animation<double> _wave = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: _waveController, curve: Curves.easeOut));
  late final Animation<double> _breathe = Tween<double>(begin: 0.95, end: 1.05)
      .animate(
        CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
      );
  late final Animation<double> _press = Tween<double>(
    begin: 1.0,
    end: 0.92,
  ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    // Seeded rather than eased, so the first frame is already the right size
    // instead of growing into it while the screen is being read.
    _breatheController.value = _breatheRest;
    _applyStatus(widget.status);
  }

  @override
  void didUpdateWidget(ConnectionDial oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.status != oldWidget.status) _applyStatus(widget.status);
    if (widget.invite != oldWidget.invite) {
      // From the start of a breath, so the moving ring grows out from the rim
      // as the rings come in, rather than arriving partway through one.
      _stopInvite();
      _applyStatus(widget.status);
      widget.invite ? _inviteShown.forward() : _inviteShown.reverse();
    }
    if (widget.pressed != oldWidget.pressed) {
      widget.pressed ? _pressController.forward() : _pressController.reverse();
    }
  }

  @override
  void dispose() {
    _inviteTimer?.cancel();
    _waveController.dispose();
    _breatheController.dispose();
    _pressController.dispose();
    _inviteController.dispose();
    _inviteShown.dispose();
    super.dispose();
  }

  void _startInvite() {
    if (_inviteTimer != null) return;
    _inviteController.forward(from: 0);
    // A breath, then a rest in which nothing moves, so a home screen at rest
    // stops drawing frames rather than redrawing at the display's full rate.
    _inviteTimer = Timer.periodic(
      MainPalette.dialInvite + MainPalette.dialInviteRest,
      (_) {
        if (mounted) _inviteController.forward(from: 0);
      },
    );
  }

  void _stopInvite() {
    _inviteTimer?.cancel();
    _inviteTimer = null;
    _inviteController.stop();
    _inviteController.value = 0;
  }

  void _applyStatus(ConnectionStatus status) {
    if (status == ConnectionStatus.ready && widget.invite) {
      _startInvite();
    } else {
      _stopInvite();
    }
    switch (status) {
      case ConnectionStatus.connected:
      case ConnectionStatus.connecting:
        _waveController.repeat();
        _breatheController.repeat(reverse: true);
      case ConnectionStatus.disconnecting:
        // No rings on a teardown: it is neither traffic flowing nor a tunnel
        // being reached for. The breath is what says something is in flight.
        _waveController.stop();
        _breatheController.repeat(reverse: true);
      case ConnectionStatus.error:
      case ConnectionStatus.ready:
        _waveController.stop();
        _settleBreath();
    }
  }

  /// Brings the breath to rest instead of freezing it where it was.
  ///
  /// [AnimationController.stop] leaves the value it had, so a dial that
  /// stopped breathing mid-cycle kept whatever size that moment gave it and
  /// two identical screens could differ by a tenth of the dial. It eases
  /// rather than snaps, over the same duration as any other control changing
  /// state in place.
  void _settleBreath() {
    _breatheController.animateTo(
      _breatheRest,
      duration: MainPalette.stateChange,
      curve: Curves.easeOut,
    );
  }

  /// The rim: plain glass at rest, taking the light as the dial lights up,
  /// at the strength the server row's rim takes a status.
  Color _rimFor(_DialLook look) => Color.lerp(
    PremiumPalette.of(context).border,
    look.light.withValues(alpha: PremiumPalette.liveAlpha),
    look.lit,
  )!;

  /// The dial's own light round it, for as long as it is lit at all.
  ///
  /// Outside the disc only. A shadow is drawn under its box as well as round
  /// it, and under glass this clear that is a film of the light across the
  /// whole disc: the pale red of a failed connect turned it brown.
  BoxShadow? _glowFor(_DialLook look) => look.lit == 0
      ? null
      : BoxShadow(
          color: look.light.withValues(alpha: _glowAlpha * look.lit),
          blurRadius: AppLayout.mainDialGlowBlur.r,
          spreadRadius: AppLayout.mainDialGlowSpread.r,
          blurStyle: BlurStyle.outer,
        );

  /// The brand at the centre, lit as the dial is lit.
  ///
  /// It stays through every state, a wait included. While a tunnel is in
  /// flight it fades in and out with the breath, down to [_birdFadeFloor] as
  /// the dial shrinks. Connected breathes too, but a tunnel that is up is not
  /// a wait, so the bird holds solid there.
  Widget _bird(_DialLook look) {
    final opacity = widget.status.isTransitional
        ? _birdFadeFloor + (1.0 - _birdFadeFloor) * _breatheController.value
        : 1.0;

    return GlassBird(
      height: AppLayout.mainDialBirdHeight.w,
      light: look.light,
      glow: look.lit,
      opacity: opacity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = MainPalette.of(context);
    final flow = widget.status.ringFlow;

    return TweenAnimationBuilder<_DialLook>(
      tween: _DialLookTween(end: _DialLook.of(widget.status, palette)),
      duration: MainPalette.stateChange,
      curve: Curves.easeOut,
      builder: (context, look, child) => AnimatedBuilder(
        animation: Listenable.merge([
          _wave,
          _breathe,
          _press,
          _inviteController,
          _inviteShown,
        ]),
        builder: (context, child) => Transform.scale(
          scale: _press.value * _breathe.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if ((widget.invite || _inviteShown.value > 0) &&
                  widget.status == ConnectionStatus.ready)
                CustomPaint(
                  key: ConnectionDial.inviteKey,
                  size: Size.square(ConnectionDial.size.w),
                  painter: _InviteRingsPainter(
                    colour: palette.invite,
                    progress: MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : _inviteController.value,
                    strength: Curves.easeOut.transform(_inviteShown.value),
                  ),
                ),
              if (flow != null) ..._rings(flow),
              AppGlassPanel(
                style: AppGlass.dial(
                  context.palette,
                  tintStops: palette.dialStops(look.light),
                  borderColor: _rimFor(look),
                  glow: _glowFor(look),
                ),
                child: SizedBox.square(
                  dimension: ConnectionDial.size.w,
                  child: Center(child: _bird(look)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rings travelling between the rim and full stretch, evenly spaced by
  /// offsetting each one into the same loop rather than running four
  /// controllers.
  List<Widget> _rings(_RingFlow flow) {
    return List.generate(_waveCount, (index) {
      final delay = index / _waveCount;

      return AnimatedBuilder(
        animation: _wave,
        builder: (context, child) {
          final cycle = (_wave.value + delay) % 1.0;
          final distance = flow.distanceAt(cycle);
          final opacity =
              (1.0 - Curves.easeOut.transform(distance)) *
              _ringOpacity *
              flow.arrivalFadeAt(cycle);

          return Transform.scale(
            scale: 1.0 + distance,
            child: Container(
              width: ConnectionDial.size.w,
              height: ConnectionDial.size.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width:
                      AppLayout.mainDialRingWidth.w *
                      (1.0 - distance * _ringThinning),
                  // The fade rides the colour rather than an Opacity widget.
                  // A ring is one outline, so there is nothing for a layer to
                  // blend together, and four of them repainting forever is
                  // four offscreen targets a frame for no visible difference.
                  color: widget.status
                      .dialColorIn(MainPalette.of(context))
                      .withValues(alpha: opacity.clamp(0.0, 1.0)),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

/// Which way the rings travel, and so what they mean.
///
/// One shape, read in either direction: leaving is traffic flowing through a
/// tunnel that is up, arriving is a tunnel being reached for and not yet
/// found. Inward is the outward ring played backwards, so both states are the
/// same numbers in a different order and neither can drift away from the
/// other.
enum _RingFlow {
  outward,
  inward;

  /// The stretch of a run inward over which the ring is taken up by the rim.
  ///
  /// Without it a converging ring would vanish at half opacity the instant it
  /// landed. An outward ring needs none: it leaves the rim already fading.
  static const _arrivalTaper = 0.12;

  /// How far out the ring sits, from where it is in the loop. Zero is the rim.
  double distanceAt(double cycle) => this == outward ? cycle : 1.0 - cycle;

  double arrivalFadeAt(double cycle) =>
      this == outward ? 1.0 : ((1.0 - cycle) / _arrivalTaper).clamp(0.0, 1.0);
}

/// What the dial is lit with in one status, held as one value so a change of
/// status eases the glass, the bird, the rim and the glow across together
/// rather than each on a clock of its own.
@immutable
class _DialLook {
  const _DialLook({required this.light, required this.lit});

  _DialLook.of(ConnectionStatus status, MainPalette palette)
    : light = status.dialColorIn(palette),
      lit = status == ConnectionStatus.ready ? 0 : 1;

  /// The colour the dial is lit in.
  final Color light;

  /// How far the dial is reporting a status, from not at all at rest to
  /// fully. At rest the rim is plain glass and nothing glows.
  final double lit;

  static _DialLook lerp(_DialLook from, _DialLook to, double t) => _DialLook(
    light: Color.lerp(from.light, to.light, t)!,
    lit: lerpDouble(from.lit, to.lit, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is _DialLook && other.light == light && other.lit == lit;

  @override
  int get hashCode => Object.hash(light, lit);
}

/// Eases one [_DialLook] into the next.
class _DialLookTween extends Tween<_DialLook> {
  _DialLookTween({required super.end});

  @override
  _DialLook lerp(double t) => _DialLook.lerp(begin!, end!, t);
}

/// How each connection status is drawn on the dial.
extension on ConnectionStatus {
  /// The colour the dial is lit in: the bird, the rim, the glow round it and
  /// the rings.
  Color dialColorIn(MainPalette palette) => switch (this) {
    ConnectionStatus.connecting ||
    ConnectionStatus.disconnecting => palette.inFlight,
    ConnectionStatus.connected => palette.connected,
    ConnectionStatus.error => palette.failedInk,
    ConnectionStatus.ready => MainPalette.dialAtRest,
  };

  /// Which way this state's rings travel, or null for one that draws none.
  _RingFlow? get ringFlow => switch (this) {
    ConnectionStatus.connected => _RingFlow.outward,
    ConnectionStatus.connecting => _RingFlow.inward,
    ConnectionStatus.disconnecting ||
    ConnectionStatus.error ||
    ConnectionStatus.ready => null,
  };
}

/// The rings round a dial at rest: one held still a step out from the rim,
/// and one breathing out past it and back, to say the dial is there to be
/// pressed. Painted outside the dial's own box, so they take no room from
/// the screen around it.
class _InviteRingsPainter extends CustomPainter {
  const _InviteRingsPainter({
    required this.colour,
    required this.progress,
    required this.strength,
  });

  final Color colour;

  /// Where the breath is, from 0 to 1.
  final double progress;

  /// How strongly both rings are drawn, from none to full.
  final double strength;

  static const _stillScale = 1.244;

  /// Strong enough to read as a ring round a button rather than a smudge on
  /// the page, which is what it was at a tenth.
  static const _stillAlpha = 0.34;
  static const _nearScale = 1.22;
  static const _farScale = 1.46;
  static const _peakAlpha = 0.22;
  static const _stroke = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;

    canvas.drawCircle(
      centre,
      radius * _stillScale,
      paint..color = colour.withValues(alpha: _stillAlpha * strength),
    );

    final breath = math.sin(progress * math.pi);
    if (breath <= 0) return;
    canvas.drawCircle(
      centre,
      radius * (_nearScale + (_farScale - _nearScale) * breath),
      paint..color = colour.withValues(alpha: _peakAlpha * breath * strength),
    );
  }

  @override
  bool shouldRepaint(_InviteRingsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.colour != colour ||
      oldDelegate.strength != strength;
}
