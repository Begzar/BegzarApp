import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';

/// Where the premium sign-in currently stands.
///
/// The variants exist so callers can tell apart states that a set of booleans
/// used to blur together — in particular restoring a stored session on launch
/// versus a user signing in by hand, which look identical once both have
/// produced an account.
sealed class PremiumState {
  const PremiumState();

  /// The account this state carries, or null when nobody is signed in.
  PremiumAccount? get account;

  String? get errorMessage;

  bool get isLoggedIn => account != null;

  /// Whether premium is usable right now. Every premium decision in the app
  /// routes through here so none of them can disagree.
  bool get isEntitled => account?.isEntitled ?? false;

  /// True while the subscription itself is unexpired, even if the server has
  /// disabled the account. Ad gating uses this: the user paid for the period.
  bool get hasActiveSubscription => account?.isSubscriptionActive ?? false;

  /// True while an operation the subscription card reflects is in flight.
  bool get isLoading => switch (this) {
    PremiumRestoring() => true,
    PremiumSignedOut(:final isAuthenticating) => isAuthenticating,
    PremiumSignedIn(:final isRefreshing) => isRefreshing,
    PremiumSigningOut() => false,
  };

  bool get isLoggingOut => this is PremiumSigningOut;

  String? get username => account?.username;
  String? get expireDate => account?.expireDate;
  String? get userStatus => account?.statusLabel;
}

/// Reading the stored session on launch; nothing is known yet.
final class PremiumRestoring extends PremiumState {
  const PremiumRestoring();

  @override
  PremiumAccount? get account => null;

  @override
  String? get errorMessage => null;
}

/// No usable session. [isAuthenticating] is true while a sign-in is in flight.
final class PremiumSignedOut extends PremiumState {
  const PremiumSignedOut({
    this.isAuthenticating = false,
    this.errorMessage,
    this.isRevoked = false,
  });

  /// The session the server ended by unregistering this device, rather than
  /// one the user signed out of.
  const PremiumSignedOut.revoked()
    : this(errorMessage: UserFacingErrorKeys.deviceRemoved, isRevoked: true);

  final bool isAuthenticating;

  /// True when the subscription was signed out because the server stopped
  /// registering this device, or because the account itself was deleted —
  /// not because anybody signed out.
  ///
  /// The two look the same on the premium screen and are not the same to the
  /// tunnel: a user signing out keeps the connection they are on, and a seat
  /// taken away is not theirs to keep using. The app shell reads this to tell
  /// them apart.
  final bool isRevoked;

  @override
  final String? errorMessage;

  @override
  PremiumAccount? get account => null;
}

final class PremiumSignedIn extends PremiumState {
  const PremiumSignedIn({
    required this.account,
    this.isRefreshing = false,
    this.errorMessage,
  });

  @override
  final PremiumAccount account;

  final bool isRefreshing;

  @override
  final String? errorMessage;

  PremiumSignedIn copyWith({
    PremiumAccount? account,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PremiumSignedIn(
      account: account ?? this.account,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Signing out; the account is kept so the card does not flash empty.
final class PremiumSigningOut extends PremiumState {
  const PremiumSigningOut(this.account);

  @override
  final PremiumAccount account;

  @override
  String? get errorMessage => null;
}
