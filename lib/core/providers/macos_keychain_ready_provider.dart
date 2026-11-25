import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Always ready — macOS no longer blocks startup behind a permission gate.
final macOsKeychainReadyProvider = Provider<bool>((ref) => true);
