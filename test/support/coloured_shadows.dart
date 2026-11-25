import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every shadow drawn under [root] in a colour rather than in black.
///
/// A black shadow at an alpha is depth: a panel or a dialog lifted off the
/// page. A shadow in any other colour is a glow, which this app does not
/// draw round anything but the dial.
List<BoxShadow> colouredShadowsUnder(WidgetTester tester, Finder root) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: root, matching: find.byType(DecoratedBox)),
  ))
    if (box.decoration case BoxDecoration(:final boxShadow?))
      for (final shadow in boxShadow)
        if (shadow.color.r > 0 || shadow.color.g > 0 || shadow.color.b > 0)
          shadow,
];
