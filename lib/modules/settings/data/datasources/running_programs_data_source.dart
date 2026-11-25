import 'dart:io';

import 'package:flutter/services.dart';

/// The programs running on a desktop, as the paths of their executables.
///
/// Windows and Linux have no list of installed apps to pick from, and the
/// engine matches a connection to a program by its file name, so what is
/// running is the list the user chooses from. Android has the launcher
/// (`InstalledAppsDataSource`) and every other platform answers with nothing.
///
/// Windows asks the runner, which owns the Win32 calls; Linux reads `/proc`
/// itself. Either can throw — a platform with no handler raises
/// [MissingPluginException], and `/proc` can be missing — and
/// `SettingsRepository` is what turns a throw into an empty list.
class RunningProgramsDataSource {
  const RunningProgramsDataSource();

  static const _channel = MethodChannel('cloud.begzar.begzar/running_programs');
  static const _listMethod = 'list';
  static const _processesFolder = '/proc';
  static const _executableLink = 'exe';

  /// Every process the user is allowed to inspect. The kernel's own threads
  /// and other users' processes have no readable link and are left out.
  static List<String> _linuxExecutablePaths() {
    final paths = <String>[];
    for (final entry in Directory(_processesFolder).listSync()) {
      if (int.tryParse(entry.path.split('/').last) == null) continue;
      try {
        paths.add(Link('${entry.path}/$_executableLink').targetSync());
      } on FileSystemException {
        // The process ended since the folder was listed, or is not ours.
      }
    }
    return paths;
  }

  /// The executable path of each running process, one per process, so a program
  /// with several instances appears several times. Throws where the platform
  /// cannot answer; an empty list means nothing is running that the user may
  /// inspect, or that this platform has no list.
  Future<List<String>> fetchExecutablePaths() async {
    if (Platform.isWindows) {
      return await _channel.invokeListMethod<String>(_listMethod) ?? const [];
    }
    if (Platform.isLinux) return _linuxExecutablePaths();
    return const [];
  }
}
