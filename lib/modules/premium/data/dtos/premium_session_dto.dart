import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';

/// Stored shape of a [PremiumSession].
///
/// This is the on-disk format, not the API's: it shares field names with the
/// login response by history rather than by contract, so it is written out
/// here separately and may drift.
abstract final class PremiumSessionDto {
  static Map<String, dynamic> toJson(PremiumSession session) => {
    accessKeyField: session.accessKey,
    usernameField: session.account.username,
    if (session.account.email != null) emailField: session.account.email,
    if (session.account.expireDate != null)
      expireDateField: session.account.expireDate,
    if (session.account.statusLabel != null)
      userStatusField: session.account.statusLabel,
  };

  /// Throws on a missing credential or username — a session that cannot
  /// identify itself is not a session, and the caller treats the throw as
  /// "nothing stored" rather than propagating it. A missing expiry is an
  /// account that has never paid, not a broken record.
  static PremiumSession fromJson(Map<String, dynamic> json) {
    return PremiumSession(
      accessKey: json[accessKeyField] as String,
      account: PremiumAccount(
        username: json[usernameField] as String,
        email: json[emailField] as String?,
        expireDate: json[expireDateField] as String?,
        statusLabel: AccountStatus.labelOf(json[userStatusField]),
      ),
    );
  }

  static const accessKeyField = 'access_key';
  static const usernameField = 'username';
  static const emailField = 'email';
  static const expireDateField = 'expire_date';
  static const userStatusField = 'user_status';

  /// Fields older builds wrote beside the session and nothing reads now.
  /// Their presence is what tells the storage to rewrite the record on the
  /// next read, so they leave the disk.
  static const legacyFields = <String>{'password', 'config_source'};
}
