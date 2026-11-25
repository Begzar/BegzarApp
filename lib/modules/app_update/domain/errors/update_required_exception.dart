/// Thrown when the installed build is older than the minimum the server will
/// serve, to abort whatever was in flight.
///
/// Deliberately not a `Failure`. A failure is data that rides on the left of an
/// `Either` and ends up as a message; this is control flow. Nothing about it is
/// reportable — every path that catches one routes to the forced-update dialog,
/// which blocks the app until the user updates. There is nothing for the caller
/// to decide and nothing to translate, so it stays a throw.
class UpdateRequiredException implements Exception {
  UpdateRequiredException({
    required this.currentVersion,
    required this.requiredVersion,
    this.updateUrl,
  });

  final String currentVersion;
  final String requiredVersion;

  /// Where to send the user. Null falls back to the store listing for the
  /// platform, which is what the dialog does on its own.
  final String? updateUrl;

  @override
  String toString() =>
      'App update required. Current: $currentVersion, '
      'Required: $requiredVersion';
}
