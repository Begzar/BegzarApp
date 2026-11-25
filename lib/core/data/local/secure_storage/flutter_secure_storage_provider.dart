import 'package:begzar/core/data/local/secure_storage/app_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final flutterSecureStorageProvider = Provider<AppKeyedStorage>((ref) {
  return AppSecureStorage.instance;
});
