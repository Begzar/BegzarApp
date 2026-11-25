import 'dart:convert';

import 'package:begzar/modules/settings/domain/entities/warp_mode.dart';

/// The launch payload the core's WARP engine reads: the mode, and the
/// resolver its tunnel answers DNS with.
///
/// Nothing else is set, so the engine's own defaults apply: Cloudflare picks
/// the endpoint, Psiphon picks its exit country, and the identities are
/// registered on first use and kept in the work directory. The engine refuses
/// a field it does not know, which is why this sends no more than these two.
String warpEnginePayload(WarpMode mode, {required String dnsServer}) {
  return jsonEncode({
    'mode': mode.engineName,
    if (dnsServer.isNotEmpty) 'dns': dnsServer,
  });
}
