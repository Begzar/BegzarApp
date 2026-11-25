import 'package:begzar/core/domain/errors/user_facing_error_keys.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendRefusal;

export 'package:begzar/core/domain/errors/user_facing_error_keys.dart';

/// The message a server failure is shown with.
///
/// A rate limit is a rate limit whatever else it says. A [refusal] the engine
/// named decides next; the backend's own words for its refusals stay in the
/// engine, so they are never matched here. Then the status, and last the
/// developer-facing [message], read for the generic patterns any failure
/// shares.
String serverFailureKey({
  int? statusCode,
  String? serverError,
  String? message,
  BackendRefusal? refusal,
}) {
  if (statusCode == 429) return UserFacingErrorKeys.rateLimit;
  if (refusal != null) return userFacingKeyForRefusal(refusal);
  if (statusCode == 401) return UserFacingErrorKeys.unauthorized;
  if (statusCode == 403) return UserFacingErrorKeys.forbidden;

  final fallback = message ?? serverError;
  if (fallback == null || fallback.trim().isEmpty) {
    return UserFacingErrorKeys.connectionFailed;
  }
  return resolveUserFacingErrorKey(fallback);
}

/// The message a refusal the engine named is shown with.
String userFacingKeyForRefusal(BackendRefusal refusal) => switch (refusal) {
  BackendRefusal.clockSkew => UserFacingErrorKeys.clockSkew,
  BackendRefusal.requestUnverified => UserFacingErrorKeys.requestUnverified,
  BackendRefusal.replayDetected => UserFacingErrorKeys.replayDetected,
  BackendRefusal.ipBlocked => UserFacingErrorKeys.ipBlocked,
  BackendRefusal.missingSession => UserFacingErrorKeys.missingSession,
  BackendRefusal.invalidCredentials => UserFacingErrorKeys.invalidCredentials,
  BackendRefusal.sessionCredentials => UserFacingErrorKeys.sessionCredentials,
  BackendRefusal.deviceNotRegistered => UserFacingErrorKeys.deviceNotRegistered,
  BackendRefusal.accountDisabled => UserFacingErrorKeys.accountDisabled,
  BackendRefusal.accountExpired => UserFacingErrorKeys.accountExpired,
  BackendRefusal.emailTaken => UserFacingErrorKeys.emailTaken,
  BackendRefusal.codeInvalid => UserFacingErrorKeys.codeInvalid,
  BackendRefusal.codeExpired => UserFacingErrorKeys.codeExpired,
  BackendRefusal.tooManyAttempts => UserFacingErrorKeys.tooManyAttempts,
  BackendRefusal.wrongPassword => UserFacingErrorKeys.wrongPassword,
  BackendRefusal.deviceLimit => UserFacingErrorKeys.deviceLimit,
};

/// Returns a safe l10n key for display (never raw server text).
///
/// This is the last resort, for a throw that arrived as prose and never got a
/// type. Anything that implements `Failure` already knows its own key and
/// should be asked for it instead of routed through here.
String resolveUserFacingErrorKey(Object? error) {
  final raw = _extractText(error);
  if (raw.isEmpty) return UserFacingErrorKeys.networkError;
  if (isUserFacingErrorKey(raw)) return raw.trim();

  return _resolveText(raw);
}

String _resolveText(String raw) {
  final text = raw.toLowerCase();

  if (_containsNetworkDetail(text)) {
    return _matchKnownPatterns(text) ?? UserFacingErrorKeys.networkError;
  }

  return _matchKnownPatterns(text) ?? UserFacingErrorKeys.connectionFailed;
}

String? _matchKnownPatterns(String text) {
  if (_matchesStorage(text)) return UserFacingErrorKeys.noStorageAccess;
  if (_matchesRateLimit(text)) return UserFacingErrorKeys.rateLimit;
  if (_matchesUnauthorized(text)) return UserFacingErrorKeys.unauthorized;
  if (_matchesForbidden(text)) return UserFacingErrorKeys.forbidden;
  if (_matchesAccessDenied(text)) return UserFacingErrorKeys.accessDenied;
  if (_matchesSecureConnection(text)) {
    return UserFacingErrorKeys.secureConnectionFailed;
  }
  if (_matchesTimeout(text)) return UserFacingErrorKeys.connectionTimeout;
  if (_matchesNetwork(text)) return UserFacingErrorKeys.networkError;
  if (_matchesDeviceInit(text)) return UserFacingErrorKeys.deviceInitFailed;
  if (_matchesNoConfigsFromServer(text)) {
    return UserFacingErrorKeys.noConfigsFromServer;
  }
  if (_matchesNoConfigsAvailable(text)) {
    return UserFacingErrorKeys.noConfigsAvailable;
  }
  if (_matchesNoWorkingConfig(text)) return UserFacingErrorKeys.noWorkingConfig;
  if (_matchesProxyTest(text)) return UserFacingErrorKeys.proxyTestFailed;
  if (_matchesInvalidConfig(text)) return UserFacingErrorKeys.invalidConfig;
  if (_matchesFetchConfigs(text)) return UserFacingErrorKeys.fetchConfigsFailed;
  if (_matchesServiceUnavailable(text)) {
    return UserFacingErrorKeys.apiV2Unavailable;
  }
  if (_matchesPremiumUnavailable(text)) {
    return UserFacingErrorKeys.premiumApiUnavailable;
  }
  if (_matchesNoResponse(text)) return UserFacingErrorKeys.noResponse;
  if (_matchesConnectionFailed(text)) {
    return UserFacingErrorKeys.connectionFailed;
  }
  return null;
}

String _extractText(Object? error) {
  if (error == null) return '';
  var text = error.toString().trim();
  if (text.isEmpty) return '';

  const prefixes = [
    'Exception: ',
    'ConnectionError(code: CONNECTION_FAILED, message: ',
    'ConnectionError(code: NO_WORKING_CONFIG, message: ',
    'ConnectionError(code: TEST_FAILED, message: ',
    'ConnectionError(code: INVALID_CONFIG, message: ',
    'ConnectionError(code: CONNECTION_TIMEOUT, message: ',
    'ConnectionError(code: VPN_PERMISSION_DENIED, message: ',
    'ConnectionError(code: SERVICE_UNAVAILABLE, message: ',
    'Failed to start VPN mode: ',
    'Failed to start Proxy mode: ',
    'Failed to start test mode: ',
    'Unexpected error: ',
    'Failed to connect: ',
    'Failed to connect with premium configs: ',
    'Auto-connection failed: ',
    'Connection failed: ',
    'Login failed: ',
    'Failed to load premium configs: ',
    'Failed to load premium servers: ',
    'Failed to load devices: ',
    'Failed to remove device: ',
    'Failed to fetch configurations: ',
    'Failed to decrypt subscription: ',
    'Failed to decrypt premium configs: ',
    'Proxy test failed: ',
    'Invalid proxy configuration: ',
  ];
  for (final prefix in prefixes) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length).trim();
    }
  }

  final wrapper = RegExp(r'^ConnectionError\([^,]*,\s*message:\s*(.+)\)$');
  final match = wrapper.firstMatch(text);
  if (match != null) {
    text = match.group(1)!.trim();
  }

  return text;
}

bool _containsNetworkDetail(String text) {
  return text.contains('http://') ||
      text.contains('https://') ||
      text.contains('://') ||
      RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}\b').hasMatch(text) ||
      RegExp(r'\b[\w-]+\.(com|net|org|io|web|app)\b').hasMatch(text);
}

bool _matchesStorage(String text) {
  return text.contains('storage') ||
      text.contains('keychain') ||
      text.contains('secure storage') ||
      text.contains('no storage access');
}

bool _matchesRateLimit(String text) {
  return text.contains('rate limit') ||
      text.contains('too many attempts') ||
      text.contains('429') ||
      text.contains('request limit');
}

bool _matchesUnauthorized(String text) {
  return text.contains('unauthorized') || text.contains('401');
}

bool _matchesForbidden(String text) {
  return text.contains('forbidden') && !text.contains('subscription');
}

bool _matchesAccessDenied(String text) {
  return text.contains('access denied') ||
      text.contains('integrity') ||
      text.contains('signature') ||
      text.contains('invalid credentials') ||
      text.contains('invalid username') ||
      text.contains('device bound') ||
      text.contains('another device') ||
      text.contains('subscription') ||
      text.contains('session not found') ||
      text.contains('sign in') ||
      text.contains('inactive') ||
      text.contains('ip blocked') ||
      text.contains('permission denied') ||
      text.contains('vpn permission') ||
      text.contains('premium session');
}

bool _matchesSecureConnection(String text) {
  return text.contains('certificate') ||
      text.contains('pin mismatch') ||
      text.contains('secure connection failed') ||
      text.contains('tls') && text.contains('fail');
}

bool _matchesTimeout(String text) {
  return text.contains('timed out') ||
      text.contains('timeout') ||
      text.contains('time out');
}

bool _matchesNetwork(String text) {
  return text.contains('network error') ||
      text.contains('socket') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('host lookup') ||
      text.contains('failed host lookup') ||
      text.contains('no internet') ||
      text.contains('offline');
}

bool _matchesDeviceInit(String text) {
  return text.contains('session registration failed') ||
      text.contains('device initialization') ||
      text.contains('device init');
}

bool _matchesNoConfigsFromServer(String text) {
  return text.contains('no configurations available from server') ||
      text.contains('no configurations available') ||
      text.contains('no premium configs found');
}

bool _matchesNoConfigsAvailable(String text) {
  return text.contains('no configs available') ||
      text.contains('configs is empty') ||
      text.contains('empty config');
}

bool _matchesNoWorkingConfig(String text) {
  return text.contains('no working config') ||
      text.contains('no working proxy') ||
      text.contains('no working server') ||
      text.contains('working config found') ||
      text.contains('no configs') ||
      text.contains('decrypt') ||
      text.contains('no premium configs');
}

bool _matchesProxyTest(String text) {
  return text.contains('proxy test') ||
      text.contains('connectivity test') ||
      text.contains('server connectivity');
}

bool _matchesInvalidConfig(String text) {
  return text.contains('invalid config') ||
      text.contains('invalid proxy') ||
      text.contains('invalid url') ||
      text.contains('failed to parse');
}

bool _matchesFetchConfigs(String text) {
  return text.contains('failed to fetch configuration') ||
      text.contains('failed to load premium config') ||
      text.contains('failed to decrypt') ||
      text.contains('unexpected premium configs') ||
      text.contains('unexpected response');
}

bool _matchesServiceUnavailable(String text) {
  return text.contains('api v2 unavailable') ||
      text.contains('connection service unavailable') ||
      text.contains('service unavailable');
}

bool _matchesPremiumUnavailable(String text) {
  return text.contains('premium api unavailable') ||
      text.contains('premium service unavailable');
}

bool _matchesNoResponse(String text) {
  return text.contains('no response') ||
      text.contains('empty response') ||
      text.contains('null response');
}

bool _matchesConnectionFailed(String text) {
  return text.contains('connection failed') ||
      text.contains('failed to connect') ||
      text.contains('auto-connection failed');
}
