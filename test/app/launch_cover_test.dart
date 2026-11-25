import 'package:begzar/app/launch_cover.dart';
import 'package:begzar/core/providers/launch_cover_provider.dart';
import 'package:begzar/modules/main/presentation/widgets/launch_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// The screen the cover is laid over, sized like a phone.
const _window = Size(400, 800);

/// Where a home dial might be laid out: well above the window's centre.
const _dialPlace = Rect.fromLTWH(110, 150, 180, 180);

/// An animation's clock starts on the frame after it is asked to run, so
/// reaching its end takes its duration and one frame more.
const _oneFrame = Duration(milliseconds: 16);

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

Future<void> _pumpCover(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view
    ..physicalSize = _window
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: _window,
        builder: (context, _) => MaterialApp(
          builder: (context, child) =>
              LaunchCover(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Text('home')),
        ),
      ),
    ),
  );
}

Offset _dialCentre(WidgetTester tester) =>
    tester.getCenter(find.byType(LaunchDial));

/// How solid the part of the cover under [key] is drawn.
double _opacity(WidgetTester tester, Key key) =>
    tester.widget<Opacity>(find.byKey(key)).opacity;

void main() {
  group('LaunchCover', () {
    testWidgets('should cover the app with the launch dial while covering', (
      tester,
    ) async {
      await _pumpCover(tester, _container(LaunchCoverPhase.covering));

      expect(find.byType(LaunchDial), findsOneWidget);
      expect(_dialCentre(tester), _window.center(Offset.zero));
    });

    testWidgets('should leave the app uncovered when nothing asked for it', (
      tester,
    ) async {
      await _pumpCover(tester, _container(LaunchCoverPhase.done));

      expect(find.byType(LaunchDial), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('should carry the dial to where the home dial landed', (
      tester,
    ) async {
      final container = _container(LaunchCoverPhase.covering);
      await _pumpCover(tester, container);

      container.read(launchCoverProvider.notifier).land(_dialPlace);
      await tester.pump();
      await tester.pump(LaunchCover.flight * 0.6);

      final midway = _dialCentre(tester);
      expect(midway.dy, lessThan(_window.height / 2));
      expect(midway.dy, greaterThan(_dialPlace.center.dy));
    });

    // The status line sits just under the home dial's place; while the dial
    // is still on its way down there, home stays under the page.
    testWidgets('should keep home covered until the dial has nearly landed', (
      tester,
    ) async {
      final container = _container(LaunchCoverPhase.covering);
      await _pumpCover(tester, container);

      container.read(launchCoverProvider.notifier).land(_dialPlace);
      await tester.pump();
      await tester.pump(LaunchCover.flight * 0.5);
      expect(_opacity(tester, LaunchCover.pageKey), 1);

      await tester.pump(LaunchCover.flight * 0.45);
      expect(_opacity(tester, LaunchCover.pageKey), lessThan(0.5));
    });

    // Cut to Android 12's circle where the launch window had it, and open by
    // the time it reaches the home dial, so the two are the same picture there
    // shadow and all, and one can take over from the other in a frame.
    testWidgets('should open the dial out of its launch circle on the way', (
      tester,
    ) async {
      final container = _container(LaunchCoverPhase.covering);
      await _pumpCover(tester, container);
      double opening() =>
          tester.widget<LaunchDial>(find.byType(LaunchDial)).opening;
      expect(opening(), 0);

      container.read(launchCoverProvider.notifier).land(_dialPlace);
      await tester.pump();
      await tester.pump(LaunchCover.flight * 0.95);

      expect(opening(), greaterThan(0.95));
    });

    testWidgets('should end the cover once the dial has landed', (
      tester,
    ) async {
      final container = _container(LaunchCoverPhase.covering);
      await _pumpCover(tester, container);

      container.read(launchCoverProvider.notifier).land(_dialPlace);
      await tester.pump();
      await tester.pump(LaunchCover.flight);
      await tester.pump(_oneFrame);

      expect(container.read(launchCoverProvider).phase, LaunchCoverPhase.done);
      expect(find.byType(LaunchDial), findsNothing);
    });

    testWidgets('should fade out where it is when dismissed', (tester) async {
      final container = _container(LaunchCoverPhase.covering);
      await _pumpCover(tester, container);

      container.read(launchCoverProvider.notifier).dismiss();
      await tester.pump();
      await tester.pump(LaunchCover.leave * 0.5);
      expect(_dialCentre(tester), _window.center(Offset.zero));

      await tester.pump(LaunchCover.leave);
      await tester.pump(_oneFrame);
      expect(container.read(launchCoverProvider).phase, LaunchCoverPhase.done);
    });

    testWidgets('should fade out where the dial had got to when interrupted', (
      tester,
    ) async {
      final container = _container(LaunchCoverPhase.covering);
      await _pumpCover(tester, container);
      final notifier = container.read(launchCoverProvider.notifier);
      notifier.land(_dialPlace);
      await tester.pump();
      await tester.pump(LaunchCover.flight * 0.5);
      final interrupted = _dialCentre(tester);

      notifier.dismiss();
      await tester.pump();
      await tester.pump(LaunchCover.leave * 0.5);

      expect(_dialCentre(tester), interrupted);
    });

    // A cover nobody answers must never trap the reader behind it.
    testWidgets('should give up covering when nothing answers in time', (
      tester,
    ) async {
      final container = _container(LaunchCoverPhase.covering);
      await _pumpCover(tester, container);

      await tester.pump(LaunchCover.giveUpAfter);
      await tester.pump(LaunchCover.leave);
      await tester.pump(_oneFrame);

      expect(container.read(launchCoverProvider).phase, LaunchCoverPhase.done);
    });
  });
}
