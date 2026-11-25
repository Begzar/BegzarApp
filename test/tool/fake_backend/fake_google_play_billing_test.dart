import 'package:begzar/modules/premium/data/datasources/premium_remote_data_source.dart';
import 'package:begzar/modules/premium/data/repositories/google_play_billing_repository.dart';
import 'package:begzar/modules/premium/domain/play_purchase.dart';
import 'package:begzar/modules/premium/domain/premium_plan.dart';
import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_keyed_storage.dart';

import '../../../tool/fake_backend/fake_google_play_billing.dart';
import '../../../tool/fake_backend/fake_premium_backend.dart';

const _accountTag = 'account-tag';

GooglePlayBillingRepository _repository() => GooglePlayBillingRepository(
  billing: FakeGooglePlayBilling(),
  remote: PremiumRemoteDataSource(backend: FakePremiumBackend()),
);

Future<List<PremiumPlanOffer>> _offers(
  GooglePlayBillingRepository repository,
) async {
  final offers = await repository.loadOffers();
  return offers.getOrElse((failure) => fail('$failure'));
}

void main() {
  // The data source reads the session key and the install id from storage.
  setUp(() => AppSecureStorage.debugInstance = MemoryKeyedStorage());
  tearDown(() => AppSecureStorage.debugInstance = null);

  group('FakeGooglePlayBilling', () {
    test('should price every plan the fake backend lists', () async {
      final offers = await _offers(_repository());

      expect(offers, hasLength(20));
    });

    test('should sell a plan the fake backend lists', () async {
      final repository = _repository();
      final offer = (await _offers(
        repository,
      )).firstWhere((offer) => offer.plan.devices == 2 && offer.months == 3);
      final purchased = repository.purchases.firstWhere(
        (batch) => batch.any(
          (purchase) => purchase.state == PlayPurchaseState.purchased,
        ),
      );

      final opened = await repository.buy(offer.plan, _accountTag);

      expect(opened, isTrue);
      expect((await purchased).single.productId, offer.plan.productId);
    });
  });
}
