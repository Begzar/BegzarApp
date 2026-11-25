import 'dart:math' as math;

import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/widgets/premium_server_icon.dart';
import 'package:flutter/material.dart';

/// The side of the box every picture here is drawn in, in artwork units. Each
/// painter scales it to the size it is given, so the coordinates below read as
/// the design drew them.
const _artBox = 28.0;

/// The ad's countdown ring, already running, struck through: the wait Basic
/// makes after every connect, which Premium does not.
class _AdWaitPainter extends CustomPainter {
  static const _centre = Offset(14, 14);
  static const _radius = 10.5;
  static const _ringWidth = 2.4;

  /// The ring the countdown has run so far, from the top, clockwise.
  static const _runStart = -math.pi / 2;
  static const _runSweep = 2 * math.pi / 3;

  static const _labelSize = 7.5;

  /// The widest the label may run inside the ring. A longer one, which some
  /// languages' word for ads is, is set smaller rather than spilling out.
  static const _labelMaxWidth = 15.0;

  static const _strikeFrom = Offset(5.5, 22.5);
  static const _strikeTo = Offset(22.5, 5.5);
  static const _strikeWidth = 1.4;

  /// What fills the ring, a little of the ad's amber.
  static const _fillAlpha = 0.12;

  const _AdWaitPainter({
    required this.label,
    required this.textDirection,
    required this.ad,
    required this.track,
    required this.ink,
  });

  /// What the app's ad badge says, in the reader's language.
  final String label;
  final TextDirection textDirection;

  /// The ad's amber, and the ring the countdown runs round.
  final Color ad;
  final Color track;

  /// The strike through it.
  final Color ink;

  /// [label] laid out at [_labelSize], or smaller if it would not fit.
  TextPainter _labelPainter(double fontSize) => TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: ad,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: textDirection,
  )..layout();

  TextPainter _fittedLabel() {
    final natural = _labelPainter(_labelSize);
    if (natural.width <= _labelMaxWidth) return natural;
    return _labelPainter(_labelSize * _labelMaxWidth / natural.width);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _artBox);
    final ring = Rect.fromCircle(center: _centre, radius: _radius);

    canvas
      ..drawCircle(
        _centre,
        _radius,
        Paint()..color = ad.withValues(alpha: _fillAlpha),
      )
      ..drawCircle(
        _centre,
        _radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringWidth
          ..color = track,
      )
      ..drawArc(
        ring,
        _runStart,
        _runSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringWidth
          ..strokeCap = StrokeCap.round
          ..color = ad,
      );

    final text = _fittedLabel();
    text.paint(canvas, _centre - Offset(text.width / 2, text.height / 2));

    canvas.drawLine(
      _strikeFrom,
      _strikeTo,
      Paint()
        ..strokeWidth = _strikeWidth
        ..strokeCap = StrokeCap.round
        ..color = ink,
    );
  }

  @override
  bool shouldRepaint(_AdWaitPainter oldDelegate) =>
      oldDelegate.label != label ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.ad != ad ||
      oldDelegate.track != track ||
      oldDelegate.ink != ink;
}

/// A speed gauge with its needle in the green.
///
/// The dial is the top half of a circle, so its centre sits below the middle
/// of the box: placed there, the arc above and the hub below are balanced in
/// the tile, where a centre at the box's middle left the drawing low.
class _SpeedPainter extends CustomPainter {
  static const _centre = Offset(14, 18.2);
  static const _radius = 10.0;
  static const _trackWidth = 3.0;

  /// The green the needle points into: the last stretch of the dial.
  static const _greenStart = -1.2;

  static const _needleTip = Offset(20.2, 11.8);
  static const _needleWidth = 2.2;
  static const _hubRadius = 2.3;

  const _SpeedPainter({
    required this.track,
    required this.speed,
    required this.ink,
  });

  /// The dial's track, and the stretch of it the needle points into.
  final Color track;
  final Color speed;

  /// The needle and its hub.
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _artBox);
    final dial = Rect.fromCircle(center: _centre, radius: _radius);
    Paint arc(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _trackWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas
      ..drawArc(dial, math.pi, math.pi, false, arc(track))
      ..drawArc(dial, _greenStart, -_greenStart, false, arc(speed))
      ..drawLine(
        _centre,
        _needleTip,
        Paint()
          ..strokeWidth = _needleWidth
          ..strokeCap = StrokeCap.round
          ..color = ink,
      )
      ..drawCircle(_centre, _hubRadius, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_SpeedPainter oldDelegate) =>
      oldDelegate.track != track ||
      oldDelegate.speed != speed ||
      oldDelegate.ink != ink;
}

/// The kinds of device the devices picture draws.
enum PaywallDevice { monitor, laptop, tablet, phone }

/// One device in the picture: what it is, and the box its body fills in the
/// artwork box.
typedef _Placed = ({PaywallDevice kind, Rect body});

/// The picture for each device count, back to front: a phone, then a laptop
/// behind it, then a tablet between them, a monitor at the back and a second
/// phone in front. Laid out by hand for each count, because five devices
/// spread the way two are would not fit the box.
const _deviceSets = <List<_Placed>>[
  [(kind: PaywallDevice.phone, body: Rect.fromLTWH(9.5, 4.5, 9, 17))],
  [
    (kind: PaywallDevice.laptop, body: Rect.fromLTWH(2.5, 6, 15.5, 10)),
    (kind: PaywallDevice.phone, body: Rect.fromLTWH(18, 9.5, 8, 13)),
  ],
  [
    (kind: PaywallDevice.laptop, body: Rect.fromLTWH(1.5, 5, 14, 9.5)),
    (kind: PaywallDevice.tablet, body: Rect.fromLTWH(11, 9, 10, 13.5)),
    (kind: PaywallDevice.phone, body: Rect.fromLTWH(19, 12, 7, 11.5)),
  ],
  [
    (kind: PaywallDevice.monitor, body: Rect.fromLTWH(7, 1, 16, 9.5)),
    (kind: PaywallDevice.laptop, body: Rect.fromLTWH(1.5, 9, 12, 8)),
    (kind: PaywallDevice.tablet, body: Rect.fromLTWH(12, 11, 9, 12.5)),
    (kind: PaywallDevice.phone, body: Rect.fromLTWH(19.5, 13.5, 6.5, 11)),
  ],
  [
    (kind: PaywallDevice.monitor, body: Rect.fromLTWH(7, 1, 16, 9.5)),
    (kind: PaywallDevice.laptop, body: Rect.fromLTWH(1.5, 9, 12, 8)),
    (kind: PaywallDevice.tablet, body: Rect.fromLTWH(12, 11, 9, 12.5)),
    (kind: PaywallDevice.phone, body: Rect.fromLTWH(19.5, 13.5, 6.5, 11)),
    (kind: PaywallDevice.phone, body: Rect.fromLTWH(3, 15, 6, 10.5)),
  ],
];

List<_Placed> _deviceSetFor(int count) =>
    _deviceSets[count.clamp(1, _deviceSets.length) - 1];

/// The devices the picture draws for [count], back to front: as many as the
/// count, up to the five the picture has room for.
List<PaywallDevice> paywallDeviceKinds(int count) => [
  for (final device in _deviceSetFor(count)) device.kind,
];

/// As many devices as a plan signs in at once, so the picture beside the
/// device count grows with it.
class _DeviceSetPainter extends CustomPainter {
  static const _lineWidth = 1.6;

  /// How round each body's corners are: a handheld's rounder than a screen's.
  static const _screenCorner = Radius.circular(1.4);
  static const _handheldCorner = Radius.circular(1.8);

  /// How far below a laptop's screen its base runs, and how far past it.
  static const _baseDrop = 3.0;
  static const _baseOverhang = 1.0;

  /// A monitor's stand: its neck and its foot.
  static const _standNeck = 2.5;
  static const _standFoot = 3.0;

  /// The line near a handheld's bottom edge, and its half-width.
  static const _speakerRise = 2.2;
  static const _speakerHalf = 1.0;

  /// How strongly a screen takes the tunnel's blue.
  static const _screenAlpha = 0.22;

  const _DeviceSetPainter({
    required this.count,
    required this.laptop,
    required this.phone,
    required this.cutout,
  });

  final int count;

  /// A screen's blue, a handheld's outline, and the page a handheld is cut
  /// out of.
  final Color laptop;
  final Color phone;
  final Color cutout;

  Paint _line(Color color) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _lineWidth
    ..strokeCap = StrokeCap.round
    ..color = color;

  /// A laptop's or a monitor's screen, filmed in the tunnel's blue.
  void _screen(Canvas canvas, Rect body) {
    final screen = RRect.fromRectAndRadius(body, _screenCorner);
    canvas
      ..drawRRect(
        screen,
        Paint()..color = laptop.withValues(alpha: _screenAlpha),
      )
      ..drawRRect(screen, _line(laptop));
  }

  /// A phone or a tablet, cut out of whatever is behind it.
  void _handheld(Canvas canvas, Rect body) {
    final shape = RRect.fromRectAndRadius(body, _handheldCorner);
    final speakerY = body.bottom - _speakerRise;
    canvas
      ..drawRRect(shape, Paint()..color = cutout)
      ..drawRRect(shape, _line(phone))
      ..drawLine(
        Offset(body.center.dx - _speakerHalf, speakerY),
        Offset(body.center.dx + _speakerHalf, speakerY),
        _line(phone),
      );
  }

  void _device(Canvas canvas, _Placed device) {
    final body = device.body;
    switch (device.kind) {
      case PaywallDevice.laptop:
        _screen(canvas, body);
        final baseY = body.bottom + _baseDrop;
        canvas.drawLine(
          Offset(body.left - _baseOverhang, baseY),
          Offset(body.right + _baseOverhang, baseY),
          _line(laptop),
        );
      case PaywallDevice.monitor:
        _screen(canvas, body);
        final footY = body.bottom + _standNeck;
        final paint = _line(laptop);
        canvas
          ..drawLine(
            Offset(body.center.dx, body.bottom),
            Offset(body.center.dx, footY),
            paint,
          )
          ..drawLine(
            Offset(body.center.dx - _standFoot, footY),
            Offset(body.center.dx + _standFoot, footY),
            paint,
          );
      case PaywallDevice.tablet || PaywallDevice.phone:
        _handheld(canvas, body);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _artBox);
    for (final device in _deviceSetFor(count)) {
      _device(canvas, device);
    }
  }

  @override
  bool shouldRepaint(_DeviceSetPainter oldDelegate) =>
      oldDelegate.count != count ||
      oldDelegate.laptop != laptop ||
      oldDelegate.phone != phone ||
      oldDelegate.cutout != cutout;
}

/// Three of the premium list's own flags, overlapping: a choice of countries.
///
/// The flags are [PremiumServerIcon]'s, so the paywall shows the same artwork
/// the server list does.
class _Flags extends StatelessWidget {
  const _Flags({required this.size});

  final double size;

  /// Where each flag's centre sits in the artwork box, back to front, and the
  /// country it shows.
  static const _flags = [
    (code: 'de', centre: Offset(8, 16.5)),
    (code: 'us', centre: Offset(20, 16.5)),
    (code: 'nl', centre: Offset(14, 10.5)),
  ];
  static const _radius = 6.5;

  /// The ring cut round each flag, so the one in front reads as in front.
  static const _ringWidth = 1.6;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final unit = size / _artBox;
    final diameter = _radius * 2 * unit;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          for (final flag in _flags)
            Positioned(
              left: (flag.centre.dx - _radius) * unit,
              top: (flag.centre.dy - _radius) * unit,
              child: Container(
                width: diameter,
                height: diameter,
                foregroundDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.paywallArtCutout,
                    width: _ringWidth * unit,
                  ),
                ),
                child: ClipOval(
                  child: PremiumServerIcon(size: diameter, flagCode: flag.code),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What each row of the paywall's comparison is about, drawn rather than
/// glyphed: a picture of the thing itself reads faster than a symbol for it.
enum PaywallArt { adWait, countries, speed, devices }

/// One of the paywall's pictures, [size] square.
class PremiumPaywallArt extends StatelessWidget {
  const PremiumPaywallArt({
    super.key,
    required this.art,
    required this.size,
    this.adLabel = '',
    this.deviceCount = _comparisonDevices,
  });

  /// The comparison's devices row shows a laptop and a phone: more than one.
  static const _comparisonDevices = 2;

  final PaywallArt art;
  final double size;

  /// The letters on the ad's ring, for [PaywallArt.adWait].
  final String adLabel;

  /// How many devices [PaywallArt.devices] draws.
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    final square = Size.square(size);
    return ExcludeSemantics(
      child: switch (art) {
        PaywallArt.adWait => CustomPaint(
          size: square,
          painter: _AdWaitPainter(
            label: adLabel,
            textDirection: Directionality.of(context),
            ad: palette.paywallArtAd,
            track: palette.paywallArtTrack,
            ink: palette.paywallArtInk,
          ),
        ),
        PaywallArt.countries => _Flags(size: size),
        PaywallArt.speed => CustomPaint(
          size: square,
          painter: _SpeedPainter(
            track: palette.paywallArtTrack,
            speed: palette.paywallArtSpeed,
            ink: palette.paywallArtInk,
          ),
        ),
        PaywallArt.devices => CustomPaint(
          size: square,
          painter: _DeviceSetPainter(
            count: deviceCount,
            laptop: palette.paywallArtLaptop,
            phone: palette.paywallArtPhone,
            cutout: palette.paywallArtCutout,
          ),
        ),
      },
    );
  }
}
