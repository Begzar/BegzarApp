import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/main/presentation/main_palette.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_dial.dart';
import 'package:begzar/modules/main/presentation/widgets/glass_bird.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the home screen is laid out for, which is what ScreenUtil scales
/// against.
const _designSize = Size(393, 852);

/// Far enough into the 3500ms loop for a ring to have travelled a visible
/// distance, and well short of the wrap that would let the two directions
/// agree with each other.
const _step = Duration(milliseconds: 500);

/// Far enough into the 2000ms breath that the dial is nowhere near the size
/// it rests at, so a status arriving here has something to settle from.
const _midBreath = Duration(milliseconds: 900);

const _oneFrame = Duration(milliseconds: 16);

/// The scale is a product of two animations, so it is compared rather than
/// matched exactly.
const _tolerance = 0.002;

/// The palette the dial is pumped in: the dark one a bare test app gets.
const _palette = MainPalette(AppPalette.dark);

/// The colour each status lights the dial in.
final _lights = {
  ConnectionStatus.ready: MainPalette.dialAtRest,
  ConnectionStatus.connecting: _palette.inFlight,
  ConnectionStatus.disconnecting: _palette.inFlight,
  ConnectionStatus.connected: _palette.connected,
  ConnectionStatus.error: _palette.failedInk,
};

/// The statuses the dial has something to say about, which is every one but
/// rest.
final _reporting = _lights.keys.where(
  (status) => status != ConnectionStatus.ready,
);

void main() {
  /// Mounts the dial in one status, without settling: every state under test
  /// either runs forever or does not animate at all, so there is nothing to
  /// settle to. [direction] stands in for the language the screen reads in.
  Future<void> pumpDial(
    WidgetTester tester,
    ConnectionStatus status, {
    TextDirection direction = TextDirection.ltr,
    bool invite = true,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: _designSize,
        builder: (context, _) => MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: direction,
              child: Center(
                child: ConnectionDial(
                  status: status,
                  pressed: false,
                  invite: invite,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // ScreenUtilInit hands its builder a size on the frame after the first.
    await tester.pump();
  }

  /// Lets a change of status finish easing in.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(MainPalette.stateChange + _oneFrame);

  /// The expanding circles, found by the shape they are rather than by a key
  /// added for the test's benefit.
  Finder ringFinder() => find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    if (decoration.shape != BoxShape.circle) return false;
    // Wave rings are border-only; the dial itself is glass.
    return decoration.color == null && decoration.gradient == null;
  }, description: 'a ring');

  /// The bird at the centre of the dial.
  GlassBird bird(WidgetTester tester) =>
      tester.widget<GlassBird>(find.byType(GlassBird));

  /// The glass the dial is made of: the panel the bird sits in.
  AppGlassStyle glass(WidgetTester tester) => tester
      .widget<AppGlassPanel>(
        find
            .ancestor(
              of: find.byType(GlassBird),
              matching: find.byType(AppGlassPanel),
            )
            .first,
      )
      .style;

  /// The factor a [Transform.scale] is applying.
  ///
  /// Read straight off the horizontal axis rather than through
  /// `getMaxScaleOnAxis`, which also considers the untouched z column and so
  /// reports 1.0 for anything drawn smaller than full size.
  double scaleOf(WidgetTester tester, Finder finder) =>
      tester.widget<Transform>(finder).transform.storage[0];

  /// The scale the whole dial is drawn at — the press and the breath
  /// multiplied together, which is the outermost transform in the widget.
  double dialScale(WidgetTester tester) => scaleOf(
    tester,
    find
        .descendant(
          of: find.byType(ConnectionDial),
          matching: find.byType(Transform),
        )
        .first,
  );

  /// How far out ring [index] currently sits, read off the scale its own
  /// transform is carrying.
  double ringScale(WidgetTester tester, int index) => scaleOf(
    tester,
    find
        .ancestor(of: ringFinder().at(index), matching: find.byType(Transform))
        .first,
  );

  /// The outline the first ring is drawn with.
  Border ringBorder(WidgetTester tester) {
    final ring = tester.widget<Container>(ringFinder().first);
    return (ring.decoration! as BoxDecoration).border! as Border;
  }

  /// Anything of [matching] drawn inside the dial.
  Finder inDial(Finder matching) =>
      find.descendant(of: find.byType(ConnectionDial), matching: matching);

  group('the rings say which way the tunnel is going', () {
    // The direction is the whole of the distinction: the same four numbers run
    // one way mean traffic leaving a tunnel that is up, and the other way mean
    // one being reached for. A change that quietly reversed either would leave
    // the dial saying the opposite of what is happening.
    testWidgets('connected sends them outward', (tester) async {
      await pumpDial(tester, ConnectionStatus.connected);
      final started = ringScale(tester, 0);

      await tester.pump(_step);

      expect(ringScale(tester, 0), greaterThan(started));
    });

    testWidgets('connecting brings them inward', (tester) async {
      await pumpDial(tester, ConnectionStatus.connecting);
      final started = ringScale(tester, 0);

      await tester.pump(_step);

      expect(ringScale(tester, 0), lessThan(started));
    });

    testWidgets('a teardown draws none', (tester) async {
      await pumpDial(tester, ConnectionStatus.disconnecting);

      expect(ringFinder(), findsNothing);
    });

    testWidgets('a dial at rest draws none', (tester) async {
      await pumpDial(tester, ConnectionStatus.ready);

      expect(ringFinder(), findsNothing);
    });

    testWidgets('a failed connect draws none', (tester) async {
      await pumpDial(tester, ConnectionStatus.error);

      expect(ringFinder(), findsNothing);
    });

    testWidgets('they are painted in the status colour', (tester) async {
      await pumpDial(tester, ConnectionStatus.connecting);

      final border = ringBorder(tester);

      expect(border.top.color.withValues(alpha: 1), _palette.inFlight);
    });

    // The fade used to be an Opacity widget per ring, which is four offscreen
    // layers on every frame of a loop that never stops. The border colour
    // carries the same fade for nothing: alpha is a value the painter already
    // reads, not a layer it has to allocate.
    testWidgets('they fade through the colour, not a layer', (tester) async {
      await pumpDial(tester, ConnectionStatus.connected);

      expect(
        find.descendant(
          of: find.byType(ConnectionDial),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      expect(ringBorder(tester).top.color.a, lessThan(1.0));
    });
  });

  group('the rings that invite a tap at rest', () {
    /// How strongly the invite rings are drawn, or null when they are not.
    double? inviteStrength(WidgetTester tester) {
      final rings = find.byKey(ConnectionDial.inviteKey);
      if (rings.evaluate().isEmpty) return null;
      return (tester.widget<CustomPaint>(rings).painter! as dynamic).strength
          as double;
    }

    testWidgets('are drawn round a dial at rest', (tester) async {
      await pumpDial(tester, ConnectionStatus.ready);

      expect(inviteStrength(tester), 1);
    });

    // The launch dial stands for the home dial without being pressable.
    testWidgets('are left out of a dial told not to invite', (tester) async {
      await pumpDial(tester, ConnectionStatus.ready, invite: false);

      expect(inviteStrength(tester), isNull);
    });

    // Taking over from the launch dial, which has none, they come in rather
    // than appearing whole in one frame.
    testWidgets('fade in when the dial starts inviting', (tester) async {
      await pumpDial(tester, ConnectionStatus.ready, invite: false);

      await pumpDial(tester, ConnectionStatus.ready);
      final arriving = inviteStrength(tester)!;
      await tester.pump(MainPalette.dialInviteReveal + _oneFrame);

      expect(arriving, lessThan(0.5));
      expect(inviteStrength(tester), 1);
    });

    /// Where the moving ring is in its breath, from 0 to 1.
    double inviteProgress(WidgetTester tester) =>
        (tester
                        .widget<CustomPaint>(
                          find.byKey(ConnectionDial.inviteKey),
                        )
                        .painter!
                    as dynamic)
                .progress
            as double;

    // A breath is drawn on every frame, and the screen under it redraws with
    // it, blurred nav bar included.
    testWidgets('should still be breathing just before the breath ends', (
      tester,
    ) async {
      await pumpDial(tester, ConnectionStatus.ready);

      await tester.pump(MainPalette.dialInvite - _step);

      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    // Between breaths nothing moves, so the screen stops drawing frames. With
    // the next breath starting the moment one ended, the home screen never
    // stopped, and it re-blurred the nav bar at the display's full rate.
    testWidgets('should draw no frames once a breath ends', (tester) async {
      await pumpDial(tester, ConnectionStatus.ready);

      await tester.pump(MainPalette.dialInvite + _oneFrame);

      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(inviteProgress(tester), 1);
    });

    testWidgets('should still be resting just before the rest ends', (
      tester,
    ) async {
      await pumpDial(tester, ConnectionStatus.ready);
      await tester.pump(MainPalette.dialInvite + _oneFrame);

      await tester.pump(MainPalette.dialInviteRest - _step);

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('should breathe again once the rest is over', (tester) async {
      await pumpDial(tester, ConnectionStatus.ready);
      await tester.pump(MainPalette.dialInvite + _oneFrame);
      await tester.pump(MainPalette.dialInviteRest);

      await tester.pump(_step);

      expect(inviteProgress(tester), greaterThan(0));
      expect(inviteProgress(tester), lessThan(1));
    });
  });

  group('a dial that is not breathing is drawn at its full size', () {
    // The breath tween runs 0.95 to 1.05, and stopping its controller leaves
    // whatever value it held. So a cold start rested 5% under the size the
    // layout reserves, and a dial that stopped mid-breath rested at an
    // arbitrary size — two identical screens could differ by a tenth of the
    // dial depending on when the tunnel came down.
    testWidgets('on a cold start', (tester) async {
      await pumpDial(tester, ConnectionStatus.ready);

      expect(dialScale(tester), closeTo(1.0, _tolerance));
    });

    testWidgets('after a tunnel comes down mid-breath', (tester) async {
      await pumpDial(tester, ConnectionStatus.connected);
      await tester.pump(_midBreath);

      await pumpDial(tester, ConnectionStatus.ready);
      await tester.pump(MainPalette.stateChange + _oneFrame);

      expect(dialScale(tester), closeTo(1.0, _tolerance));
    });

    testWidgets('after a connect fails mid-breath', (tester) async {
      await pumpDial(tester, ConnectionStatus.connecting);
      await tester.pump(_midBreath);

      await pumpDial(tester, ConnectionStatus.error);
      await tester.pump(MainPalette.stateChange + _oneFrame);

      expect(dialScale(tester), closeTo(1.0, _tolerance));
    });
  });

  group('the centre of the dial', () {
    // The bird is the brand, so it stays through every state, a wait
    // included: the light it is drawn in says which state it is.
    testWidgets('draws the bird in every state', (tester) async {
      for (final status in ConnectionStatus.values) {
        await pumpDial(tester, status);

        expect(find.byType(GlassBird), findsOneWidget, reason: '$status');
      }
    });

    testWidgets('lights the bird in the colour of the status', (tester) async {
      for (final MapEntry(key: status, value: light) in _lights.entries) {
        await pumpDial(tester, status);
        await settle(tester);

        expect(bird(tester).light, light, reason: '$status');
      }
    });

    // At rest the bird is lit in the blue of its own streaks, which is the
    // brand rather than news. Only a status the dial is reporting makes the
    // streaks glow.
    testWidgets('glows the streaks only while there is a status to report', (
      tester,
    ) async {
      await pumpDial(tester, ConnectionStatus.ready);
      expect(bird(tester).glow, 0);

      for (final status in _reporting) {
        await pumpDial(tester, status);
        await settle(tester);

        expect(bird(tester).glow, 1, reason: '$status');
      }
    });

    testWidgets('eases the light into a new status rather than snapping', (
      tester,
    ) async {
      await pumpDial(tester, ConnectionStatus.connected);

      await pumpDial(tester, ConnectionStatus.error);
      await tester.pump(MainPalette.stateChange ~/ 2);

      expect(bird(tester).light, isNot(_palette.connected));
      expect(bird(tester).light, isNot(_palette.failedInk));

      await settle(tester);
      expect(bird(tester).light, _palette.failedInk);
    });

    testWidgets('fades the bird in and out while a tunnel is in flight', (
      tester,
    ) async {
      for (final status in [
        ConnectionStatus.connecting,
        ConnectionStatus.disconnecting,
      ]) {
        await pumpDial(tester, status);
        final started = bird(tester).opacity;

        await tester.pump(_midBreath);

        expect(
          bird(tester).opacity,
          isNot(closeTo(started, _tolerance)),
          reason: '$status',
        );
        expect(bird(tester).opacity, lessThan(1.0), reason: '$status');
      }
    });

    testWidgets('holds the bird solid once a state settles', (tester) async {
      // Connected breathes too, and is in this list for that reason: the fade
      // is for a wait, not for a tunnel that is up.
      for (final status in [
        ConnectionStatus.ready,
        ConnectionStatus.connected,
        ConnectionStatus.error,
      ]) {
        await pumpDial(tester, status);
        await tester.pump(_midBreath);

        expect(bird(tester).opacity, 1.0, reason: '$status');
      }
    });
  });

  group('the glass of the dial', () {
    // The dial rests on the page the way the server row and the IP reading
    // do, so the three read as one set of objects: the same hairline rim and
    // the same shadow under it.
    testWidgets('casts the rim and shadow every home surface does', (
      tester,
    ) async {
      await pumpDial(tester, ConnectionStatus.ready);
      final surface = AppGlass.homeSurface(
        AppPalette.dark,
        cornerRadius: 0,
        borderColor: const PremiumPalette(AppPalette.dark).border,
      );

      expect(glass(tester).shape, BoxShape.circle);
      expect(glass(tester).borderWidth, surface.borderWidth);
      expect(glass(tester).boxShadow!.first, surface.boxShadow!.single);
    });

    // A film of white the size of the dial turns the saturated page under it
    // grey: khaki while a connect is in flight, brown after a failed one. The
    // glass is tinted with the dial's own light instead, strongest where the
    // light enters at the top left, and eases with it from status to status.
    testWidgets('tints its glass with its own light in every status', (
      tester,
    ) async {
      for (final MapEntry(key: status, value: light) in _lights.entries) {
        await pumpDial(tester, status);
        await settle(tester);
        final tint = glass(tester).gradientColors;

        expect(tint, isNotNull, reason: '$status');
        for (final stop in tint!) {
          expect(stop.withValues(alpha: 1), light, reason: '$status');
        }
        expect(
          tint.first.a,
          greaterThan(tint.last.a),
          reason: '$status: denser where the light enters',
        );
      }
    });

    // A shadow is drawn under its box as well as round it. Under glass this
    // clear that would lay a film of the glow across the whole disc, and the
    // pale red of a failed connect turned it brown, so the glow is kept to
    // the outside.
    testWidgets('keeps its glow outside the glass', (tester) async {
      for (final status in _reporting) {
        await pumpDial(tester, status);
        await settle(tester);

        expect(
          glass(tester).boxShadow!.last.blurStyle,
          BlurStyle.outer,
          reason: '$status',
        );
      }
    });

    testWidgets('is rimmed in plain glass at rest, with no glow', (
      tester,
    ) async {
      await pumpDial(tester, ConnectionStatus.ready);

      expect(
        glass(tester).borderColor,
        const PremiumPalette(AppPalette.dark).border,
      );
      expect(
        glass(tester).boxShadow,
        hasLength(1),
        reason: 'the drop shadow every home surface casts, and nothing else',
      );
    });

    // The rim takes a status the way the server row's does, at the same
    // strength, and the glow round it is the same light the bird is lit in.
    testWidgets('takes the status colour for its rim and its glow', (
      tester,
    ) async {
      for (final status in _reporting) {
        await pumpDial(tester, status);
        await settle(tester);
        final light = _lights[status]!;

        expect(
          glass(tester).borderColor,
          light.withValues(alpha: PremiumPalette.liveAlpha),
          reason: '$status',
        );
        expect(
          glass(tester).boxShadow!.last.color.withValues(alpha: 1),
          light,
          reason: '$status',
        );
      }
    });
  });

  group('the rim of the dial', () {
    // The dial says its status through its light and the line of text under
    // it, so the rim is left to the glass: no glyph is set into it in any
    // state, a wait included.
    testWidgets('carries no badge in any state', (tester) async {
      for (final status in ConnectionStatus.values) {
        await pumpDial(tester, status);
        await settle(tester);

        expect(inDial(find.byType(Icon)), findsNothing, reason: '$status');
        expect(
          inDial(find.byType(AppGlassPanel)),
          findsOneWidget,
          reason: 'the dial itself, and no bead set into its rim',
        );
      }
    });
  });
}
