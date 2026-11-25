import 'dart:async';

import 'package:begzar/modules/ads/domain/entities/advertisement.dart';
import 'package:begzar/modules/ads/presentation/states/post_connect_ad_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the post-connect overlay and the future the connect flow waits on.
class PostConnectAdNotifier extends Notifier<PostConnectAdState?> {
  Completer<void>? _dismissCompleter;

  @override
  PostConnectAdState? build() => null;

  /// Shows the empty shimmer shell and returns a future that completes on dismiss.
  Future<void> showLoadingAndWait() {
    _dismissCompleter?.complete();
    _dismissCompleter = Completer<void>();
    state = const PostConnectAdState.loading();
    return _dismissCompleter!.future;
  }

  /// Replaces shimmer with ad content (keeps the same wait completer).
  void showContent(Advertisement ad, {bool enforceWait = false}) {
    if (state == null) {
      _dismissCompleter ??= Completer<void>();
    }
    state = PostConnectAdState.ready(ad, enforceWait: enforceWait);
  }

  Future<void> showAndWait(Advertisement ad, {bool enforceWait = false}) {
    _dismissCompleter?.complete();
    _dismissCompleter = Completer<void>();
    state = PostConnectAdState.ready(ad, enforceWait: enforceWait);
    return _dismissCompleter!.future;
  }

  void dismiss() {
    if (state == null) return;
    state = null;
    if (_dismissCompleter != null && !_dismissCompleter!.isCompleted) {
      _dismissCompleter!.complete();
    }
    _dismissCompleter = null;
  }
}

final postConnectAdProvider =
    NotifierProvider<PostConnectAdNotifier, PostConnectAdState?>(
      PostConnectAdNotifier.new,
    );
