/// A newer release the user may install.
///
/// Set from the startup version check when the installed build is allowed but
/// older than the channel's latest release, and held until the process ends:
/// the dot on the settings tab and the update row stay for as long as it is
/// here, so the only way to clear them is to update.
class AvailableUpdateState {
  const AvailableUpdateState({required this.version, required this.url});

  final String version;

  /// The store listing or release page for this install channel.
  final String url;
}
