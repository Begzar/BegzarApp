/// How the running build is named on screen: its version and build number,
/// joined as the release files name them (`8.0.0+35`).
///
/// [buildNumber] is the platform's own. A per-ABI Android build reports 1000
/// times its ABI's number on top of the build (arm64-v8a's 35 arrives as
/// 2035), so the remainder is what the release named. A missing or
/// non-numeric build leaves the version alone.
String installedBuildLabel(String version, String buildNumber) {
  final build = int.tryParse(buildNumber);
  if (build == null) return version;
  return '$version+${build % _abiVersionCodeStep}';
}

/// What Flutter multiplies an ABI's number by when it stamps a per-ABI
/// Android build's version code.
const _abiVersionCodeStep = 1000;
