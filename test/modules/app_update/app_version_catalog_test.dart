import 'package:begzar/modules/app_update/application/services/app_version_enforcement.dart';
import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:begzar/modules/app_update/data/app_version_catalog_cache.dart';
import 'package:begzar/modules/app_update/domain/app_version_gate.dart';
import 'package:begzar/modules/app_update/domain/entities/app_version_catalog.dart';
import 'package:begzar/modules/app_update/domain/version_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

const _github = 'https://github.com/Begzar/BegzarApp/releases/latest';

const _catalog = AppVersionCatalog(
  platforms: {
    'android': {
      'github': AppVersionSourceRelease(version: '6.8.0', url: _github),
      'google_play': AppVersionSourceRelease(
        version: '6.8.0',
        url:
            'https://play.google.com/store/apps/details?id=cloud.begzar.begzar',
      ),
    },
    'windows': {
      'github': AppVersionSourceRelease(version: '6.8.0', url: _github),
      'ms_store': AppVersionSourceRelease(version: '6.8.0'),
    },
    'ios': {
      'testflight': AppVersionSourceRelease(
        version: '6.8.0',
        url: 'https://testflight.apple.com/join/cRSCr51a',
      ),
      'app_store': AppVersionSourceRelease(
        version: '6.8.0',
        url: 'https://apps.apple.com/app/begzar/',
      ),
    },
    'macos': {
      'testflight': AppVersionSourceRelease(version: '6.8.0'),
      'app_store': AppVersionSourceRelease(version: '6.8.0'),
    },
  },
);

/// Channels that name a newer release beside their minimum: one with a page to
/// send the user to, one without, and one that names no newer release.
const _latestCatalog = AppVersionCatalog(
  platforms: {
    'android': {
      'github': AppVersionSourceRelease(
        version: '6.8.0',
        latestVersion: '7.0.0',
        url: _github,
      ),
      'google_play': AppVersionSourceRelease(
        version: '6.8.0',
        latestVersion: '7.0.0',
      ),
    },
    'windows': {
      'github': AppVersionSourceRelease(version: '6.8.0', url: _github),
    },
  },
);

void main() {
  const compare = compareVersions;

  group('AppVersionGate.evaluate', () {
    late AppVersionCatalog catalog;

    setUp(() {
      catalog = _catalog;
    });

    test('fails open when catalog is missing', () {
      final result = AppVersionGate.evaluate(
        catalog: null,
        platform: 'android',
        sourceKey: 'github',
        currentVersion: '1.0.0',
        compareVersions: compare,
      );
      expect(result.isUpdateRequired, isFalse);
    });

    test('fails open when this source is not listed', () {
      final result = AppVersionGate.evaluate(
        catalog: catalog,
        platform: 'macos',
        sourceKey: 'github',
        currentVersion: '1.0.0',
        compareVersions: compare,
      );
      expect(result.isUpdateRequired, isFalse);
    });

    test('allows when installed version matches or is newer', () {
      expect(
        AppVersionGate.evaluate(
          catalog: catalog,
          platform: 'android',
          sourceKey: 'github',
          currentVersion: '6.8.0',
          compareVersions: compare,
        ).isUpdateRequired,
        isFalse,
      );
      expect(
        AppVersionGate.evaluate(
          catalog: catalog,
          platform: 'android',
          sourceKey: 'github',
          currentVersion: '6.9.0',
          compareVersions: compare,
        ).isUpdateRequired,
        isFalse,
      );
    });

    test('requires update with the source url when installed is older', () {
      final result = AppVersionGate.evaluate(
        catalog: catalog,
        platform: 'android',
        sourceKey: 'google_play',
        currentVersion: '6.7.9',
        compareVersions: compare,
      );
      expect(result.isUpdateRequired, isTrue);
      expect(result.currentVersion, '6.7.9');
      expect(result.requiredVersion, '6.8.0');
      expect(
        result.updateUrl,
        'https://play.google.com/store/apps/details?id=cloud.begzar.begzar',
      );
    });

    test('requires update without url when the catalog omits it', () {
      final result = AppVersionGate.evaluate(
        catalog: catalog,
        platform: 'windows',
        sourceKey: 'ms_store',
        currentVersion: '6.0.0',
        compareVersions: compare,
      );
      expect(result.isUpdateRequired, isTrue);
      expect(result.updateUrl, isNull);
    });

    test(
      'should offer the latest version when the installed build is older',
      () {
        final result = AppVersionGate.evaluate(
          catalog: _latestCatalog,
          platform: 'android',
          sourceKey: 'github',
          currentVersion: '6.9.0',
          compareVersions: compare,
        );

        expect(result.isUpdateRequired, isFalse);
        expect(result.currentVersion, '6.9.0');
        expect(result.latestVersion, '7.0.0');
        expect(
          result.updateUrl,
          'https://github.com/Begzar/BegzarApp/releases/latest',
        );
      },
    );

    test('should offer nothing when the installed build is the latest', () {
      final latest = _latestCatalog;

      for (final installed in ['7.0.0', '7.0.1']) {
        final result = AppVersionGate.evaluate(
          catalog: latest,
          platform: 'android',
          sourceKey: 'github',
          currentVersion: installed,
          compareVersions: compare,
        );
        expect(result.isUpdateRequired, isFalse);
        expect(result.latestVersion, isNull, reason: installed);
      }
    });

    // The forced dialog already sends the user to the newest build, so a
    // build below the minimum is required to update and offered nothing.
    test('should require rather than offer below the minimum', () {
      final result = AppVersionGate.evaluate(
        catalog: _latestCatalog,
        platform: 'android',
        sourceKey: 'github',
        currentVersion: '6.7.0',
        compareVersions: compare,
      );

      expect(result.isUpdateRequired, isTrue);
      expect(result.latestVersion, isNull);
    });

    // An offer with nowhere to go is a row that does nothing when tapped.
    test('should offer nothing when the channel has no page to open', () {
      final result = AppVersionGate.evaluate(
        catalog: _latestCatalog,
        platform: 'android',
        sourceKey: 'google_play',
        currentVersion: '6.9.0',
        compareVersions: compare,
      );

      expect(result.isUpdateRequired, isFalse);
      expect(result.latestVersion, isNull);
    });
  });

  group('AppVersionEnforcement.target', () {
    tearDown(() {
      AppVersionCatalogCache.latest = null;
    });

    test('uses catalog entry for this install when present', () {
      AppVersionCatalogCache.latest = AppVersionCatalog(
        platforms: {
          AppDistribution.catalogPlatform: {
            AppDistribution.sourceKey: const AppVersionSourceRelease(
              version: '6.9.0',
              url: 'https://example.com/update',
            ),
          },
        },
      );

      final target = AppVersionEnforcement.target(
        fallbackVersion: '1.0.0',
        fallbackUrl: 'https://fallback.example',
      );
      expect(target?.version, '6.9.0');
      expect(target?.url, 'https://example.com/update');
    });

    test('does not block when catalog loaded but source is absent', () {
      AppVersionCatalogCache.latest = const AppVersionCatalog(
        platforms: {
          'other': {'github': AppVersionSourceRelease(version: '9.9.9')},
        },
      );
      expect(AppVersionEnforcement.target(fallbackVersion: '9.9.9'), isNull);
    });

    test('falls back to subscription metadata when catalog fetch failed', () {
      AppVersionCatalogCache.latest = null;
      final target = AppVersionEnforcement.target(
        fallbackVersion: '6.8.0',
        fallbackUrl: 'https://fallback.example',
      );
      expect(target?.version, '6.8.0');
      expect(target?.url, 'https://fallback.example');
    });
  });
}
