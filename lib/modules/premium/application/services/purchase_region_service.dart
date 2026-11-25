import 'dart:async';

import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/core/log/log.dart';
import 'package:begzar/modules/premium/data/repositories/purchase_region_repository.dart';
import 'package:begzar/modules/premium/domain/purchase_region.dart';
import 'package:fpdart/fpdart.dart';

/// Decides whether a buyer is in Iran, asking as little as it can.
///
/// The device's own readings come first and cost nothing, so they are read
/// afresh every time — a buyer who has crossed a border since the last launch
/// is placed where they are now. The address is consulted only when none of
/// those readings already said Iran, so a buyer in Iran is placed without a
/// request leaving the phone and without anything being written down.
///
/// The address answer is the one slow part, so it is kept: in memory for the
/// run, and on disk for [addressTtl] so a launch within a day asks nothing.
/// Neither it nor the verdict is ever sent to the backend or handed to
/// analytics — the only thing either is needed for is which link a button
/// opens.
class PurchaseRegionService {
  PurchaseRegionService(
    this._repository, {
    required bool tunnelCarriesOwnTraffic,
    DateTime Function() clock = DateTime.now,
  }) : _tunnelCarriesOwnTraffic = tunnelCarriesOwnTraffic,
       _clock = clock;

  static const _log = Log('premium');

  /// How long a kept address answer is trusted before it is asked again. An
  /// address moves when its owner travels or puts another VPN in front of
  /// this one, and a day is short enough to follow either.
  static const addressTtl = Duration(hours: 24);

  /// A ceiling over the lookup's own timeouts, which the API client retries
  /// once — without it a black-holed request could hold a buyer for twice as
  /// long.
  static const _addressWait = Duration(seconds: 5);

  final PurchaseRegionRepository _repository;
  final DateTime Function() _clock;

  /// Whether a tunnel that is up also carries this app's own requests.
  ///
  /// On Android the app excludes itself from its own `VpnService`, so a
  /// direct request reports the real address whatever the tunnel is doing. An
  /// Apple packet tunnel routes everything, this app included — the address
  /// it reports is the server's, not the buyer's.
  final bool _tunnelCarriesOwnTraffic;

  /// The address's country for this run. Shared by callers that arrive while
  /// it is in flight, and dropped when the server could not be asked so the
  /// next purchase tries again.
  Future<String?>? _addressCountry;

  Future<PurchaseRegion> resolve({required bool tunnelIsUp}) async {
    final device = await _repository.readDevice();
    final deviceSignal = iranSignalIn(device);
    if (deviceSignal != null) {
      return _verdict(PurchaseRegion.iran, deviceSignal);
    }

    if (tunnelIsUp && _tunnelCarriesOwnTraffic) {
      return _verdict(PurchaseRegion.international, null);
    }

    final address = await (_addressCountry ??= _lookUpAddress());
    final addressSignal = iranSignalIn(device, addressCountry: address);
    return _verdict(
      addressSignal == null
          ? PurchaseRegion.international
          : PurchaseRegion.iran,
      addressSignal,
    );
  }

  /// The kept answer while it is fresh; otherwise the server's, which is then
  /// kept. When the server cannot be asked, a kept answer past its day is
  /// still a better guess than none.
  Future<String?> _lookUpAddress() async {
    final kept = await _repository.readAddressAnswer();
    if (kept != null && _isFresh(kept)) return kept.country;

    final answer = await _repository.addressCountry().timeout(
      _addressWait,
      onTimeout: () => left<ApiFailure, String?>(const TimeoutFailure()),
    );

    switch (answer) {
      case Right(value: final country):
        await _repository.storeAddressAnswer(
          AddressAnswer(country: country, askedAt: _clock()),
        );
        return country;
      case Left(value: final failure):
        _log.warn('purchase.address.failed', {
          'reason': failure.runtimeType,
          'kept': kept != null,
        });
        _addressCountry = null;
        return kept?.country;
    }
  }

  /// A time in the future is not fresh: it means the clock has been moved
  /// since the answer was kept, and nothing about its age can be trusted.
  bool _isFresh(AddressAnswer kept) {
    final age = _clock().difference(kept.askedAt);
    return !age.isNegative && age < addressTtl;
  }

  PurchaseRegion _verdict(PurchaseRegion region, IranSignal? signal) {
    _log.trace('purchase.region', {
      'region': region.name,
      'by': signal?.name ?? 'none',
    });
    return region;
  }
}
