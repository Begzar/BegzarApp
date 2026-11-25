import 'dart:async';

import 'package:begzar/modules/ads/presentation/controllers/ad_skip_warning_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the ad-skip warning overlay after resume when the navigator is idle.
class AdSkipWarningPresenter extends ConsumerStatefulWidget {
  const AdSkipWarningPresenter({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdSkipWarningPresenter> createState() =>
      _AdSkipWarningPresenterState();
}

class _AdSkipWarningPresenterState
    extends ConsumerState<AdSkipWarningPresenter> {
  ProviderSubscription<bool>? _showRequestSubscription;
  bool _isPresenting = false;

  @override
  void initState() {
    super.initState();
    _showRequestSubscription = ref.listenManual(
      adSkipWarningShowRequestProvider,
      (previous, next) {
        if (next && !_isPresenting) {
          unawaited(_presentWhenReady());
        }
      },
    );
  }

  @override
  void dispose() {
    _showRequestSubscription?.close();
    super.dispose();
  }

  Future<void> _presentWhenReady() async {
    if (_isPresenting || !mounted) return;
    _isPresenting = true;

    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      for (var frame = 0; frame < 2; frame++) {
        final completer = Completer<void>();
        SchedulerBinding.instance.scheduleFrameCallback((_) {
          if (!completer.isCompleted) completer.complete();
        });
        await completer.future;
        if (!mounted) return;
      }

      if (!ref.read(adSkipWarningShowRequestProvider)) return;

      ref.read(adSkipWarningShowRequestProvider.notifier).clear();
      ref.read(adSkipWarningVisibleProvider.notifier).show();
    } finally {
      _isPresenting = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
