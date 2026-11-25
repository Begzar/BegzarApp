import 'package:begzar/modules/app_update/data/app_distribution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDistributionSource.parse', () {
    test('accepts canonical catalog keys', () {
      expect(
        AppDistributionSource.parse('github'),
        AppDistributionSource.github,
      );
      expect(
        AppDistributionSource.parse('google_play'),
        AppDistributionSource.googlePlay,
      );
      expect(
        AppDistributionSource.parse('ms_store'),
        AppDistributionSource.msStore,
      );
      expect(
        AppDistributionSource.parse('testflight'),
        AppDistributionSource.testFlight,
      );
      expect(
        AppDistributionSource.parse('app_store'),
        AppDistributionSource.appStore,
      );
    });

    test('normalizes aliases and case', () {
      expect(AppDistributionSource.parse('GH'), AppDistributionSource.github);
      expect(
        AppDistributionSource.parse('Google-Play'),
        AppDistributionSource.googlePlay,
      );
      expect(
        AppDistributionSource.parse('play_store'),
        AppDistributionSource.googlePlay,
      );
      expect(
        AppDistributionSource.parse('msstore'),
        AppDistributionSource.msStore,
      );
      expect(
        AppDistributionSource.parse('test-flight'),
        AppDistributionSource.testFlight,
      );
      expect(
        AppDistributionSource.parse('AppStore'),
        AppDistributionSource.appStore,
      );
    });

    test('returns null for unknown values', () {
      expect(AppDistributionSource.parse(''), isNull);
      expect(AppDistributionSource.parse('fdroid'), isNull);
    });
  });

  test('default dart-define is github', () {
    expect(AppDistribution.source, AppDistributionSource.github);
    expect(AppDistribution.sourceKey, 'github');
  });
}
