import 'dart:async';
import 'dart:math' as math;

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Which of the pass's three looks it wears.
enum PremiumPassTone {
  /// Signed in and entitled: the blue pass, with light passing over it.
  entitled,

  /// Signed in, never paid: an outline waiting to be filled.
  open,

  /// The subscription lapsed, or the account was disabled: the pass in red.
  lapsed,
}

String _passEmailDisplay(String email) {
  const max = AppLayout.premiumPassUserEmailMaxChars;
  if (email.length <= max) return email;
  return '${email.substring(0, max)}…';
}

/// The subscription drawn as a membership card, at the top of the signed-in
/// account tab.
///
/// The card carries who is signed in and where the account stands; what it
/// says underneath — the days left, or the way out of having none — is the
/// caller's [body], because that is where the three states differ.
class PremiumPassCard extends StatefulWidget {
  const PremiumPassCard({
    super.key,
    required this.tone,
    required this.planLabel,
    required this.username,
    this.email,
    required this.body,
    this.statusLabel,
    this.tierLabel,
    this.isBusy = false,
  });

  final PremiumPassTone tone;

  /// The plan, as the corner label: Premium, or Basic.
  final String planLabel;
  final String username;

  /// Shown under [username] when the server sent one and it is not the same
  /// text as the username.
  final String? email;
  final Widget body;

  /// The live chip opposite the plan, with its dot.
  final String? statusLabel;

  /// A plain tag opposite the plan, for a pass with no live status.
  final String? tierLabel;

  /// Shows a spinner in the chip's place while the account is being re-read.
  final bool isBusy;

  @override
  State<PremiumPassCard> createState() => _PremiumPassCardState();
}

class _PremiumPassCardState extends State<PremiumPassCard>
    with SingleTickerProviderStateMixin {
  /// Made in [initState] rather than on first use: a pass that never shines
  /// would otherwise first touch it in [dispose], and creating its ticker on a
  /// card already being taken down looks up an ancestor that is gone.
  late final AnimationController _sheen;

  /// Starts each pass of light. A timer between finite sweeps rather than a
  /// repeating controller, so the card is at rest between them and a test
  /// that waits for the screen to settle is not waiting forever.
  Timer? _sheenTimer;

  /// Whether the card is its own artwork rather than a surface of the page:
  /// the live pass in blue and the lapsed one in red, navy and near-black on
  /// a dark page and the accent's own tones on a light one.
  bool get _isArtwork => widget.tone != PremiumPassTone.open;

  /// Whether the page is light, which the artwork is drawn brighter on.
  bool get _onLightPage => PremiumPalette.of(context).onLightPage;

  /// What everything drawn on the artwork reads: the dark palette on the
  /// night pass, and the white inks of [PremiumPalette.passDayInk] on the day
  /// one.
  AppPalette get _artworkInk =>
      _onLightPage ? PremiumPalette.passDayInk : AppPalette.dark;

  /// The tint of the captions on the artwork.
  Color get _caption =>
      _onLightPage ? PremiumPalette.passDayCaption : PremiumPalette.accentInk;

  /// The palette the card's helpers draw in: the artwork's ink on a pass that
  /// is artwork, so it reads on it whichever theme the page is in, and the
  /// page's own on an open pass.
  PremiumPalette get palette =>
      _isArtwork ? PremiumPalette(_artworkInk) : PremiumPalette.of(context);

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(
      vsync: this,
      duration: PremiumPalette.sheenSweep,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSheen();
  }

  @override
  void didUpdateWidget(PremiumPassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSheen();
  }

  /// Only the entitled pass shines, and never for a reader who has asked the
  /// system for less motion.
  void _syncSheen() {
    final animate =
        widget.tone == PremiumPassTone.entitled &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && _sheenTimer == null) {
      _sheen.forward(from: 0);
      _sheenTimer = Timer.periodic(PremiumPalette.sheenCycle, (_) {
        if (mounted) _sheen.forward(from: 0);
      });
    } else if (!animate && _sheenTimer != null) {
      _sheenTimer?.cancel();
      _sheenTimer = null;
      _sheen.stop();
      _sheen.value = 0;
    }
  }

  @override
  void dispose() {
    _sheenTimer?.cancel();
    _sheen.dispose();
    super.dispose();
  }

  BoxDecoration _frame(BorderRadius radius) => switch (widget.tone) {
    PremiumPassTone.entitled => BoxDecoration(
      borderRadius: radius,
      gradient: RadialGradient(
        center: AlignmentDirectional.topEnd,
        radius: 1.4,
        colors: _onLightPage
            ? PremiumPalette.passEntitledDay
            : PremiumPalette.passEntitled,
        stops: PremiumPalette.passStops,
      ),
      border: Border.all(
        color: palette.accent.withValues(alpha: PremiumPalette.passRimAlpha),
      ),
    ),
    PremiumPassTone.lapsed => BoxDecoration(
      borderRadius: radius,
      gradient: RadialGradient(
        center: AlignmentDirectional.topEnd,
        radius: 1.4,
        colors: _onLightPage
            ? PremiumPalette.passLapsedDay
            : PremiumPalette.passLapsed,
        stops: PremiumPalette.passStops,
      ),
      border: Border.all(
        color: palette.danger.withValues(alpha: PremiumPalette.passRimAlpha),
      ),
    ),
    PremiumPassTone.open => BoxDecoration(
      borderRadius: radius,
      color: palette.inkSurface,
    ),
  };

  List<Color> get _rings => switch (widget.tone) {
    PremiumPassTone.entitled => [
      for (final alpha in PremiumPalette.passRingAlphas)
        palette.accent.withValues(alpha: alpha),
    ],
    PremiumPassTone.lapsed => [
      for (final alpha in PremiumPalette.passRingAlphas)
        palette.danger.withValues(alpha: alpha),
    ],
    PremiumPassTone.open => [
      for (final _ in PremiumPalette.passRingAlphas)
        PremiumPalette.passRingQuiet,
    ],
  };

  Color get _labelColour => switch (widget.tone) {
    PremiumPassTone.entitled => _caption.withValues(
      alpha: PremiumPalette.passLabelAlpha,
    ),
    PremiumPassTone.lapsed => palette.danger,
    PremiumPassTone.open => palette.inkFaint,
  };

  Color get _chipColour => switch (widget.tone) {
    PremiumPassTone.entitled => palette.good,
    PremiumPassTone.lapsed => palette.danger,
    PremiumPassTone.open => palette.inkMuted,
  };

  /// What sits opposite the plan while nothing is loading.
  Widget? _restingTrailing(bool tracked) {
    if (widget.statusLabel != null) {
      return _StatusChip(label: widget.statusLabel!, colour: _chipColour);
    }
    if (widget.tierLabel != null) {
      return _TierTag(label: widget.tierLabel!, tracked: tracked);
    }
    return null;
  }

  Widget _topRow(bool tracked) {
    final Widget? trailing;
    if (widget.isBusy) {
      // The spinner is shorter than the chip it stands in for, and the row
      // takes its height from whichever is there — so swapping one for the
      // other lifted everything under it by the difference. The chip stays
      // in the layout, unseen, to hold the row at its resting height; with
      // no chip to hold it, an empty one stands in.
      final holder =
          _restingTrailing(tracked) ??
          _StatusChip(label: '', colour: _chipColour);
      trailing = Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: holder,
          ),
          SizedBox.square(
            dimension: AppLayout.premiumPassSpinner.sp,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _chipColour,
            ),
          ),
        ],
      );
    } else {
      trailing = _restingTrailing(tracked);
    }

    return Row(
      children: [
        Expanded(
          // A plan name is a word, so the body face like the plan badge in
          // the app bar; the mono face is kept for the username below.
          child: Text(
            tracked ? widget.planLabel.toUpperCase() : widget.planLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppLayout.premiumPassLabel.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: tracked
                  ? AppLayout.premiumPassLabelTracking
                  : null,
              color: _labelColour,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _user() {
    final email = widget.email?.trim();
    final showEmail =
        email != null && email.isNotEmpty && email != widget.username.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Iconsax.user,
          size: AppLayout.premiumPassUserGlyph.sp,
          color: palette.inkText,
        ),
        SizedBox(width: AppLayout.premiumPassUserGap.w),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // A username reads left to right in every locale.
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontFamily: monoFamilyOf(context),
                  fontSize: AppLayout.premiumPassUser.sp,
                  color: palette.inkText,
                ),
              ),
              if (showEmail) ...[
                SizedBox(height: AppLayout.gap4.h),
                Text(
                  _passEmailDisplay(email),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: monoFamilyOf(context),
                    fontSize: AppLayout.premiumPassCaption.sp,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppLayout.premiumPassRadius.r);
    final rings = AppLayout.premiumPassRings.w;
    // Letter-spacing pulls Persian's joined letters apart, so the tracked
    // corner label is a Latin-script treatment only.
    final tracked = Localizations.localeOf(context).languageCode != 'fa';
    final userGap = SizedBox(height: AppLayout.premiumPassUserTopGap.h);

    // The live pass spreads its three parts down the card; the others keep
    // the account and its message together at the foot.
    final children = widget.tone == PremiumPassTone.entitled
        ? [
            _topRow(tracked),
            Padding(
              padding: EdgeInsets.only(top: AppLayout.premiumPassUserTopGap.h),
              child: _user(),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: AppLayout.premiumPassBottomTopGap.h,
              ),
              child: widget.body,
            ),
          ]
        : [
            _topRow(tracked),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [userGap, _user(), widget.body],
            ),
          ];

    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: AppLayout.premiumPassMinHeight.h),
      child: Padding(
        padding: EdgeInsets.all(AppLayout.premiumPassPad.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );

    final card = DecoratedBox(
      decoration: _frame(radius),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          foregroundPainter: widget.tone == PremiumPassTone.open
              ? PremiumDashedRimPainter(
                  colour: palette.inkLineStrong,
                  radius: AppLayout.premiumPassRadius.r,
                  dash: AppLayout.premiumPassDash.w,
                  gap: AppLayout.premiumPassDashGap.w,
                )
              : null,
          child: Stack(
            children: [
              PositionedDirectional(
                top: -AppLayout.premiumPassRingsInset.w,
                end: -AppLayout.premiumPassRingsInset.w,
                width: rings,
                height: rings,
                child: IgnorePointer(
                  child: CustomPaint(painter: _RingsPainter(colours: _rings)),
                ),
              ),
              if (widget.tone == PremiumPassTone.entitled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _sheen,
                      builder: (context, _) {
                        final sweep = Curves.easeInOut.transform(_sheen.value);
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: const Alignment(-1, -0.47),
                              end: const Alignment(1, 0.47),
                              colors: [
                                Colors.transparent,
                                PremiumPalette.sheenLight.withValues(
                                  alpha: PremiumPalette.passSheenAlpha,
                                ),
                                Colors.transparent,
                              ],
                              stops: const [0.3, 0.45, 0.6],
                              transform: _Slide(1.2 - 2.4 * sweep),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              content,
            ],
          ),
        ),
      ),
    );

    if (!_isArtwork) return card;

    // Everything drawn on the artwork — the chip, the tier tag, whatever the
    // caller puts in the body — reads the artwork's ink, as the card does.
    return Theme(
      data: Theme.of(context).copyWith(extensions: [_artworkInk]),
      child: PremiumPassCaption(colour: _caption, child: card),
    );
  }
}

/// The tint of the captions on a pass's artwork, for whatever the caller
/// puts in its body: pale blue on the night pass, near-white on the day one,
/// where pale blue sinks into the card.
class PremiumPassCaption extends InheritedWidget {
  const PremiumPassCaption({
    super.key,
    required this.colour,
    required super.child,
  });

  final Color colour;

  /// The caption tint of the pass around [context], or the night pass's
  /// outside of one.
  static Color of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PremiumPassCaption>()
          ?.colour ??
      PremiumPalette.accentInk;

  @override
  bool updateShouldNotify(PremiumPassCaption oldWidget) =>
      oldWidget.colour != colour;
}

/// The pill opposite the plan: a dot and a word, in the state's colour.
///
/// The dot used to breathe a ring out round itself on a live subscription.
/// That was a glow, and on this app only the dial casts one; the chip's
/// colour and word already say the subscription is live.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.colour});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final dot = AppLayout.premiumPassDot.w;

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppLayout.premiumPassChipPadStart.w,
        AppLayout.premiumPassChipPadV.h,
        AppLayout.premiumPassChipPadEnd.w,
        AppLayout.premiumPassChipPadV.h,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: PremiumPalette.chipFillAlpha),
        borderRadius: BorderRadius.circular(AppLayout.radiusPill.r),
        border: Border.all(
          color: colour.withValues(alpha: PremiumPalette.chipRimAlpha),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          SizedBox(width: AppLayout.premiumPassDotGap.w),
          Text(
            label,
            style: TextStyle(
              fontSize: AppLayout.premiumPassChipLabel.sp,
              fontWeight: FontWeight.w500,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain outlined tag, for the plan a pass with no subscription is on.
class _TierTag extends StatelessWidget {
  const _TierTag({required this.label, required this.tracked});

  final String label;
  final bool tracked;

  @override
  Widget build(BuildContext context) {
    final palette = PremiumPalette.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.premiumPassTierPadH.w,
        vertical: AppLayout.premiumPassTierPadV.h,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppLayout.premiumPassTierRadius.r),
        border: Border.all(color: palette.inkLineStrong),
      ),
      child: Text(
        tracked ? label.toUpperCase() : label,
        style: TextStyle(
          fontSize: AppLayout.premiumPassTierLabel.sp,
          letterSpacing: tracked ? AppLayout.premiumPassTierTracking : null,
          color: palette.inkMuted,
        ),
      ),
    );
  }
}

/// Moves a gradient sideways by [offset] widths of its box.
class _Slide extends GradientTransform {
  const _Slide(this.offset);

  final double offset;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * offset, 0, 0);
}

/// Concentric rings in the pass's corner, one colour each, outermost first.
class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.colours});

  final List<Color> colours;

  /// Each ring sits this share of the outer radius inside the last.
  static const _step = 26 / 110;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final outer = size.shortestSide / 2;

    for (final (ring, colour) in colours.indexed) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colour;
      canvas.drawCircle(centre, outer * (1 - _step * ring), paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      !_sameColours(oldDelegate.colours, colours);

  static bool _sameColours(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// A dashed rounded rim: the open pass's outline with nothing in it yet,
/// and the perks under the sign-in form.
class PremiumDashedRimPainter extends CustomPainter {
  const PremiumDashedRimPainter({
    required this.colour,
    required this.radius,
    required this.dash,
    required this.gap,
  });

  final Color colour;
  final double radius;
  final double dash;
  final double gap;

  static const _stroke = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = colour;
    final rim = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(_stroke / 2),
      Radius.circular(radius),
    );

    for (final metric in (Path()..addRRect(rim)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(PremiumDashedRimPainter oldDelegate) =>
      oldDelegate.colour != colour ||
      oldDelegate.radius != radius ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}
