import 'dart:io';
import 'dart:ui' show Rect;

import 'package:begzar/modules/connection/domain/entities/engine_log_line.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart'
    show FileSelectorPlatform, SaveDialogOptions, XTypeGroup;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes the engine log out of the app, as a text file the user chooses
/// what to do with.
///
/// Android and iOS hand the file to the system share sheet. Windows asks
/// where to save it. Linux saves it to Downloads, since it has neither.
/// Nothing is sent anywhere unless the user sends it.
class EngineLogExporter {
  const EngineLogExporter();

  /// Throws when the file could not be written.
  ///
  /// [shareOrigin] is where the share sheet points from on an iPad, which
  /// refuses to open one without it.
  Future<EngineLogExportOutcome> export(
    String text, {
    required String fileName,
    Rect? shareOrigin,
  }) async {
    if (Platform.isWindows) return _saveWithDialog(text, fileName);
    if (Platform.isLinux) return _saveToDownloads(text, fileName);
    return _share(text, fileName, shareOrigin);
  }

  Future<EngineLogExportOutcome> _saveWithDialog(
    String text,
    String fileName,
  ) async {
    final location = await FileSelectorPlatform.instance.getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Text', extensions: ['txt']),
      ],
      options: SaveDialogOptions(suggestedName: fileName),
    );
    if (location == null) return EngineLogExportOutcome.cancelled;
    await File(location.path).writeAsString(text, flush: true);
    return EngineLogExportOutcome.saved;
  }

  Future<EngineLogExportOutcome> _saveToDownloads(
    String text,
    String fileName,
  ) async {
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    await File('${dir.path}/$fileName').writeAsString(text, flush: true);
    return EngineLogExportOutcome.saved;
  }

  Future<EngineLogExportOutcome> _share(
    String text,
    String fileName,
    Rect? shareOrigin,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(text, flush: true);

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/plain', name: fileName)],
        sharePositionOrigin: shareOrigin,
      ),
    );
    return result.status == ShareResultStatus.dismissed
        ? EngineLogExportOutcome.cancelled
        : EngineLogExportOutcome.shared;
  }
}
