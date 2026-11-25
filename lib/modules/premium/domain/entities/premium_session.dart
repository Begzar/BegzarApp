import 'package:begzar/modules/premium/domain/premium_account.dart';

/// A sign-in: the credential plus the account it belongs to.
///
/// This is what `login` returns and what storage persists — the two used to be
/// separate classes with identical fields, which meant every sign-in built one
/// and immediately copied it into the other.
///
/// The session deliberately carries no UI state. Which body the home screen
/// shows is a view preference that lives in memory, not next to the access
/// key — storing it here previously meant two copies that had to be kept in
/// sync by hand.
class PremiumSession {
  const PremiumSession({required this.accessKey, required this.account});

  /// The server-issued credential every premium call is signed with.
  final String accessKey;

  final PremiumAccount account;

  PremiumSession copyWith({String? accessKey, PremiumAccount? account}) {
    return PremiumSession(
      accessKey: accessKey ?? this.accessKey,
      account: account ?? this.account,
    );
  }
}
