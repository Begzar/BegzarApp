/// Once set, the app must not connect until the user installs a newer build.
///
/// Set from the splash gate when the version catalog reports the installed
/// build is below the minimum for this platform and distribution source, and
/// read by every path that could otherwise start a tunnel.
class ForceUpdateState {
  const ForceUpdateState({
    this.required = false,
    this.currentVersion = '',
    this.requiredVersion = '',
    this.updateUrl,
  });

  final bool required;
  final String currentVersion;
  final String requiredVersion;

  /// Where to send the user. Null falls back to the store listing for the
  /// platform, which is what the dialog does on its own.
  final String? updateUrl;

  ForceUpdateState copyWith({
    bool? required,
    String? currentVersion,
    String? requiredVersion,
    String? updateUrl,
  }) {
    return ForceUpdateState(
      required: required ?? this.required,
      currentVersion: currentVersion ?? this.currentVersion,
      requiredVersion: requiredVersion ?? this.requiredVersion,
      updateUrl: updateUrl ?? this.updateUrl,
    );
  }
}
