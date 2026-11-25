import 'package:begzar/modules/ads/domain/entities/advertisement.dart';

/// Whether the overlay is still waiting on a list or has an ad to paint.
enum PostConnectAdPhase { loading, ready }

/// What the post-connect overlay is showing. `null` state means no overlay.
class PostConnectAdState {
  const PostConnectAdState._({
    required this.phase,
    this.ad,
    this.enforceWait = false,
  });

  /// The shimmer shell, shown while the list is fetched. Nothing is on screen
  /// to read yet, so the wait is enforced from the start.
  const PostConnectAdState.loading()
    : this._(phase: PostConnectAdPhase.loading, enforceWait: true);

  factory PostConnectAdState.ready(
    Advertisement ad, {
    bool enforceWait = false,
  }) {
    return PostConnectAdState._(
      phase: PostConnectAdPhase.ready,
      ad: ad,
      enforceWait: enforceWait,
    );
  }

  final PostConnectAdPhase phase;
  final Advertisement? ad;
  final bool enforceWait;

  bool get isLoading => phase == PostConnectAdPhase.loading;
}
