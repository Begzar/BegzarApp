import 'package:begzar/modules/settings/domain/entities/installed_app.dart';
import 'package:installed_apps/app_info.dart';

/// Maps what the platform reports onto [InstalledApp]: the launcher entries on
/// Android, the running programs' executable paths on Windows and Linux.
///
/// Entries with a blank label are dropped rather than shown: the row would
/// carry nothing the user can recognise, and the package name alone is not
/// something they chose to install by.
abstract final class InstalledAppDto {
  static const _windowsSeparator = r'\';
  static const _separator = '/';

  static List<InstalledApp> fromPlatform(List<AppInfo> apps) {
    return apps
        .where((app) => app.name.trim().isNotEmpty)
        .map(
          (app) => InstalledApp(
            packageName: app.packageName,
            name: app.name,
            icon: app.icon,
          ),
        )
        .toList();
  }

  /// Backslashes read as folder separators, so one comparison covers both
  /// kinds of path.
  static String _normalize(String path) {
    return path.replaceAll(_windowsSeparator, _separator);
  }

  static String _fileName(String path) {
    return _normalize(path).split(_separator).last;
  }

  static String _comparable(String text, {required bool ignoreCase}) {
    final normalized = _normalize(text);
    return ignoreCase ? normalized.toLowerCase() : normalized;
  }

  /// The folder with a trailing separator, so that a sibling whose name only
  /// starts like it, such as `WindowsApps` beside `Windows`, is not mistaken
  /// for something under it.
  static String _folderPrefix(String folder, {required bool ignoreCase}) {
    final comparable = _comparable(folder, ignoreCase: ignoreCase);
    return comparable.endsWith(_separator)
        ? comparable
        : '$comparable$_separator';
  }

  /// One entry per program file name, since the engine matches a connection
  /// by that name and not by where the program sits.
  ///
  /// Every program with the file name of [selfPath] is left out, wherever it
  /// sits, so the user cannot pick Begzar itself or a second copy of it: the
  /// engine matches by file name, so a copy shares Begzar's own exemption.
  /// Everything under [systemFolder] is left out too, since it holds the
  /// services the operating system needs to keep reaching the network.
  ///
  /// [ignoreCase] is set where the engine matches without regard to case,
  /// which is Windows; Linux compares names as they are written.
  /// [systemFolder] is given on Windows only.
  static List<InstalledApp> fromExecutablePaths(
    List<String> paths, {
    required String selfPath,
    bool ignoreCase = false,
    String? systemFolder,
  }) {
    final selfFileName = _comparable(
      _fileName(selfPath),
      ignoreCase: ignoreCase,
    );
    final systemPrefix = systemFolder == null
        ? null
        : _folderPrefix(systemFolder, ignoreCase: ignoreCase);

    final byFileName = <String, InstalledApp>{};
    for (final path in paths) {
      final fileName = _fileName(path);
      if (fileName.isEmpty) continue;
      if (_comparable(fileName, ignoreCase: ignoreCase) == selfFileName) {
        continue;
      }
      final comparable = _comparable(path, ignoreCase: ignoreCase);
      if (systemPrefix != null && comparable.startsWith(systemPrefix)) continue;
      byFileName.putIfAbsent(
        fileName,
        () => InstalledApp(
          packageName: fileName,
          name: InstalledApp.labelFromId(fileName),
        ),
      );
    }
    return byFileName.values.toList()..sort(InstalledApp.byName);
  }
}
