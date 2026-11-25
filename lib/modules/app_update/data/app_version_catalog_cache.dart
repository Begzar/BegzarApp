import 'package:begzar/modules/app_update/domain/entities/app_version_catalog.dart';

/// Last catalog the splash fetch managed to read, for the rest of the process.
///
/// `null` means the request failed, and connect-time falls back to the version
/// the subscription metadata carries. Written once by the repository on the
/// way through the splash gate; read at every connect after that.
abstract final class AppVersionCatalogCache {
  static AppVersionCatalog? latest;
}
