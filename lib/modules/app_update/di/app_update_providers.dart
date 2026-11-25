import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/data/datasources/installed_build.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The build that is running, version and build number, for the settings
/// version row.
final installedVersionProvider = FutureProvider<String>(
  (ref) => InstalledBuild.instance.label(),
);

/// The store this build was made for.
///
/// A provider over the compile-time constant, so a screen that differs on a
/// Play build reads it through the container and a test can stand in for a
/// Play build without being compiled as one.
final appDistributionSourceProvider = Provider<AppDistributionSource>(
  (ref) => AppDistribution.source,
);
