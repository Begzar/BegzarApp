import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/ads/presentation/controllers/ad_overlay_back_handler.dart';
import 'package:begzar/modules/ads/presentation/controllers/ad_skip_warning_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/connection_ad_gate_notifier.dart';
import 'package:begzar/modules/ads/presentation/controllers/post_connect_ad_notifier.dart';
import 'package:begzar/modules/ads/presentation/states/connection_ad_gate_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The overlays are painted above the router, where there is no `ModalRoute`
/// for a `PopScope` to register with, so a back press aimed at the ad used to
/// fall through to Android — which finishes the activity, taking the tunnel
/// with it. The press is answered here instead, and the screen that owns the
/// back button asks this before doing anything of its own.
///
/// What back means is what the control on screen means: while the wait runs the
/// close knob is locked, so back is too; once the knob opens, back is the knob.
const _waitSeconds = 3;

Advertisement _ad() {
  final now = DateTime.now();
  return Advertisement(
    id: 1,
    title: 'title',
    description: 'description',
    bannerUrl: 'https://example.invalid/banner.png',
    clickUrl: 'https://example.invalid/go',
    position: 'post_connect',
    priority: 1,
    startDate: now.subtract(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 1)),
    type: 'banner',
    action: 'action',
    buttonColor: '#7A3FD4',
    duration: _waitSeconds,
  );
}

/// The gate at a fixed point in its countdown, so a test can stand at either
/// side of the moment the knob opens without waiting out a real timer.
class _FixedGate extends ConnectionAdGateNotifier {
  _FixedGate({required this.canClose});

  final bool canClose;

  @override
  ConnectionAdGateState build() => ConnectionAdGateState(
    isActive: true,
    canClose: canClose,
    remainingSeconds: canClose ? 0 : _waitSeconds,
  );
}

ProviderContainer _container({bool? canClose}) {
  final container = ProviderContainer(
    overrides: [
      if (canClose != null)
        connectionAdGateProvider.overrideWith(
          () => _FixedGate(canClose: canClose),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

bool _pressBack(ProviderContainer container) =>
    container.read(adOverlayBackHandlerProvider).handleBack();

void main() {
  test('back is left alone when no overlay is up', () {
    final container = _container();

    expect(_pressBack(container), isFalse);
  });

  test('back is swallowed while the shimmer shell stands in', () {
    final container = _container(canClose: false);
    container.read(postConnectAdProvider.notifier).showLoadingAndWait();

    expect(_pressBack(container), isTrue);
    expect(
      container.read(postConnectAdProvider),
      isNotNull,
      reason: 'there is no ad to close yet, so there is nothing back can do',
    );
  });

  test('back is swallowed while the wait is still running', () {
    final container = _container(canClose: false);
    container
        .read(postConnectAdProvider.notifier)
        .showAndWait(_ad(), enforceWait: true);

    expect(_pressBack(container), isTrue);
    expect(
      container.read(postConnectAdProvider),
      isNotNull,
      reason: 'the close knob is locked, so back cannot open it either',
    );
  });

  test('back closes the ad once the wait is served', () {
    final container = _container(canClose: true);
    final dismissed = container
        .read(postConnectAdProvider.notifier)
        .showAndWait(_ad(), enforceWait: true);

    expect(_pressBack(container), isTrue);
    expect(container.read(postConnectAdProvider), isNull);
    expect(
      dismissed,
      completes,
      reason: 'back releases the connect path exactly as the knob does',
    );
  });

  test('back closes an ad that enforces no wait', () {
    final container = _container(canClose: false);
    container.read(postConnectAdProvider.notifier).showContent(_ad());

    expect(_pressBack(container), isTrue);
    expect(container.read(postConnectAdProvider), isNull);
  });

  test('back cancels the ad-skip warning', () {
    final container = _container();
    container.read(adSkipWarningVisibleProvider.notifier).show();

    expect(_pressBack(container), isTrue);
    expect(container.read(adSkipWarningVisibleProvider), isFalse);
  });

  test('the warning answers back before the ad under it does', () {
    final container = _container(canClose: true);
    container.read(postConnectAdProvider.notifier).showContent(_ad());
    container.read(adSkipWarningVisibleProvider.notifier).show();

    expect(_pressBack(container), isTrue);
    expect(container.read(adSkipWarningVisibleProvider), isFalse);
    expect(
      container.read(postConnectAdProvider),
      isNotNull,
      reason: 'the warning is drawn on top, so it is what back reaches',
    );
  });
}
