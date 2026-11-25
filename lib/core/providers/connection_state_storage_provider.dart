import 'package:begzar/core/data/local/secure_storage/flutter_secure_storage_provider.dart';
import 'package:begzar/core/storage/connection_state_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The post-connect ad-gate flag's store.
///
/// Wired the same way as every other keyed store — settings and premium — so a
/// test overrides one provider to swap the storage underneath it, rather than
/// finding a static to reset between cases.
final connectionStateStorageProvider = Provider<ConnectionStateStorage>((ref) {
  return ConnectionStateStorage(
    storage: ref.watch(flutterSecureStorageProvider),
  );
});
