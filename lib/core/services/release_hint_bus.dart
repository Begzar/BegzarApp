import 'package:begzar_engine/begzar_engine.dart' show BackendReleaseHint;

/// The newest release the backend has named for this platform.
class LatestRelease {
  const LatestRelease({this.version, this.updatedUrl});

  final String? version;
  final String? updatedUrl;
}

/// The newest release any backend answer named in this run.
///
/// Several operations carry one on the way past; the connect path reads the
/// latest to enforce the release the backend asks for. A field an answer
/// leaves out keeps the one before it.
class ReleaseHintBus {
  ReleaseHintBus._();

  static LatestRelease? latest;

  static void publish(BackendReleaseHint? hint) {
    if (hint == null) return;
    final version = hint.version;
    final updatedUrl = hint.updateUrl;
    if ((version == null || version.isEmpty) &&
        (updatedUrl == null || updatedUrl.isEmpty)) {
      return;
    }
    latest = LatestRelease(
      version: version ?? latest?.version,
      updatedUrl: updatedUrl ?? latest?.updatedUrl,
    );
  }
}
