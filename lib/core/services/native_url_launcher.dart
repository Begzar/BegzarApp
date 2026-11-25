import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens URLs via url_launcher, with a native Android fallback when the plugin
/// channel is unavailable (e.g. after hot restart).
class NativeUrlLauncher {
  static const _channel = MethodChannel('cloud.begzar.begzar/url_launcher');

  static Future<bool> open(String url) async {
    final uri = _parseUrl(url);
    if (uri == null) return false;

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } on MissingPluginException {
      return _openViaNativeChannel(uri.toString());
    } on PlatformException catch (e) {
      if (e.code == 'channel-error') {
        return _openViaNativeChannel(uri.toString());
      }
      rethrow;
    }
  }

  static Future<bool> _openViaNativeChannel(String url) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('openUrl', url);
      return result == true;
    } catch (e) {
      return false;
    }
  }

  static Uri? _parseUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse(trimmed);
      if (uri.hasScheme) return uri;
      return Uri.parse('https://$trimmed');
    } catch (_) {
      return null;
    }
  }
}
