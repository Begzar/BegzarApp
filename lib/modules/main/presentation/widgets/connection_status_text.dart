import 'package:begzar/core/layout/app_layout.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:begzar/core/theme/app_fonts.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/l10n/localized_date.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Every measurement the status block is drawn at.
abstract final class _StatusMetrics {
  static double get title => AppLayout.text6xl.sp;
  static double get subtitle => AppLayout.textLg.sp;
  static double get titleToSubtitle => AppLayout.gap4.h;
  static double get sidePadding => AppLayout.gap24.w;

  static const lineHeight = 1.3;
  static const weight = FontWeight.w300;

  /// One line replacing another.
  static const swap = Duration(milliseconds: 200);

  /// How often the session clock is reprinted.
  static const tick = Duration(seconds: 1);

  static const normalLines = 2;

  /// The title's weight and tracking, in em, when it is set in the display
  /// face.
  static const displayWeight = FontWeight.w500;
  static const displayTracking = -0.01;

  /// The clock's weight when it is set in the mono face.
  static const monoWeight = FontWeight.w400;
}

/// What the dial currently means, in words — and, once a tunnel is up, for
/// how long it has been up.
///
/// The title answers the only question this screen is asked: whether the
/// person reading it is protected. The subtitle carries whatever follows from
/// that — the session clock while connected, and otherwise what is happening
/// or what to do next. Why a connect failed is not repeated here: the error
/// toast says it, and the same reason on both showed one error twice.
class ConnectionStatusText extends StatefulWidget {
  const ConnectionStatusText({super.key, required this.connection});

  final ConnectionEntity connection;

  @override
  State<ConnectionStatusText> createState() => _ConnectionStatusTextState();
}

class _ConnectionStatusTextState extends State<ConnectionStatusText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _applyConnection();
  }

  @override
  void didUpdateWidget(ConnectionStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.connection != oldWidget.connection) {
      _applyConnection();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// The clock is the one thing on this screen that changes while nothing
  /// else does, so it is the one thing that needs a timer of its own — and
  /// the timer runs exactly while there is a clock on screen for it to move.
  void _applyConnection() {
    _ticker?.cancel();
    _ticker = widget.connection.connectionDuration == null
        ? null
        : Timer.periodic(_StatusMetrics.tick, (_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connection = widget.connection;
    final key = connection.status.copyKey;
    final elapsed = connection.connectionDuration;

    final display = displayFamilyOf(context);
    final mono = monoFamilyOf(context);
    final titleStyle = _lineStyle(context, _StatusMetrics.title).copyWith(
      fontFamily: display,
      fontWeight: display == null ? null : _StatusMetrics.displayWeight,
      letterSpacing: display == null
          ? null
          : _StatusMetrics.displayTracking * _StatusMetrics.title,
    );
    // At rest the hint is the way in, so it wears the accent the dial's ring
    // does; once a connect is under way it is news and goes back to the ink.
    final subtitleStyle = _lineStyle(context, _StatusMetrics.subtitle).copyWith(
      color: connection.status == ConnectionStatus.ready
          ? MainPalette.of(context).invite
          : null,
    );
    final clockStyle = subtitleStyle.copyWith(
      fontFamily: mono,
      fontWeight: mono == null ? null : _StatusMetrics.monoWeight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AnimatedLine(
          // Keyed on the status alone: the title only changes when the
          // status does.
          swapKey: connection.status.toString(),
          child: Text(
            l10n.connectionTitle(key),
            textAlign: TextAlign.center,
            maxLines: _StatusMetrics.normalLines,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        SizedBox(height: _StatusMetrics.titleToSubtitle),
        _AnimatedLine(
          // The clock's key leaves the reading out: it is reprinted every
          // second, and a key that moved with it would slide the line up the
          // screen once a second for the length of the session.
          swapKey: elapsed != null
              ? '${connection.status}_subtitle_clock'
              : '${connection.status}_subtitle',
          child: elapsed != null
              ? _ElapsedClock(elapsed: elapsed, style: clockStyle)
              : Text(
                  l10n.connectionSubtitle(key, Theme.of(context).platform),
                  textAlign: TextAlign.center,
                  maxLines: _StatusMetrics.normalLines,
                  overflow: TextOverflow.ellipsis,
                  style: subtitleStyle,
                ),
        ),
      ],
    );
  }
}

/// The status block's type, resolved against the ambient style.
///
/// Resolved rather than left to inherit, because [_ElapsedClock] measures its
/// own glyphs and a painter has to be handed the same face the widget will
/// draw with — an unresolved style carries no font family and would be
/// measured in the platform default.
TextStyle _lineStyle(BuildContext context, double fontSize) =>
    DefaultTextStyle.of(context).style.merge(
      TextStyle(
        color: MainPalette.of(context).idle,
        fontSize: fontSize,
        fontWeight: _StatusMetrics.weight,
        height: _StatusMetrics.lineHeight,
      ),
    );

/// How long the tunnel has been up, laid out so the reading does not move as
/// it counts.
///
/// Neither face the app ships draws its digits at a single width — a Poppins
/// `1` is under half the width of its `0` — and only Estedad carries the
/// `tnum` feature that would even them out. A centred clock built from plain
/// text therefore re-centres itself on almost every tick, which reads as the
/// line breathing rather than as a clock running. Each digit gets a cell as
/// wide as the widest digit the language writes instead, and the separators
/// keep their own width.
class _ElapsedClock extends StatelessWidget {
  const _ElapsedClock({required this.elapsed, required this.style});

  final Duration elapsed;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).toString();
    final digits = LocalizedDate.digits(localeName);
    final written = LocalizedDate.elapsed(elapsed, localeName);
    final cell = _cellWidth(context, digits);

    // One reading to anything that speaks the screen. Without this the row
    // of one-glyph cells below is announced a character at a time, which is
    // how a clock stops being a clock.
    return Semantics(
      label: written,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // The fields read hours-minutes-seconds in every language, Persian
        // included, the same way the app writes a time of day.
        textDirection: TextDirection.ltr,
        children: [
          for (final glyph in written.split(''))
            if (digits.contains(glyph))
              SizedBox(
                width: cell,
                child: Text(glyph, textAlign: TextAlign.center, style: style),
              )
            else
              Text(glyph, style: style),
        ],
      ),
    );
  }

  /// The width of the widest of [digits] at this style.
  ///
  /// Measured rather than assumed: the two faces disagree about which digit
  /// is widest, and the Persian set is a different set of glyphs again. Ten
  /// single-glyph layouts, once a second, is nothing next to the dial
  /// repainting beside it every frame.
  double _cellWidth(BuildContext context, String digits) {
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;

    for (final digit in digits.split('')) {
      final painter = TextPainter(
        text: TextSpan(text: digit, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }

    return widest;
  }
}

class _AnimatedLine extends StatelessWidget {
  const _AnimatedLine({required this.swapKey, required this.child});

  final String swapKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _StatusMetrics.swap,
      // Rises into place, so a status change reads as the next line arriving
      // rather than the same line changing its mind.
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Padding(
        key: ValueKey<String>(swapKey),
        padding: EdgeInsets.symmetric(horizontal: _StatusMetrics.sidePadding),
        child: child,
      ),
    );
  }
}

/// The localization key each status is written under.
///
/// A method on the enum rather than a switch in the widget, so adding a
/// status is a compile error here instead of a missing string at runtime.
extension ConnectionStatusCopy on ConnectionStatus {
  String get copyKey => switch (this) {
    ConnectionStatus.connecting => 'connecting',
    ConnectionStatus.disconnecting => 'disconnecting',
    ConnectionStatus.connected => 'connected',
    ConnectionStatus.error => 'error',
    ConnectionStatus.ready => 'ready',
  };
}
