import 'dart:convert';
import 'dart:io';

import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/services/release_hint_bus.dart';
import 'package:begzar_engine/begzar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../support/memory_keyed_storage.dart';

/// Replays, through the app's code as it is now, what the engine's
/// operations answered for each case the app recorded before its calls moved
/// to the engine, and holds the app to the outcome it reached then.
///
/// The record was made by a recorder that drove the app's own HTTP client;
/// it went with that client, and its record lives on in the engine.
///
/// Both files live in the private engine (`src/backend/testdata/`); without
/// it, as in the open repository, there is nothing to replay.
class BackendReplay {
  BackendReplay._(this.cases, this.replies);

  static const _dir = 'begzar-engine/src/backend/testdata';

  final List<Map<String, Object?>> cases;
  final Map<String, Map<String, Object?>> replies;

  /// The record and the replies for [name], or null when the engine is not
  /// checked out.
  static BackendReplay? load(String name) {
    final record = File('$_dir/$name.json');
    final answers = File('$_dir/${name}_replies.json');
    if (!record.existsSync() || !answers.existsSync()) return null;
    final cases = (jsonDecode(record.readAsStringSync())['cases'] as List)
        .cast<Map<String, Object?>>();
    final replies = {
      for (final reply
          in (jsonDecode(answers.readAsStringSync())['cases'] as List)
              .cast<Map<String, Object?>>())
        '${reply['op']}/${reply['name']}': reply,
    };
    return BackendReplay._(cases, replies);
  }

  /// Runs [call] for [c] against a backend answering the case's replies in
  /// order, and checks the outcome, the release kept and what was stored.
  Future<void> check<T>(
    Map<String, Object?> c, {
    required Future<Either<ApiFailure, T>> Function(BegzarBackend backend) call,
    required Object? Function(T value) describe,
  }) => _run(c, (backend) async {
    final label = '${c['op']}/${c['name']}';
    final result = await call(backend);
    final outcome = c['outcome']! as Map<String, Object?>;
    result.match(
      (failure) {
        final want = outcome['failure'] as Map<String, Object?>?;
        expect(want, isNotNull, reason: '$label: failed, $failure');
        final got = describeFailure(failure);
        for (final field in ['type', 'key', 'status', 'serverError']) {
          expect(got[field], want![field], reason: '$label: $field');
        }
        // A network failure's message was the HTTP client's own prose, for
        // developers; its key is fixed, so only the type and key are held.
        if (const {
          'ServerFailure',
          'RateLimitFailure',
          'TimeoutFailure',
        }.contains(want!['type'])) {
          expect(got['message'], want['message'], reason: '$label: message');
        }
        if (want['type'] == 'RateLimitFailure') {
          expect(
            got['retryAfterSeconds'],
            want['retryAfterSeconds'],
            reason: '$label: retryAfterSeconds',
          );
        }
      },
      (value) {
        expect(outcome['ok'], isNotNull, reason: '$label: succeeded');
        expect(describe(value), outcome['ok'], reason: '$label: value');
      },
    );
  });

  /// [check] for a call whose result is not an `Either`: [call] describes
  /// what it returned, and that is held to the recorded outcome whole.
  Future<void> checkOutcome(
    Map<String, Object?> c, {
    required Future<Map<String, Object?>> Function(BegzarBackend backend) call,
  }) => _run(c, (backend) async {
    expect(
      await call(backend),
      c['outcome'],
      reason: '${c['op']}/${c['name']}: outcome',
    );
  });

  Future<void> _run(
    Map<String, Object?> c,
    Future<void> Function(BegzarBackend backend) body,
  ) async {
    final label = '${c['op']}/${c['name']}';
    final calls = ((replies[label]!['calls'] as List?) ?? const [])
        .cast<Map<String, Object?>>();
    final backend = ScriptedBackend(calls);
    final store = MemoryKeyedStorage(
      (c['storage']! as Map).cast<String, String>(),
    );
    AppSecureStorage.debugInstance = store;
    ReleaseHintBus.latest = null;
    try {
      await body(backend);
      expect(backend.remaining, isEmpty, reason: '$label: calls not made');

      final latest = ReleaseHintBus.latest;
      expect(
        latest == null
            ? null
            : {'version': latest.version, 'updatedUrl': latest.updatedUrl},
        c['releaseHint'],
        reason: '$label: release kept',
      );
      // Stored JSON is compared as JSON: the order a language's versions
      // are kept in is not something the app reads.
      expect(
        _decoded(stableStorage(store.values)),
        _decoded((c['storageAfter']! as Map).cast<String, String>()),
        reason: '$label: stored',
      );

      // The credentials handed in are the ones the app sent.
      final sent = (c['sent']! as List).cast<Map<String, Object?>>();
      for (final made in backend.made) {
        final request = sent.firstWhere(
          (r) => r['kind'] == made.kind,
          orElse: () => fail('$label: ${made.op} sent nothing'),
        );
        expect(made.credentials, {
          for (final key in made.credentials.keys) key: request[key],
        }, reason: '$label: ${made.op} credentials');
      }
    } finally {
      AppSecureStorage.debugInstance = null;
      ReleaseHintBus.latest = null;
    }
  }
}

/// What was stored, with values that name the clock replaced by a mark.
Map<String, String> stableStorage(Map<String, String> values) => {
  for (final MapEntry(:key, :value) in values.entries)
    key: _clockKeys.contains(key) ? '<time>' : value,
};

const _clockKeys = {'ads_expiry'};

/// How the record described a failure: its type, message, key and the
/// fields a server refusal and a rate limit carry.
Map<String, Object?> describeFailure(ApiFailure failure) => {
  'type': failure.runtimeType.toString(),
  'message': failure.message,
  'key': failure.userFacingKey,
  if (failure case ServerFailure(:final statusCode, :final serverError)) ...{
    'status': statusCode,
    'serverError': serverError,
  },
  if (failure case RateLimitFailure(:final retryAfterSeconds))
    'retryAfterSeconds': retryAfterSeconds,
};

Map<String, Object?> _decoded(Map<String, String> values) => {
  for (final MapEntry(:key, :value) in values.entries) key: _tryJson(value),
};

Object? _tryJson(String value) {
  try {
    return jsonDecode(value);
  } on FormatException {
    return value;
  }
}

/// One call the app made, with what it handed the engine.
class MadeCall {
  MadeCall(this.op, this.kind, this.credentials);

  final String op;

  /// Which of the old clients the recorded request came from.
  final String kind;
  final Map<String, String> credentials;
}

/// A [BegzarBackend] answering the replies the engine gave, in order.
class ScriptedBackend implements BegzarBackend {
  ScriptedBackend(List<Map<String, Object?>> calls) : remaining = [...calls];

  final List<Map<String, Object?>> remaining;
  final List<MadeCall> made = [];

  Future<BackendAnswer<T>> _answer<T>(
    String op,
    String kind,
    Map<String, String> credentials,
    T Function(Object? value) read,
  ) async {
    made.add(MadeCall(op, kind, credentials));
    expect(remaining, isNotEmpty, reason: '$op was not expected');
    final reply = remaining.removeAt(0);
    expect(reply['op'], op);
    final hint = reply['releaseHint'] as Map<String, Object?>?;
    final releaseHint = hint == null
        ? null
        : BackendReleaseHint(
            version: hint['version'] as String?,
            updateUrl: hint['updateUrl'] as String?,
          );
    final e = reply['exception'] as Map<String, Object?>?;
    if (e != null) {
      final refusal = e['refusal'] as String?;
      throw BackendException(
        BackendFailureKind.values.byName(e['kind']! as String),
        message: e['message']! as String,
        status: e['status'] as int?,
        serverMessage: e['serverMessage'] as String?,
        refusal: refusal == null ? null : BackendRefusal.values.byName(refusal),
        retryAfterSeconds: e['retryAfterSeconds'] as int?,
        releaseHint: releaseHint,
      );
    }
    return BackendAnswer(read(reply['value']), releaseHint: releaseHint);
  }

  @override
  Future<BackendAnswer<String>> registerSession() =>
      _answer('registerSession', 'public', const {}, (v) => v! as String);

  @override
  Future<BackendAnswer<List<String>>> fetchFreeServers({
    required String sessionKey,
    required String deviceId,
  }) => _answer('fetchFreeServers', 'free', {
    'sessionKey': sessionKey,
    'deviceId': deviceId,
  }, (v) => (v! as List).cast<String>());

  @override
  Future<BackendAnswer<List<BackendPromotion>>> fetchPromotions({
    required String sessionKey,
    required String deviceId,
  }) => _answer(
    'fetchPromotions',
    'free',
    {'sessionKey': sessionKey, 'deviceId': deviceId},
    (v) =>
        (v! as List).cast<Map<String, Object?>>().map(promotionFrom).toList(),
  );

  static BackendPromotion promotionFrom(Map<String, Object?> p) =>
      BackendPromotion(
        id: p['id']! as int,
        title: p['title']! as String,
        description: p['description']! as String,
        bannerUrl: p['bannerUrl']! as String,
        clickUrl: p['clickUrl']! as String,
        position: p['position']! as String,
        priority: p['priority']! as int,
        startDate: p['startDate']! as String,
        endDate: p['endDate']! as String,
        type: p['type']! as String,
        action: p['action'] as String?,
        buttonColor: p['buttonColor'] as String?,
        duration: p['duration'] as int?,
        byLanguage: {
          for (final version
              in (p['byLanguage']! as List).cast<Map<String, Object?>>())
            version['language']! as String: promotionFrom(
              version['promotion']! as Map<String, Object?>,
            ),
        },
      );

  @override
  Future<BackendAnswer<BackendVersionCatalog?>> appVersionCatalog() => _answer(
    'appVersionCatalog',
    'public',
    const {},
    (v) {
      final platforms = (v! as Map)['platforms'] as Map?;
      if (platforms == null) return null;
      return BackendVersionCatalog({
        for (final MapEntry(key: platform, value: sources) in platforms.entries)
          platform as String: {
            for (final MapEntry(key: source, value: release)
                in (sources as Map).entries)
              source as String: BackendSourceRelease(
                version: (release as Map)['version']! as String,
                latestVersion: release['latestVersion'] as String?,
                url: release['url'] as String?,
              ),
          },
      });
    },
  );

  @override
  Future<BackendAnswer<String?>> lookupRegionCountry() =>
      _answer('lookupRegionCountry', 'public', const {}, (v) => v as String?);

  @override
  Future<BackendAnswer<BackendExitReading>> lookupExit({
    String viaSocks5 = '',
  }) => _answer('lookupExit', 'public', {'viaSocks5': viaSocks5}, (v) {
    final reading = v! as Map;
    return BackendExitReading(
      ip: reading['ip'] as String?,
      country: reading['country'] as String?,
      countryCode: reading['countryCode'] as String?,
    );
  });

  static Map<String, String> _creds(BackendPremiumCredentials c) => {
    'sessionKey': c.sessionKey,
    'deviceId': c.deviceId,
  };

  static BackendAccount _account(Map<String, Object?> a) => BackendAccount(
    username: a['username']! as String,
    email: a['email'] as String?,
    expireDate: a['expireDate'] as String?,
    statusLabel: a['statusLabel'] as String?,
  );

  @override
  Future<BackendAnswer<BackendSession>> premiumSignIn({
    required String username,
    required String password,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  }) => _answer('premiumSignIn', 'premium', _creds(credentials), (v) {
    final s = v! as Map<String, Object?>;
    return BackendSession(
      accessKey: s['accessKey']! as String,
      account: _account(s['account']! as Map<String, Object?>),
    );
  });

  @override
  Future<BackendAnswer<BackendAccountData>> premiumAccount(
    BackendPremiumCredentials credentials,
  ) => _answer('premiumAccount', 'premium', _creds(credentials), (v) {
    final d = v! as Map<String, Object?>;
    final roster = d['roster']! as Map<String, Object?>;
    return BackendAccountData(
      account: _account(d['account']! as Map<String, Object?>),
      rosterKnown: roster['known']! as bool,
      maxDevices: roster['maxDevices'] as int?,
      activeDevices: roster['activeDevices'] as int?,
      devices: [
        for (final device
            in (roster['devices']! as List).cast<Map<String, Object?>>())
          BackendDevice(
            deviceId: device['deviceId']! as String,
            deviceName: device['deviceName'] as String?,
            loggedInAt: device['loggedInAt'] as String?,
          ),
      ],
    );
  });

  @override
  Future<BackendAnswer<void>> premiumSignOut(
    BackendPremiumCredentials credentials,
  ) => _answer('premiumSignOut', 'premium', _creds(credentials), (_) {});

  @override
  Future<BackendAnswer<int>> premiumRemoveDevice({
    required String deviceId,
    required BackendPremiumCredentials credentials,
  }) => _answer(
    'premiumRemoveDevice',
    'premium',
    _creds(credentials),
    (v) => v! as int,
  );

  @override
  Future<BackendAnswer<List<BackendPremiumServer>>> premiumServers(
    BackendPremiumCredentials credentials,
  ) => _answer('premiumServers', 'premium', _creds(credentials), (v) {
    return [
      for (final s in (v! as List).cast<Map<String, Object?>>())
        BackendPremiumServer(
          id: s['id']! as int,
          name: s['name'] as String?,
          icon: s['icon'] as String?,
          configs: [
            for (final c
                in (s['configs']! as List).cast<Map<String, Object?>>())
              BackendPremiumConfig(
                id: c['id']! as int,
                name: c['name'] as String?,
                url: c['url']! as String,
              ),
          ],
        ),
    ];
  });

  @override
  Future<BackendAnswer<int?>> requestSignUpCode({
    required String email,
    required String password,
    required BackendPremiumCredentials credentials,
  }) => _answer(
    'requestSignUpCode',
    'premium',
    _creds(credentials),
    (v) => v as int?,
  );

  @override
  Future<BackendAnswer<int?>> resendSignUpCode({
    required String email,
    required BackendPremiumCredentials credentials,
  }) => _answer(
    'resendSignUpCode',
    'premium',
    _creds(credentials),
    (v) => v as int?,
  );

  @override
  Future<BackendAnswer<BackendSession>> confirmSignUp({
    required String email,
    required String code,
    required String deviceName,
    required BackendPremiumCredentials credentials,
  }) => _answer('confirmSignUp', 'premium', _creds(credentials), (v) {
    final s = v! as Map<String, Object?>;
    return BackendSession(
      accessKey: s['accessKey']! as String,
      account: _account(s['account']! as Map<String, Object?>),
    );
  });

  @override
  Future<BackendAnswer<void>> deleteAccount({
    required String password,
    required BackendPremiumCredentials credentials,
  }) => _answer('deleteAccount', 'premium', _creds(credentials), (_) {});

  @override
  Future<BackendAnswer<List<BackendPlan>>> premiumPlans() =>
      _answer('premiumPlans', 'public', const {}, (v) {
        return [
          for (final p in (v! as List).cast<Map<String, Object?>>())
            BackendPlan(
              devices: p['devices']! as int,
              productId: p['productId']! as String,
              basePlanId: p['basePlanId']! as String,
            ),
        ];
      });

  @override
  Future<BackendAnswer<void>> reportPlayPurchase({
    required String productId,
    required String purchaseToken,
    required BackendPremiumCredentials credentials,
  }) => _answer('reportPlayPurchase', 'premium', _creds(credentials), (_) {});
}
