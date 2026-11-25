import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_dial.dart';
import 'package:begzar/modules/main/presentation/widgets/launch_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _window = Size(400, 800);
const _dialSide = 180.0;
const _dialKey = Key('home dial');

ProviderContainer _container(LaunchCoverPhase initial) {
  final container = ProviderContainer(
    overrides: [
      launchCoverProvider.overrideWith(
        () => LaunchCoverNotifier(initial: initial),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Whether the slot last told the home dial it was covered.
bool? _lastCovered;

Future<void> _pumpSlot(WidgetTester tester, ProviderContainer container) async {
  tester.view
    ..physicalSize = _window
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Align(
          alignment: const Alignment(0, -0.4),
          child: LaunchDialSlot(
            builder: (context, covered) {
              _lastCovered = covered;
              return const SizedBox.square(key: _dialKey, dimension: _dialSide);
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// How solid the home dial is drawn.
double _shown(WidgetTester tester) {
  final opacity = find.ancestor(
    of: find.byKey(_dialKey),
    matching: find.byType(Opacity),
  );
  if (opacity.evaluate().isEmpty) return 1;
  return tester.widget<Opacity>(opacity.first).opacity;
}

void main() {
  group('LaunchDial', () {
    Future<Rect> clipAt(WidgetTester tester, double opening) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: _window,
          builder: (context, _) => MaterialApp(
            home: Center(child: LaunchDial(opening: opening)),
          ),
        ),
      );
      final clip = tester.renderObject<RenderClipOval>(
        find.descendant(
          of: find.byType(LaunchDial),
          matching: find.byType(ClipOval),
        ),
      );
      return clip.clipper!.getClip(clip.size);
    }

    // The cover scales it by the home dial's size over this one, so a disc
    // drawn any other size lands the wrong size and snaps when home takes over.
    testWidgets('should draw the disc at the launch size', (tester) async {
      await clipAt(tester, 0);

      final disc = tester.getRect(
        find.descendant(
          of: find.byType(LaunchDial),
          matching: find.byType(AppGlassPanel),
        ),
      );
      expect(disc.width, closeTo(AppLayout.launchDialSize, 0.01));
    });

    testWidgets('should cut the dial to the circle Android 12 shows', (
      tester,
    ) async {
      final clip = await clipAt(tester, 0);

      expect(clip.width, AppLayout.launchShownCircle);
    });

    // Opened all the way, nothing of the dial's shadow is cut off, so the
    // cover's dial and the home dial under it are the same picture.
    testWidgets('should open to the whole icon canvas', (tester) async {
      final clip = await clipAt(tester, 1);

      expect(clip.width, AppLayout.launchIconCanvas);
    });

    testWidgets('should draw no invite rings of its own', (tester) async {
      await clipAt(tester, 1);

      final dial = tester.widget<ConnectionDial>(find.byType(ConnectionDial));
      expect(dial.invite, isFalse);
    });
  });

  group('LaunchDialSlot', () {
    testWidgets('should report where the home dial is laid out', (
      tester,
    ) async {
      final container = _container(LaunchCoverPhase.covering);
      await _pumpSlot(tester, container);

      final state = container.read(launchCoverProvider);
      expect(state.phase, LaunchCoverPhase.landing);
      expect(state.target, tester.getRect(find.byKey(_dialKey)));
    });

    // The cover draws the dial while it flies; two at once would show the
    // home one sitting in place under the one still on its way.
    testWidgets('should hide the home dial until the cover is done', (
      tester,
    ) async {
      final container = _container(LaunchCoverPhase.covering);
      await _pumpSlot(tester, container);
      expect(_shown(tester), 0);

      container.read(launchCoverProvider.notifier).finish();
      await tester.pump();

      expect(_shown(tester), 1);
    });

    // The cover's dial arrives without the invite rings, so the home dial
    // takes over without them and brings them in once it is showing.
    testWidgets(
      'should tell the home dial it is covered until the cover ends',
      (tester) async {
        final container = _container(LaunchCoverPhase.covering);
        await _pumpSlot(tester, container);
        expect(_lastCovered, isTrue);

        container.read(launchCoverProvider.notifier).finish();
        await tester.pump();

        expect(_lastCovered, isFalse);
      },
    );

    testWidgets('should show the home dial when no cover is up', (
      tester,
    ) async {
      final container = _container(LaunchCoverPhase.done);
      await _pumpSlot(tester, container);

      expect(_shown(tester), 1);
      expect(container.read(launchCoverProvider).phase, LaunchCoverPhase.done);
    });
  });
}
