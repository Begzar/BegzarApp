import 'dart:ui';

import 'package:begzar/modules/connection/data/datasources/engine_log_data_source.dart';
import 'package:begzar/modules/connection/data/datasources/engine_log_exporter.dart';
import 'package:begzar/modules/connection/domain/entities/engine_log_line.dart';
import 'package:begzar/modules/connection/domain/errors/connection_failure.dart';
import 'package:fpdart/fpdart.dart' hide State;

/// The engine log the log viewer shows: read, cleared, and exported.
///
/// A throw from the engine or the file system comes back as a left. The
/// failure's message names only the throw's type: engine prose can quote
/// what it was handed, and a failure outlives the call that made it.
class EngineLogRepository {
  EngineLogRepository(
    this._source,
    this._exporter, {
    required Future<String> Function() appVersion,
    DateTime Function()? clock,
  }) : _appVersion = appVersion,
       _clock = clock ?? DateTime.now;

  final EngineLogDataSource _source;
  final EngineLogExporter _exporter;
  final Future<String> Function() _appVersion;
  final DateTime Function() _clock;

  /// The lines since the last read, or every line kept with [fromStart].
  /// With [wait], a read that finds nothing new is held until a line arrives.
  Future<Either<ConnectionFailure, EngineLogBatch>> read({
    bool fromStart = false,
    Duration wait = Duration.zero,
  }) async {
    try {
      return right(await _source.read(fromStart: fromStart, wait: wait));
    } catch (e) {
      return left(EngineLogReadFailure('read engine log: ${e.runtimeType}'));
    }
  }

  Future<Either<ConnectionFailure, Unit>> clear() async {
    try {
      await _source.clear();
      return right(unit);
    } catch (e) {
      return left(EngineLogReadFailure('clear engine log: ${e.runtimeType}'));
    }
  }

  /// Writes [lines] to a text file and hands it to the share sheet, or the
  /// save dialog on Windows.
  Future<Either<ConnectionFailure, EngineLogExportOutcome>> export(
    List<EngineLogLine> lines, {
    Rect? shareOrigin,
  }) async {
    try {
      final now = _clock();
      final text = engineLogExportText(
        lines,
        exportedAt: now,
        appVersion: await _appVersionOrUnknown(),
      );
      return right(
        await _exporter.export(
          text,
          fileName: engineLogFileName(now),
          shareOrigin: shareOrigin,
        ),
      );
    } catch (e) {
      return left(
        EngineLogExportFailure('export engine log: ${e.runtimeType}'),
      );
    }
  }

  Future<String> _appVersionOrUnknown() async {
    try {
      return await _appVersion();
    } catch (_) {
      return 'unknown';
    }
  }
}
