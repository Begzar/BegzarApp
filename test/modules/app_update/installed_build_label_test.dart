import 'package:begzar/modules/app_update/domain/installed_build_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('installedBuildLabel', () {
    test('should join the version and the build as the file names do', () {
      expect(installedBuildLabel('8.0.0', '35'), '8.0.0+35');
    });

    // A per-ABI APK reports 1000 times its ABI's number on top of the build:
    // arm64-v8a's build 35 arrives as 2035, x86_64's as 4035.
    test('should drop the offset a per-ABI Android build adds', () {
      expect(installedBuildLabel('8.0.0', '2035'), '8.0.0+35');
      expect(installedBuildLabel('8.0.0', '1035'), '8.0.0+35');
      expect(installedBuildLabel('8.0.0', '4035'), '8.0.0+35');
    });

    test('should keep a build just under the offset as it is', () {
      expect(installedBuildLabel('8.0.0', '999'), '8.0.0+999');
    });

    test('should show the version alone when the build is missing', () {
      expect(installedBuildLabel('8.0.0', ''), '8.0.0');
    });

    test('should show the version alone when the build is not a number', () {
      expect(installedBuildLabel('8.0.0', 'dev'), '8.0.0');
    });
  });
}
