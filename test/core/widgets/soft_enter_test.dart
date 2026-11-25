import 'package:begzar/core/widgets/soft_enter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _fade = Duration(milliseconds: 480);
const _oneFrame = Duration(milliseconds: 16);

void main() {
  late BuildContext probe;

  /// Mounts a spinner, which animates for as long as its tickers are on,
  /// inside a [SoftEnter] that is [visible] or not.
  Future<void> pumpSoftEnter(WidgetTester tester, {required bool visible}) =>
      tester.pumpWidget(
        MaterialApp(
          home: SoftEnter(
            visible: visible,
            duration: _fade,
            child: Builder(
              builder: (context) {
                probe = context;
                return const CircularProgressIndicator();
              },
            ),
          ),
        ),
      );

  group('SoftEnter', () {
    testWidgets('should keep a visible child animating', (tester) async {
      await pumpSoftEnter(tester, visible: true);
      await tester.pump(_fade + _oneFrame);

      expect(TickerMode.valuesOf(probe).enabled, isTrue);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    // The home screen's address panel sits hidden while no tunnel is up, and
    // its loading shimmer kept the whole screen drawing at the display's rate.
    testWidgets('should draw no frames for a child that is hidden', (
      tester,
    ) async {
      await pumpSoftEnter(tester, visible: false);
      await tester.pump(_oneFrame);

      expect(TickerMode.valuesOf(probe).enabled, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('should keep the child animating while it fades out', (
      tester,
    ) async {
      await pumpSoftEnter(tester, visible: true);
      await tester.pump(_fade + _oneFrame);

      await pumpSoftEnter(tester, visible: false);
      await tester.pump(_fade - _oneFrame * 4);

      expect(TickerMode.valuesOf(probe).enabled, isTrue);
    });

    testWidgets('should stop the child once it has faded out', (tester) async {
      await pumpSoftEnter(tester, visible: true);
      await tester.pump(_fade + _oneFrame);

      await pumpSoftEnter(tester, visible: false);
      await tester.pump(_fade + _oneFrame);
      // The frame that ends the fade is the one that mutes the child.
      await tester.pump(_oneFrame);

      expect(TickerMode.valuesOf(probe).enabled, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('should start the child again as it fades back in', (
      tester,
    ) async {
      await pumpSoftEnter(tester, visible: false);
      await tester.pump(_oneFrame);

      await pumpSoftEnter(tester, visible: true);
      await tester.pump(_oneFrame);

      expect(TickerMode.valuesOf(probe).enabled, isTrue);
    });
  });
}
