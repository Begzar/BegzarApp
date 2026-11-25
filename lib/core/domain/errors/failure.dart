/// What every failure in the app has in common.
///
/// A failure is data, not an exception: it rides on the left of an `Either`
/// and is read, never caught. Modules seal their own families of them —
/// `ApiFailure` for anything that talks to the Begzar API, `ConnectionFailure`
/// for anything that dials a tunnel, `IpInfoFailure` for reading the exit
/// address — and this is the one type the layers above hold. Presentation asks
/// a failure for its [userFacingKey] without needing to know which family
/// answered.
///
/// A family describes what went wrong, never what is merely absent. Something
/// the app has no reason to know yet is not a failure and does not get a
/// variant here; it is `null`, or whatever empty looks like in that domain.
///
/// Deliberately not one app-wide `sealed` type: Dart requires every variant of
/// a sealed class to sit in the same library, so a single sealed [Failure]
/// would drag every module's vocabulary — VPN permissions, proxy tests, device
/// registration — back into `core/`, which is the floor and may not know a
/// module exists. Nothing switches over all failures anyway; every call site
/// wants the key.
abstract interface class Failure {
  /// Developer-facing detail, for logs and tests.
  ///
  /// Never rendered: it can carry raw server text, and a URL or an address in
  /// an error toast is an information leak. [userFacingKey] is what the UI
  /// reads.
  String get message;

  /// Stable l10n key describing this failure (see `UserFacingErrorKeys`).
  String get userFacingKey;
}
