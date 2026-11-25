/// Sign-in input that has already been checked and normalized.
///
/// The type is the guarantee: a blank username or password cannot be built
/// into one, so nothing downstream has to re-check, and the trim happens once
/// here rather than again in the API client.
class PremiumCredentials {
  const PremiumCredentials._({required this.username, required this.password});

  /// Trimmed. The server matches on the exact string, and a trailing space
  /// picked up from a paste or a keyboard suggestion is not part of the name.
  final String username;

  /// Never trimmed — whitespace can be a deliberate part of a password.
  final String password;

  /// Null when either field is blank, which is the caller's cue to ask again
  /// rather than spend a request finding out.
  static PremiumCredentials? parse({
    required String username,
    required String password,
  }) {
    final trimmed = username.trim();
    if (trimmed.isEmpty || password.isEmpty) return null;
    return PremiumCredentials._(username: trimmed, password: password);
  }
}
