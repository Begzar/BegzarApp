import 'package:begzar/modules/settings/data/dtos/installed_app_dto.dart';
import 'package:flutter_test/flutter_test.dart';

const _selfPath = 'C:/Program Files/Begzar/begzar.exe';

void main() {
  group('InstalledAppDto.fromExecutablePaths', () {
    test('should list each program once by file name', () {
      final apps = InstalledAppDto.fromExecutablePaths([
        'C:/Apps/chrome.exe',
        'C:/Apps/chrome.exe',
      ], selfPath: _selfPath);

      expect(apps, hasLength(1));
      expect(apps.single.packageName, 'chrome.exe');
      expect(apps.single.name, 'chrome');
    });

    test('should list one entry for two paths that share a file name', () {
      final apps = InstalledAppDto.fromExecutablePaths([
        'C:/Apps/one/tool.exe',
        'C:/Apps/two/tool.exe',
      ], selfPath: _selfPath);

      expect(apps.map((app) => app.packageName), ['tool.exe']);
    });

    test('should leave out programs under the system folder', () {
      final apps = InstalledAppDto.fromExecutablePaths(
        ['C:/Windows/System32/svchost.exe', 'C:/Apps/chrome.exe'],
        selfPath: _selfPath,
        ignoreCase: true,
        systemFolder: 'c:/windows',
      );

      expect(apps.map((app) => app.packageName), ['chrome.exe']);
    });

    test('should keep a folder that only starts like the system folder', () {
      final apps = InstalledAppDto.fromExecutablePaths(
        ['C:/WindowsApps/store.exe'],
        selfPath: _selfPath,
        ignoreCase: true,
        systemFolder: 'C:/Windows',
      );

      expect(apps.map((app) => app.packageName), ['store.exe']);
    });

    test('should leave out Begzar itself', () {
      final apps = InstalledAppDto.fromExecutablePaths([
        _selfPath,
        'C:/Apps/chrome.exe',
      ], selfPath: _selfPath);

      expect(apps.map((app) => app.packageName), ['chrome.exe']);
    });

    test('should read backslashes as folder separators', () {
      final apps = InstalledAppDto.fromExecutablePaths(
        [
          r'C:\Program Files\Begzar\begzar.exe',
          r'C:\Windows\System32\svchost.exe',
          r'C:\Apps\chrome.exe',
        ],
        selfPath: _selfPath,
        ignoreCase: true,
        systemFolder: r'C:\Windows',
      );

      expect(apps.map((app) => app.packageName), ['chrome.exe']);
    });

    test('should ignore case in paths when told to', () {
      final apps = InstalledAppDto.fromExecutablePaths(
        ['c:/program files/begzar/BEGZAR.EXE', 'C:/WINDOWS/notepad.exe'],
        selfPath: _selfPath,
        ignoreCase: true,
        systemFolder: 'C:/Windows',
      );

      expect(apps, isEmpty);
    });

    test('should leave out a differently cased copy of Begzar', () {
      final apps = InstalledAppDto.fromExecutablePaths(
        ['D:/Portable/Begzar.EXE', 'C:/Apps/chrome.exe'],
        selfPath: _selfPath,
        ignoreCase: true,
      );

      expect(apps.map((app) => app.packageName), ['chrome.exe']);
    });

    test('should keep a differently cased name unless told to ignore case', () {
      final apps = InstalledAppDto.fromExecutablePaths([
        'D:/Portable/Begzar.EXE',
      ], selfPath: _selfPath);

      expect(apps.map((app) => app.packageName), ['Begzar.EXE']);
    });

    test('should keep Linux names as they are', () {
      final apps = InstalledAppDto.fromExecutablePaths([
        '/usr/lib/firefox/firefox',
      ], selfPath: '/opt/begzar/begzar');

      expect(apps.single.packageName, 'firefox');
      expect(apps.single.name, 'firefox');
    });

    // The engine matches a connection by file name, so a second copy of Begzar
    // elsewhere shares the first one's exemption and must not be pickable.
    test('should leave out another copy of Begzar at a different path', () {
      final apps = InstalledAppDto.fromExecutablePaths([
        'D:/Portable/begzar.exe',
        'C:/Apps/chrome.exe',
      ], selfPath: _selfPath);

      expect(apps.map((app) => app.packageName), ['chrome.exe']);
    });

    test('should leave out another copy of Begzar on Linux', () {
      final apps = InstalledAppDto.fromExecutablePaths([
        '/home/user/build/begzar',
      ], selfPath: '/opt/begzar/begzar');

      expect(apps, isEmpty);
    });

    test('should not mistake a Linux file name for Begzar by its case', () {
      final apps = InstalledAppDto.fromExecutablePaths([
        '/opt/other/Begzar',
      ], selfPath: '/opt/begzar/begzar');

      expect(apps.map((app) => app.packageName), ['Begzar']);
    });

    test('should sort the programs by name', () {
      final apps = InstalledAppDto.fromExecutablePaths([
        'C:/Apps/zoom.exe',
        'C:/Apps/Chrome.exe',
        'C:/Apps/astro.exe',
      ], selfPath: _selfPath);

      expect(apps.map((app) => app.name), ['astro', 'Chrome', 'zoom']);
    });
  });
}
