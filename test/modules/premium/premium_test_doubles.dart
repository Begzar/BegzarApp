import 'dart:async';

import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar_engine/begzar_engine.dart' show BackendRefusal;
import 'package:begzar/modules/premium/data/repositories/google_play_billing_repository.dart';
import 'package:begzar/modules/premium/data/repositories/premium_repository.dart';
import 'package:begzar/modules/premium/data/repositories/purchase_region_repository.dart';
import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';
import 'package:begzar/modules/premium/domain/entities/premium_session.dart';
import 'package:begzar/modules/premium/domain/entities/premium_user_data.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:fpdart/fpdart.dart';

/// A [PremiumRepository] that answers from scripted values and remembers the
/// session it was handed, so sign-in and sign-out behave as they would.
///
/// `implements` against the concrete class: its constructor and private fields
/// are not part of the implicit interface across a library boundary, so only
/// the public methods need an implementation here.
///
/// Prefer overriding the real repository over a memory-backed [PremiumStorage]
/// where a test is about persistence — this fake is for tests that only need
/// the repository to answer.
class FakePremiumRepository implements PremiumRepository {
  FakePremiumRepository({
    PremiumSession? session,
    this.signInResult,
    this.refreshResult,
    this.serversResult,
    this.devices,
    this.removeDeviceResult,
    this.signUpResult,
    this.resendResult,
    this.verifyResult,
    this.deleteResult,
    this.pingByConfigId = const {},
    this.deviceIdentifier = 'test-device',
  }) : _session = session;

  PremiumSession? _session;

  /// Overrides what [signIn] returns; null signs in as [_session].
  final Either<ApiFailure, PremiumSession>? signInResult;

  /// What a sign-up answers; null sends a code with a minute's wait. Mutable
  /// so a test can let a refused address through on the next try.
  Either<ApiFailure, Duration>? signUpResult;

  /// What a resend answers; null sends a code with a minute's wait.
  Either<ApiFailure, Duration>? resendResult;

  /// What confirming the code answers; a right is stored as the session, the
  /// way the real repository stores it. Null refuses every code. Mutable so a
  /// test can refuse one code and accept the next.
  Either<ApiFailure, PremiumSession>? verifyResult;

  /// What deleting the account answers; a right forgets the session. Null
  /// deletes it.
  Either<ApiFailure, Unit>? deleteResult;

  int signUpCount = 0;
  int resendCount = 0;
  int verifyCount = 0;
  int deleteCount = 0;

  /// Overrides what [refreshAccount] returns. Left as null it reports the
  /// stored account, or no credential when nothing is signed in.
  ///
  /// Mutable so a test can change the server's answer after the session has
  /// been restored — which is the only way to reach the pre-connect gate's
  /// refusals, since a session that is already lapsed on disk never counts
  /// as entitled and so is never re-checked.
  Either<ApiFailure, PremiumAccount>? refreshResult;

  final Either<ApiFailure, List<PremiumServer>>? serversResult;

  /// The roster the account refresh answers with, since the real one carries
  /// it. Null stands for a subscription with nothing registered.
  final LinkedDevices? devices;

  final Either<ApiFailure, int>? removeDeviceResult;

  /// How often the server was asked for the account. The device list rides
  /// along with that answer, so this is also the count of device fetches.
  int refreshAccountCount = 0;

  /// Latency per config id; ids absent from the map fail their ping.
  final Map<int, int> pingByConfigId;

  final String deviceIdentifier;

  int signOutCount = 0;

  /// Thrown by [signOut] when set, the way storage that will not answer
  /// throws. Mutable so a test can let the next sign-out through.
  Object? signOutError;

  final List<int> pingedConfigIds = <int>[];

  @override
  Future<PremiumSession?> readSession() async => _session;

  /// Holds a sign-in open until the test completes it, so a frame can be drawn
  /// while the attempt is under way, as one always is on a real network.
  Completer<void>? signInGate;

  @override
  Future<Either<ApiFailure, PremiumSession>> signIn({
    required String username,
    required String password,
  }) async {
    await signInGate?.future;
    final scripted = signInResult;
    if (scripted == null) {
      final session = _session;
      if (session == null) {
        return left(PremiumRepository.sessionMissingFailure);
      }
      return right(session);
    }
    if (scripted case Right(value: final session)) {
      _session = session;
    }
    return scripted;
  }

  static const _defaultCodeWait = Duration(minutes: 1);

  @override
  Future<Either<ApiFailure, Duration>> signUp({
    required String email,
    required String password,
  }) async {
    signUpCount++;
    return signUpResult ?? right(_defaultCodeWait);
  }

  @override
  Future<Either<ApiFailure, Duration>> resendSignUpCode(String email) async {
    resendCount++;
    return resendResult ?? right(_defaultCodeWait);
  }

  @override
  Future<Either<ApiFailure, PremiumSession>> verifySignUp({
    required String email,
    required String code,
  }) async {
    verifyCount++;
    final scripted =
        verifyResult ??
        left(
          const ServerFailure(
            'invalid_code',
            serverError: 'invalid_code',
            refusal: BackendRefusal.codeInvalid,
          ),
        );
    if (scripted case Right(value: final session)) {
      _session = session;
    }
    return scripted;
  }

  /// What reporting a Play purchase answers; null grants it. Mutable so a
  /// test can let a failed report through on the next try.
  Either<ApiFailure, Unit>? purchaseReportResult;

  /// Every reported purchase, as (product, token).
  final List<(String, String)> reportedPurchases = [];

  @override
  Future<Either<ApiFailure, Unit>> reportGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    if (_session == null) return left(PremiumRepository.sessionMissingFailure);
    reportedPurchases.add((productId, purchaseToken));
    return purchaseReportResult ?? right(unit);
  }

  @override
  Future<Either<ApiFailure, Unit>> deleteAccount(String password) async {
    deleteCount++;
    if (_session == null) return left(PremiumRepository.sessionMissingFailure);
    final scripted = deleteResult ?? right(unit);
    if (scripted.isRight()) _session = null;
    return scripted;
  }

  /// Holds refreshes open, one gate each in the order they are asked, so a
  /// test can let a later refresh answer before an earlier one. Each answers
  /// with what [refreshResult] said when it was asked, as a server would.
  final List<Completer<void>> refreshGates = [];

  @override
  Future<Either<ApiFailure, PremiumUserData>?> refreshAccount() async {
    refreshAccountCount++;

    final session = _session;
    if (session == null) return null;

    final scripted = refreshResult;
    if (refreshGates.isNotEmpty) await refreshGates.removeAt(0).future;

    switch (scripted) {
      case null:
        return right(_userData(session.account));
      case Left(value: final failure):
        return left(failure);
      case Right(value: final account):
        _session = session.copyWith(account: account);
        return right(_userData(account));
    }
  }

  PremiumUserData _userData(PremiumAccount account) => PremiumUserData(
    account: account,
    devices:
        devices ??
        const LinkedDevices(
          maxDevices: 0,
          activeDevices: 0,
          devices: <PremiumDevice>[],
        ),
  );

  @override
  Future<void> signOut() async {
    signOutCount++;
    final error = signOutError;
    if (error != null) throw error;
    _session = null;
  }

  @override
  Future<Either<ApiFailure, int>> removeDevice(String deviceId) async =>
      removeDeviceResult ?? right(0);

  @override
  Future<Either<ApiFailure, List<PremiumServer>>> fetchServers() async =>
      serversResult ?? right(const <PremiumServer>[]);

  @override
  Future<String> deviceId() async => deviceIdentifier;

  ({int serverId, int configId})? lastConnected;

  PremiumServerLabel? lastConnectedLabel;

  @override
  Future<({int serverId, int configId})?> readLastConnected() async =>
      lastConnected;

  @override
  Future<PremiumServerLabel?> readLastConnectedLabel() async =>
      lastConnectedLabel;

  @override
  Future<void> saveLastConnected({
    required int serverId,
    required int configId,
    required PremiumServerLabel label,
  }) async {
    lastConnected = (serverId: serverId, configId: configId);
    lastConnectedLabel = label;
  }

  @override
  Future<List<int?>> measurePings(List<PremiumServerConfig> configs) async {
    return configs.map((config) {
      pingedConfigIds.add(config.id);
      return pingByConfigId[config.id];
    }).toList();
  }
}

/// A [PurchaseRegionRepository] that answers from scripted readings, with no
/// platform channel and no request.
class FakePurchaseRegionRepository implements PurchaseRegionRepository {
  FakePurchaseRegionRepository({
    this.device = const DeviceRegionSignals(utcOffset: Duration.zero),
    this.addressResult,
    this.kept,
  });

  /// Mutable so a test can move the device between two purchases.
  DeviceRegionSignals device;

  /// What the geo lookup answers; null answers with no country. Mutable so a
  /// test can let a failed lookup succeed on the next ask.
  Either<ApiFailure, String?>? addressResult;

  /// How often the address was asked for — the request a buyer the device
  /// already placed must never make.
  int addressAsks = 0;

  /// The answer on disk, as a previous launch would have left it. Written
  /// through by [storeAddressAnswer], so a test can see what was kept.
  AddressAnswer? kept;

  /// How often the device was read — once per purchase decision.
  int deviceReads = 0;

  @override
  Future<DeviceRegionSignals> readDevice() async {
    deviceReads++;
    return device;
  }

  @override
  Future<Either<ApiFailure, String?>> addressCountry() async {
    addressAsks++;
    return addressResult ?? right(null);
  }

  @override
  Future<AddressAnswer?> readAddressAnswer() async => kept;

  @override
  Future<void> storeAddressAnswer(AddressAnswer answer) async => kept = answer;
}

/// A [GooglePlayBillingRepository] that sells from a script: offers to
/// answer with, purchases to push, and a record of what was bought,
/// completed and restored.
class FakeGooglePlayBillingRepository implements GooglePlayBillingRepository {
  FakeGooglePlayBillingRepository({this.offersResult});

  /// What loading the offers answers; null answers with none.
  Either<ApiFailure, List<PremiumPlanOffer>>? offersResult;

  final purchaseUpdates = StreamController<List<PlayPurchase>>.broadcast();

  /// Every billing flow opened, as (plan, account tag).
  final List<(PremiumPlan, String)> bought = [];
  final List<PlayPurchase> completed = [];
  int restoreCount = 0;

  /// Holds a billing flow open until the test completes it, so two taps can
  /// be seen to overlap.
  Completer<bool>? holdBuy;

  /// Holds loading the offers until the test completes it, so the paywall
  /// can be seen while Play is still pricing the plans.
  Completer<void>? holdOffers;

  @override
  Future<Either<ApiFailure, List<PremiumPlanOffer>>> loadOffers() async {
    await holdOffers?.future;
    return offersResult ?? right(const []);
  }

  @override
  Future<bool> buy(PremiumPlan plan, String accountTag) async {
    bought.add((plan, accountTag));
    return holdBuy?.future ?? Future.value(true);
  }

  @override
  Stream<List<PlayPurchase>> get purchases => purchaseUpdates.stream;

  @override
  Future<void> complete(PlayPurchase purchase) async => completed.add(purchase);

  @override
  Future<void> restore() async => restoreCount++;
}
