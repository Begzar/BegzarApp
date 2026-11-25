import 'package:begzar/modules/premium/domain/entities/premium_device.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';

/// Everything the account answers with: the subscription, and the
/// devices registered against it.
///
/// The two travel together because the server sends them together. Asking
/// `/premium/devices` for the roster was a second signed request for a payload
/// the app had just been handed, so the roster is read out of this instead.
class PremiumUserData {
  const PremiumUserData({required this.account, required this.devices});

  final PremiumAccount account;
  final LinkedDevices devices;
}
