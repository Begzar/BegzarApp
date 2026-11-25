import 'package:begzar/modules/connection/domain/entities/engine_log_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EngineLogComponent and EngineLogLevel', () {
    test('should read the names the engine sends', () {
      expect(EngineLogComponent.fromName('xray'), EngineLogComponent.xray);
      expect(EngineLogComponent.fromName('warp'), EngineLogComponent.warp);
      expect(EngineLogLevel.fromName('error'), EngineLogLevel.error);
      expect(EngineLogLevel.fromName('warn'), EngineLogLevel.warn);
    });

    test('should take an unknown name as the engine at info', () {
      expect(
        EngineLogComponent.fromName('tun2socks'),
        EngineLogComponent.engine,
      );
      expect(EngineLogLevel.fromName('trace'), EngineLogLevel.info);
    });
  });

  group('export', () {
    final line = EngineLogLine(
      time: DateTime(2026, 3, 4, 5, 6, 7, 89),
      component: EngineLogComponent.warp,
      level: EngineLogLevel.error,
      message: 'register failed endpoint=<ip>:2408',
      fromTunnel: true,
    );

    test('should write one line with its time, process and level', () {
      expect(
        line.toExportText(),
        '2026-03-04 05:06:07.089 warp@tunnel ERROR '
        'register failed endpoint=<ip>:2408',
      );
    });

    test('should head the file with what it is and the version', () {
      final text = engineLogExportText(
        [line],
        exportedAt: DateTime(2026, 3, 4, 6),
        appVersion: '8.0.4+38',
      );
      expect(text, startsWith('Begzar engine log\nApp version: 8.0.4+38\n'));
      expect(text, contains('redacted'));
      expect(text.trim().split('\n').last, line.toExportText());
    });

    test('should stamp the file name, so exports never overwrite', () {
      expect(
        engineLogFileName(DateTime(2026, 11, 9, 8, 7, 6)),
        'begzar-engine-log-20261109-080706.txt',
      );
    });
  });
}
