/// Compares two dotted version strings.
///
/// Negative when [version1] is older, zero when they are equal, positive when
/// it is newer. Missing or non-numeric parts read as zero, so `1.2` and
/// `1.2.0` compare equal and a malformed segment never throws — a version
/// string the server got wrong must not lock anyone out of the app.
int compareVersions(String version1, String version2) {
  final v1Parts = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final v2Parts = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  while (v1Parts.length < v2Parts.length) {
    v1Parts.add(0);
  }
  while (v2Parts.length < v1Parts.length) {
    v2Parts.add(0);
  }

  for (var i = 0; i < v1Parts.length; i++) {
    if (v1Parts[i] < v2Parts[i]) return -1;
    if (v1Parts[i] > v2Parts[i]) return 1;
  }

  return 0;
}
