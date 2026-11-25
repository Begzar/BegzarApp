import 'dart:async';
import 'dart:io';

import 'package:begzar/modules/settings/data/datasources/installed_apps_data_source.dart';
import 'package:begzar/modules/settings/data/datasources/launch_appearance_channel.dart';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';

/// Windows and Linux read the running programs instead of the launcher, which
/// is not something a test can reach from another host.
final readsRunningPrograms = Platform.isWindows || Platform.isLinux;

const desktopSkipReason = 'Windows and Linux list running programs instead.';

/// A launcher that reports exactly the packages it was given, each labelled
/// with its own package name.
class FakeInstalledApps extends InstalledAppsDataSource {
  const FakeInstalledApps(this._packages);

  final List<String> _packages;

  @override
  Future<List<AppInfo>> fetchLaunchable() async {
    return [
      for (final package in _packages)
        AppInfo.create({'name': package, 'package_name': package}),
    ];
  }
}

/// A launch window that keeps every theme it is handed, for a test to read
/// back, and touches no platform.
class RecordingLaunchAppearance extends LaunchAppearanceChannel {
  RecordingLaunchAppearance();

  final followed = <ThemeMode>[];

  @override
  Future<void> follow(ThemeMode mode) async => followed.add(mode);
}

/// A launcher that has not answered yet, so a screen asking it stays in its
/// loading state for as long as the test needs, until [answer] is called.
class PendingInstalledApps extends InstalledAppsDataSource {
  PendingInstalledApps();

  final _answer = Completer<List<AppInfo>>();

  /// Answers with [packages], each labelled with its own package name.
  void answer(List<String> packages) =>
      _answer.complete(FakeInstalledApps(packages).fetchLaunchable());

  @override
  Future<List<AppInfo>> fetchLaunchable() => _answer.future;
}
