import 'package:begzar/modules/settings/domain/entities/installed_app.dart';
import 'package:flutter_test/flutter_test.dart';

InstalledApp _app(String name, String packageName) =>
    InstalledApp(name: name, packageName: packageName);

void main() {
  group('matches', () {
    test('an empty query matches everything', () {
      final app = _app('Maps', 'com.example.maps');

      expect(app.matches(''), isTrue);
      expect(app.matches('   '), isTrue);
    });

    test('matches the label regardless of case', () {
      final app = _app('Maps', 'com.example.maps');

      expect(app.matches('map'), isTrue);
      expect(app.matches('MAP'), isTrue);
      expect(app.matches('  maps '), isTrue);
    });

    // Two apps can carry the same label; the package is what tells them
    // apart, so it is searched too.
    test('matches the package name', () {
      final app = _app('Maps', 'com.example.navigation');

      expect(app.matches('navigation'), isTrue);
      expect(app.matches('com.example'), isTrue);
    });

    test('a query that appears in neither does not match', () {
      final app = _app('Maps', 'com.example.maps');

      expect(app.matches('calendar'), isFalse);
    });
  });

  test('byName sorts by label, ignoring case', () {
    final apps = [
      _app('zebra', 'com.example.z'),
      _app('Apple', 'com.example.a'),
      _app('banana', 'com.example.b'),
    ]..sort(InstalledApp.byName);

    expect(apps.map((app) => app.name), ['Apple', 'banana', 'zebra']);
  });

  group('InstalledApp.withMissing', () {
    test('should list a picked app that is not installed or running', () {
      final merged = InstalledApp.withMissing(
        [_app('chrome', 'chrome.exe')],
        {'chrome.exe', 'Discord.exe'},
      );

      expect(merged.map((app) => app.packageName), [
        'chrome.exe',
        'Discord.exe',
      ]);
      expect(merged.map((app) => app.name), ['chrome', 'Discord']);
      expect(merged.last.icon, isNull);
    });

    test('should leave the list alone when every picked app is listed', () {
      final merged = InstalledApp.withMissing(
        [_app('Maps', 'com.example.maps')],
        {'com.example.maps'},
      );

      expect(merged, hasLength(1));
    });

    test('should keep the id as the label when it has no .exe suffix', () {
      final merged = InstalledApp.withMissing(const [], {'com.gone'});

      expect(merged.single.name, 'com.gone');
    });
  });
}
