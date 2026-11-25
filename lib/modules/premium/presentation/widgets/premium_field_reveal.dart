import 'dart:async';

import 'package:flutter/widgets.dart';

/// Tells the reveal when the screen's size changes, which is how the keyboard
/// opening reaches a widget.
class _MetricsListener with WidgetsBindingObserver {
  _MetricsListener(this._onChange);

  final VoidCallback _onChange;

  @override
  void didChangeMetrics() => _onChange();
}

/// Brings a focused field to the middle of what the keyboard leaves of the
/// screen, rather than to its bottom edge with the button below it hidden
/// under the keyboard.
///
/// Both halves of the sign-in card use it, so signing in and creating an
/// account move the same way when a field is tapped.
mixin PremiumFieldReveal<T extends StatefulWidget> on State<T> {
  /// How long the screen has to hold its size before the keyboard counts as
  /// open. It changes on every frame while the keyboard slides in.
  static const _keyboardSettle = Duration(milliseconds: 150);
  static const _fieldRevealDuration = Duration(milliseconds: 220);

  final List<FocusNode> _revealedFields = [];
  late final _metrics = _MetricsListener(_scheduleReveal);
  Timer? _pendingReveal;

  FocusNode? _focusedField() {
    for (final node in _revealedFields) {
      if (node.hasFocus) return node;
    }
    return null;
  }

  Future<void> _revealFocusedField() async {
    final focused = _focusedField();
    if (!mounted || focused == null) return;

    final fieldContext = focused.context;
    if (fieldContext == null || !fieldContext.mounted) return;

    await Scrollable.ensureVisible(
      fieldContext,
      alignment: 0.5,
      duration: _fieldRevealDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Reveals once the screen has stopped changing size, so the keyboard has
  /// finished opening and what is left of the screen can be measured. A field
  /// focused while the keyboard is already open causes no size change, and
  /// waits the same time for its own reveal.
  void _scheduleReveal() {
    if (_focusedField() == null) return;
    _pendingReveal?.cancel();
    _pendingReveal = Timer(_keyboardSettle, _revealFocusedField);
  }

  /// Reveals each of [fields] whenever it takes focus. The owner disposes
  /// the nodes, and the listeners go with them.
  void revealWhenFocused(List<FocusNode> fields) {
    if (_revealedFields.isEmpty) {
      WidgetsBinding.instance.addObserver(_metrics);
    }
    for (final field in fields) {
      field.addListener(_scheduleReveal);
      _revealedFields.add(field);
    }
  }

  @override
  void dispose() {
    _pendingReveal?.cancel();
    WidgetsBinding.instance.removeObserver(_metrics);
    super.dispose();
  }
}
