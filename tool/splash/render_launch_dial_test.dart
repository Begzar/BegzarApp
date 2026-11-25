import 'dart:io';
import 'dart:ui' as ui;

import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/core/theme/app_theme.dart';
import 'package:begzar/core/theme/brand_assets.dart';
import 'package:begzar/modules/main/presentation/widgets/launch_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the launch window's mark from [LaunchDial], the widget the app's
/// launch cover draws and carries into the home dial, so the splash and what
/// takes over from it are one drawing.
///
/// Run from the repo root, after changing the dial or the palette:
///
///     flutter test tool/splash/render_launch_dial_test.dart
///
/// Android takes the dial centred on the Android 12 icon canvas, per density,
/// in drawable and drawable-night; iOS takes the dial alone, in the light and
/// dark launch images.

const _androidCanvas = AppLayout.launchIconCanvas;

/// iOS centres the mark as it is, so it needs no canvas round it.
const _appleCanvas = AppLayout.launchShownCircle;

/// Any phone's: [LaunchDial] does not scale with the screen.
const _designSize = Size(393, 852);

const _androidDensities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

const _res = 'android/app/src/main/res';
const _launchImages = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';

final _boundary = GlobalKey();

/// The launch dial, on a transparent square of [canvas] logical pixels.
Widget _dialOn(double canvas, ThemeData theme) {
  return ScreenUtilInit(
    designSize: _designSize,
    builder: (context, _) => MaterialApp(
      // A fresh app per theme: one app handed a new theme cross-fades into
      // it, and the render would catch it halfway.
      key: ValueKey(theme.brightness),
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: ColoredBox(
          color: Colors.transparent,
          child: Center(
            child: RepaintBoundary(
              key: _boundary,
              child: SizedBox.square(
                dimension: canvas,
                child: const Center(child: LaunchDial()),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _write(WidgetTester tester, double pixelRatio, String path) async {
  final boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
  // ignore: avoid_print
  print('  wrote $path');
}

Future<void> _pumpDial(
  WidgetTester tester,
  double canvas,
  ThemeData theme,
) async {
  tester.view
    ..physicalSize = Size.square(canvas)
    ..devicePixelRatio = 1;
  await tester.pumpWidget(_dialOn(canvas, theme));
  final context = tester.element(find.byType(LaunchDial));
  await tester.runAsync(() async {
    await precacheImage(const AssetImage(BrandAssets.bird), context);
    await precacheImage(const AssetImage(BrandAssets.birdAccent), context);
  });
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('render the launch dial', (tester) async {
    addTearDown(tester.view.reset);
    final themes = {
      false: AppTheme.light(fontFamily: 'Roboto'),
      true: AppTheme.dark(fontFamily: 'Roboto'),
    };

    for (final MapEntry(key: night, value: theme) in themes.entries) {
      await _pumpDial(tester, _androidCanvas, theme);
      for (final MapEntry(key: density, value: ratio)
          in _androidDensities.entries) {
        final qualifier = night ? '-night' : '';
        await _write(
          tester,
          ratio,
          '$_res/drawable$qualifier-$density/splash_bird.png',
        );
      }

      await _pumpDial(tester, _appleCanvas, theme);
      for (final scale in [1, 2, 3]) {
        final suffix = night ? '-dark' : '';
        final name = scale == 1 ? '' : '@${scale}x';
        await _write(
          tester,
          scale.toDouble(),
          '$_launchImages/LaunchImage$suffix$name.png',
        );
      }
    }
  });
}
