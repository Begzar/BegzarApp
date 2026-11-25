import 'package:begzar/modules/premium/domain/premium_account.dart';

/// What the server said when the app re-checked entitlement immediately
/// before a premium connect.
///
/// The check runs against the server every time rather than trusting stored
/// state, so a subscription that lapsed or an account that was disabled since
/// the last refresh still stops the connect.
enum PremiumConnectValidation {
  /// Entitled: go ahead.
  allowed,

  /// Nothing to check — this connect is not using premium.
  skipped,

  /// No usable session, so there is nothing to check with.
  notLoggedIn,

  /// The server has disabled the account, whatever its expiry says.
  accountInactive,

  /// The account has never paid, so there is nothing to renew.
  notSubscribed,

  /// The subscription has lapsed.
  subscriptionExpired,

  /// The check itself did not complete. Deliberately not the same as
  /// [allowed]: an unreachable server never grants entitlement.
  checkFailed;

  /// The verdict for an account the server has just described.
  ///
  /// Order matters: a disabled account reports [accountInactive] even when its
  /// subscription still has time on it, because that is the reason the user
  /// needs to hear.
  static PremiumConnectValidation forAccount(PremiumAccount account) {
    if (!account.status.isActive) return accountInactive;
    if (account.neverSubscribed) return notSubscribed;
    if (!account.isSubscriptionActive) return subscriptionExpired;
    return allowed;
  }
}
