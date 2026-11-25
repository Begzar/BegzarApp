import 'dart:async';
import 'dart:ui' as ui;

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/theme/brand_assets.dart';
import 'package:flutter/material.dart';

/// One layer of the artwork, decoded through the image cache and held for as
/// long as the bird that asked for it.
///
/// This is what [Image] does for itself. The bird needs it done by hand
/// because it paints its layers into each other rather than placing them, so
/// it needs the pixels rather than a widget.
class _Artwork {
  _Artwork(this.asset, this.onDecoded);

  final String asset;

  /// Called when the layer arrives after the frame that asked for it.
  final VoidCallback onDecoded;

  ImageStream? _stream;
  ImageInfo? _decoded;

  late final _listener = ImageStreamListener(_take);

  ui.Image? get image => _decoded?.image;

  void _take(ImageInfo decoded, bool synchronousCall) {
    _decoded?.dispose();
    _decoded = decoded;
    // A layer already in the cache arrives inside the frame that asked for
    // it, before that frame paints, so there is nothing to redraw.
    if (!synchronousCall) onDecoded();
  }

  /// Asks for the layer at [configuration], unless it is already on its way.
  void resolve(ImageConfiguration configuration) {
    final stream = AssetImage(asset).resolve(configuration);
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void dispose() {
    _stream?.removeListener(_listener);
    _decoded?.dispose();
  }
}

/// Paints the bird as etched glass, in the canvas's own terms.
class _GlassBirdPainter extends CustomPainter {
  _GlassBirdPainter({
    required this.outline,
    required this.streaks,
    required this.light,
    required this.glow,
    required this.opacity,
    required this.edge,
    required this.glowBlur,
  });

  /// The corner the light enters from.
  static const _lightFrom = Alignment.topLeft;

  /// How strongly the light fills the body: nearly solid where it enters,
  /// thinning partway across, and clearing towards the far side without
  /// quite leaving it, so the bird reads as a shape of glass the dial shows
  /// through rather than as an outline drawn on it.
  static const _lightAlphas = [0.95, 0.45, 0.12];
  static const _lightStops = [0.0, 0.65, 1.0];

  /// How far the body's light is lifted towards white, so a bird filled with
  /// it stands out from a dial lit the same colour.
  static const _bodyWhitening = 0.2;

  /// The edges facing the light catch it, lifted most of the way to white,
  /// and the edges facing away fall into shade.
  static const _litEdgeWhitening = 0.65;
  static const _litEdgeAlpha = 1.0;
  static const _shadedEdgeAlpha = 0.28;

  /// The whole bird. Only its outline is drawn from: the light, the edges and
  /// the streaks give it every colour it shows.
  final ui.Image? outline;

  /// The two wing streaks alone, on a canvas the size of [outline].
  final ui.Image? streaks;

  final Color light;
  final double glow;
  final double opacity;

  /// How wide each edge is.
  final double edge;

  /// How far the glow round a lit streak spreads.
  final double glowBlur;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = this.outline;
    final streaks = this.streaks;
    if (outline == null || streaks == null) return;

    final bounds = Offset.zero & size;
    final awayFromLight = Offset(-_lightFrom.x, -_lightFrom.y) * edge;

    void drawLayer(ui.Image layer, Paint paint, [Offset shift = Offset.zero]) {
      final source =
          Offset.zero & Size(layer.width.toDouble(), layer.height.toDouble());
      paint.filterQuality = FilterQuality.medium;
      canvas.drawImageRect(layer, source, bounds.shift(shift), paint);
    }

    Paint tinted(Color colour) =>
        Paint()..colorFilter = ColorFilter.mode(colour, BlendMode.srcIn);

    // An edge is the part of the outline that a copy of it, moved one edge
    // width over, no longer covers: moved away from the light, what is left
    // is the side facing it.
    //
    // The colour is laid on the finished edge as the layer composites, not on
    // the outline as it is drawn. Tinting the drawn outline painted a hairline
    // along the top and bottom of its box on GPU renderers, because the
    // artwork's wing and tail touch those sides of the image.
    void drawEdge(Color colour, Offset shift) {
      canvas.saveLayer(bounds, tinted(colour));
      drawLayer(outline, Paint());
      drawLayer(outline, Paint()..blendMode = BlendMode.dstOut, shift);
      canvas.restore();
    }

    final bodyLight = Color.lerp(light, AppPalette.lift, _bodyWhitening)!;
    canvas.saveLayer(bounds, Paint());
    drawLayer(outline, Paint());
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = LinearGradient(
          begin: _lightFrom,
          end: -_lightFrom,
          colors: [
            for (final alpha in _lightAlphas)
              bodyLight.withValues(alpha: alpha * opacity),
          ],
          stops: _lightStops,
        ).createShader(bounds),
    );
    canvas.restore();

    drawEdge(
      AppPalette.shade.withValues(alpha: _shadedEdgeAlpha * opacity),
      -awayFromLight,
    );
    drawEdge(
      Color.lerp(
        light,
        AppPalette.lift,
        _litEdgeWhitening,
      )!.withValues(alpha: _litEdgeAlpha * opacity),
      awayFromLight,
    );

    if (glow > 0) {
      drawLayer(
        streaks,
        tinted(light.withValues(alpha: glow * opacity))
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: glowBlur,
            sigmaY: glowBlur,
          ),
      );
    }
    drawLayer(streaks, tinted(light.withValues(alpha: opacity)));
  }

  @override
  bool shouldRepaint(_GlassBirdPainter oldDelegate) =>
      oldDelegate.outline != outline ||
      oldDelegate.streaks != streaks ||
      oldDelegate.light != light ||
      oldDelegate.glow != glow ||
      oldDelegate.opacity != opacity ||
      oldDelegate.edge != edge ||
      oldDelegate.glowBlur != glowBlur;
}

/// The brand's bird, drawn as a shape of glass.
///
/// Light fills the body from the top left of the screen, nearly solid where
/// it enters, and clears across it so the dial shows through on the far side.
/// The edges facing the light catch it, the edges facing away fall
/// into shade, and the two wing streaks are lit on their own in [light],
/// glowing as strongly as [glow] says.
///
/// It is centred by its weight rather than its box. It is the brand's mark,
/// so it keeps one shape whichever way the screen reads: a right-to-left
/// screen does not mirror it.
class GlassBird extends StatefulWidget {
  const GlassBird({
    super.key,
    required this.height,
    required this.light,
    required this.glow,
    this.opacity = 1,
  });

  /// The edge and the glow as shares of the bird's height, so the bird reads
  /// the same at any size it is drawn.
  static const _edgeShare =
      AppLayout.mainDialBirdEdge / AppLayout.mainDialBirdHeight;
  static const _glowShare =
      AppLayout.mainDialStreakGlow / AppLayout.mainDialBirdHeight;

  /// How tall the bird is drawn. The artwork is taller than it is wide, and
  /// its width follows.
  final double height;

  /// The colour the bird is lit in: the light in its body, the edges that
  /// catch it, and the streaks.
  final Color light;

  /// How strongly the streaks glow, from none at all to full.
  final double glow;

  /// How solid the whole bird is drawn.
  final double opacity;

  /// Decodes the artwork into the image cache, so the first frame that
  /// draws the bird has it rather than a frame or two later. Run while the
  /// launch window is still up.
  ///
  /// A layer that cannot be decoded is left to the bird to ask for again;
  /// launch does not wait on it.
  static Future<void> precacheArtwork() => Future.wait([
    for (final asset in [BrandAssets.bird, BrandAssets.birdAccent])
      _decode(AssetImage(asset)),
  ]);

  static Future<void> _decode(ImageProvider image) {
    final decoded = Completer<void>();
    final stream = image.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void settle() {
      stream.removeListener(listener);
      if (!decoded.isCompleted) decoded.complete();
    }

    listener = ImageStreamListener(
      (_, _) => settle(),
      onError: (_, _) => settle(),
    );
    stream.addListener(listener);
    return decoded.future;
  }

  @override
  State<GlassBird> createState() => _GlassBirdState();
}

class _GlassBirdState extends State<GlassBird> {
  late final _outline = _Artwork(BrandAssets.bird, _redraw);
  late final _streaks = _Artwork(BrandAssets.birdAccent, _redraw);

  void _redraw() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final configuration = createLocalImageConfiguration(context);
    _outline.resolve(configuration);
    _streaks.resolve(configuration);
  }

  @override
  void dispose() {
    _outline.dispose();
    _streaks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outline = _outline.image;
    final height = widget.height;
    final width = outline == null
        ? 0.0
        : height * outline.width / outline.height;

    return RepaintBoundary(
      child: FractionalTranslation(
        translation: BrandAssets.birdOpticalCentring,
        child: CustomPaint(
          size: Size(width, height),
          painter: _GlassBirdPainter(
            outline: outline,
            streaks: _streaks.image,
            light: widget.light,
            glow: widget.glow,
            opacity: widget.opacity,
            edge: height * GlassBird._edgeShare,
            glowBlur: height * GlassBird._glowShare,
          ),
        ),
      ),
    );
  }
}
