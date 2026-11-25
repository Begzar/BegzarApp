import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:begzar/core/providers/analytics_provider.dart';
import 'package:begzar/l10n/app_localizations.dart';
import 'package:begzar/l10n/locale_provider.dart';
import 'package:begzar/modules/app_update/data/datasources/installed_build.dart';
import 'package:begzar/modules/connection/data/datasources/engine_log_data_source.dart';
import 'package:begzar/modules/connection/data/datasources/engine_log_exporter.dart';
import 'package:begzar/modules/connection/data/datasources/proxy_core_adapter.dart';
import 'package:begzar/modules/connection/data/datasources/tunnel_helper.dart';
import 'package:begzar/modules/connection/data/repositories/connection_repository.dart';
import 'package:begzar/modules/connection/data/repositories/engine_log_repository.dart';
import 'package:begzar/modules/connection/application/services/connection_service.dart';
import 'package:begzar/modules/connection/domain/tunnel_options.dart';
import 'package:begzar/modules/settings/presentation/controllers/app_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/custom_routing_notifier.dart';
import 'package:begzar/modules/settings/presentation/controllers/settings_notifier.dart';

// ============================================================================
// Infrastructure Layer
// ============================================================================

/// Proxy core adapter provider.
///
/// Watches the locale rather than reading it: the tunnel notification is
/// written in the language in force when the tunnel started, so a language
/// change has to reach the adapter before the next connect.
final proxyCoreAdapterProvider = Provider<ProxyCoreAdapter>((ref) {
  return ProxyCoreAdapter(
    l10n: lookupAppLocalizations(ref.watch(localeProvider)),
  );
});

/// The Windows tunnel helper, and null on every other platform.
///
/// A provider of its own, watching nothing, so there is one for the app's
/// whole run. The repository is rebuilt whenever the adapter is, on every
/// language change, and the helper holds the lease of a tunnel that may be
/// up: a repository that built its own would lose that lease with the old
/// one, and its disconnect would leave the old helper's adapter in place.
final tunnelHelperProvider = Provider<TunnelHelper?>((ref) {
  return Platform.isWindows ? TunnelHelper() : null;
});

/// Connection repository provider
final connectionRepositoryProvider = Provider<ConnectionRepository>((ref) {
  return ConnectionRepository(
    ref.watch(proxyCoreAdapterProvider),
    tunnelHelper: ref.watch(tunnelHelperProvider),
  );
});

/// The engine log the hidden log viewer reads.
///
/// One for the app's whole run, so the viewer's cursor is not lost between
/// one opening and the next; the viewer reads from the start when it opens.
final engineLogRepositoryProvider = Provider<EngineLogRepository>((ref) {
  return EngineLogRepository(
    EngineLogDataSource(),
    const EngineLogExporter(),
    appVersion: InstalledBuild.instance.label,
  );
});

// ============================================================================
// Application Layer
// ============================================================================

/// Gathers the settings a tunnel needs, from the three modules that own them.
///
/// This is the seam the repository used to reach across on its own. It is read
/// rather than watched, and read fresh on each connect, so an attempt always
/// uses the settings in force when it started.
TunnelOptions _readTunnelOptions(Ref ref) {
  final settings = ref.read(settingsProvider);
  return TunnelOptions(
    dnsServer: settings.dnsServer,
    proxyOnly: settings.exposure.proxyOnly,
    systemProxy: settings.exposure.systemProxy,
    listenAddress: settings.exposure.listenAddress,
    customRouting: ref.read(customRoutingProvider),
    appRouting: ref
        .read(appRoutingProvider)
        .routingWhen(enabled: settings.appExclude),
  );
}

/// Connection service provider
final connectionServiceProvider = Provider<ConnectionService>((ref) {
  return ConnectionService(
    ref.watch(connectionRepositoryProvider),
    readOptions: () => _readTunnelOptions(ref),
    analytics: ref.watch(analyticsServiceProvider),
  );
});
