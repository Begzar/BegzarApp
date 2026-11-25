/// Where a buyer pays from, which decides where premium is sold to them.
///
/// Buyers in Iran are sold premium through the Telegram bot, and everyone
/// else through the website. What decides is where the device is, not what
/// language it reads: a Persian speaker abroad buys the way everyone abroad
/// does, and a phone in Tehran set to English still buys through the bot.
enum PurchaseRegion { iran, international }

/// Where a purchase tap opens.
///
/// [googlePlay] is a Play build's, wherever the buyer is: Play's rules allow
/// no other way to pay inside an app it distributes, so the region is never
/// asked there.
enum PurchaseDestination { telegramBot, website, googlePlay }

/// Which reading placed the device in Iran — for the debug log and the tests,
/// never for anything a user sees.
enum IranSignal {
  timeZone,
  utcOffset,
  simCountry,
  networkCountry,
  region,
  address,
}

/// What the device itself says about where it is.
///
/// Every field but [utcOffset] is a reading the platform may decline to give:
/// the zone id and both telephony countries come from Android alone, and a
/// tablet has no SIM to ask. A missing reading is silent, not foreign.
class DeviceRegionSignals {
  const DeviceRegionSignals({
    required this.utcOffset,
    this.timeZoneId,
    this.localeLanguage,
    this.localeRegion,
    this.simCountry,
    this.networkCountry,
  });

  /// The device clock's current offset from UTC.
  final Duration utcOffset;

  /// The IANA zone the device is set to, e.g. `Asia/Tehran`.
  final String? timeZoneId;

  /// The primary system locale — the phone's, not the app's.
  final String? localeLanguage;
  final String? localeRegion;

  /// ISO 3166 alpha-2 of the operator that issued the SIM.
  final String? simCountry;

  /// ISO 3166 alpha-2 of the network the radio is registered on — where the
  /// phone is, which a roaming SIM's issuer is not.
  final String? networkCountry;
}

/// What the server last said about the device's address, and when it said it.
///
/// [country] is null when the server answered without one — an answer all the
/// same, and kept like one.
class AddressAnswer {
  const AddressAnswer({required this.country, required this.askedAt});

  final String? country;
  final DateTime askedAt;
}

/// The first reading that places the device in Iran, or null when none does.
///
/// Any one is enough, and none outvotes another: a device in Iran often reads
/// foreign on some axis — a clock left on UTC, a foreign SIM, another VPN in
/// front of this one answering for the address — and rarely reads Iranian by
/// accident.
IranSignal? iranSignalIn(DeviceRegionSignals device, {String? addressCountry}) {
  if (_iranZones.contains(device.timeZoneId)) return IranSignal.timeZone;
  if (device.utcOffset == _iranOffset) return IranSignal.utcOffset;
  if (_isIran(device.simCountry)) return IranSignal.simCountry;
  if (_isIran(device.networkCountry)) return IranSignal.networkCountry;
  if (_isIran(device.localeRegion) && !_isPersian(device.localeLanguage)) {
    return IranSignal.region;
  }
  if (_isIran(addressCountry)) return IranSignal.address;
  return null;
}

PurchaseRegion purchaseRegionFor(
  DeviceRegionSignals device, {
  String? addressCountry,
}) => iranSignalIn(device, addressCountry: addressCountry) == null
    ? PurchaseRegion.international
    : PurchaseRegion.iran;

/// Where a buyer in [region] is sent.
///
/// The bot until the website is ready to take them: a buyer sent to a page
/// that is not there has nowhere to go, where the bot has always sold to
/// everyone.
PurchaseDestination purchaseDestinationFor(
  PurchaseRegion region, {
  required bool websiteReady,
}) => switch (region) {
  PurchaseRegion.iran => PurchaseDestination.telegramBot,
  PurchaseRegion.international =>
    websiteReady
        ? PurchaseDestination.website
        : PurchaseDestination.telegramBot,
};

/// `Iran` is the legacy alias tzdata still links to `Asia/Tehran`.
const _iranZones = {'Asia/Tehran', 'Iran'};

/// Iran has held +03:30 all year since it stopped observing daylight saving in
/// 2022, and no other country uses that offset, so the clock alone places a
/// device there.
///
/// A device whose tz database predates the change still moves to +04:30 in
/// summer, which is also Kabul's offset and so proves nothing — that half of
/// the year is left to the zone id.
const _iranOffset = Duration(hours: 3, minutes: 30);

bool _isIran(String? country) => country?.trim().toUpperCase() == 'IR';

/// Choosing Persian on a phone usually means choosing `fa-IR`: the region comes
/// bundled with the language, so it says what the user reads rather than where
/// they are. A region set to Iran under any other language was chosen for its
/// own sake.
bool _isPersian(String? language) => language?.trim().toLowerCase() == 'fa';
