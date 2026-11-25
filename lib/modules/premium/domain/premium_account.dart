/// Whether the server considers the account usable, ignoring the expiry date.
///
/// The API sends `user_status` as a bool, a number, or a free-form label
/// depending on the endpoint and the account's age, so every value that
/// reaches the app is normalized through [labelOf] before it is parsed here.
enum AccountStatus {
  active,
  inactive;

  bool get isActive => this == AccountStatus.active;

  static const _inactiveLabels = {
    'false',
    '0',
    'inactive',
    'disabled',
    'suspended',
    'banned',
    'expired',
  };

  /// Older accounts predate `user_status` and the server omits the field for
  /// them, so an absent status means active rather than unknown.
  static AccountStatus parse(String? label) {
    if (label == null || label.isEmpty) return AccountStatus.active;
    return _inactiveLabels.contains(label)
        ? AccountStatus.inactive
        : AccountStatus.active;
  }

  /// Normalizes a raw `user_status` from the API or from stored JSON into the
  /// single lower-case form the rest of the app compares against.
  ///
  /// Returns null when the field carries no status at all, which [parse]
  /// reads as active.
  static String? labelOf(Object? raw) {
    if (raw == null) return null;
    if (raw is bool) return raw ? 'true' : 'false';
    if (raw is num) return raw != 0 ? 'true' : 'false';

    final value = raw.toString().trim().toLowerCase();
    if (value.isEmpty) return null;
    if (value == 'true' || value == '1') return 'true';
    if (value == 'false' || value == '0') return 'false';
    return value;
  }
}

/// The subscription as the server last described it.
///
/// This is the app's only authority on whether premium is usable: the UI mode,
/// the connect button's routing and the pre-connect gate all ask
/// [isEntitled] rather than keeping a flag of their own.
class PremiumAccount {
  const PremiumAccount({
    required this.username,
    this.email,
    this.expireDate,
    this.statusLabel,
  });

  final String username;

  /// The account email when the server sends it (for example from user-data).
  final String? email;

  /// The raw server value, kept verbatim so the subscription card can format
  /// and localize it without the domain guessing at a display format.
  ///
  /// Null when the server has never recorded a payment: an account created in
  /// the app exists before anything has been bought for it.
  final String? expireDate;

  /// Normalized `user_status`, or null when the server sent none.
  final String? statusLabel;

  AccountStatus get status => AccountStatus.parse(statusLabel);

  /// True for an account that has never paid, which is a different thing to
  /// tell its owner from one whose subscription ran out.
  bool get neverSubscribed => expireDate == null;

  DateTime? get expiresAt {
    final raw = expireDate;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  bool get isSubscriptionActive {
    final expiry = expiresAt;
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  /// Premium is usable only when the server has not disabled the account and
  /// the subscription has not lapsed.
  bool get isEntitled => status.isActive && isSubscriptionActive;

  @override
  bool operator ==(Object other) =>
      other is PremiumAccount &&
      other.username == username &&
      other.email == email &&
      other.expireDate == expireDate &&
      other.statusLabel == statusLabel;

  @override
  int get hashCode => Object.hash(username, email, expireDate, statusLabel);
}
