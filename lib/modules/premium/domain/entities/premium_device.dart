/// One device the subscription is currently signed in on.
class PremiumDevice {
  const PremiumDevice({
    required this.deviceId,
    required this.deviceName,
    this.loggedInAt,
  });

  /// The identifier the app generated for this install; the premium API keys
  /// a registration by it, and it is what removing a device names.
  final String deviceId;

  final String deviceName;

  /// Null when the server sent no timestamp, or one it could not parse.
  final DateTime? loggedInAt;
}

/// The device registrations on a subscription, and how many it allows.
///
/// [activeDevices] is the server's own count wherever it sends one, rather
/// than `devices.length`: the two disagree while a registration is being
/// removed, and the seat count the user is shown should be the server's
/// answer. Removing a device answers with it, which is the case that matters —
/// the roster arrives with the account, which does not, so on load
/// the count is the length of the list that came with it.
class LinkedDevices {
  const LinkedDevices({
    required this.maxDevices,
    required this.activeDevices,
    required this.devices,
    this.rosterKnown = true,
  });

  final int maxDevices;
  final int activeDevices;
  final List<PremiumDevice> devices;

  /// Whether the response this was parsed from listed the registrations at all.
  ///
  /// An empty [devices] means two different things on the wire — a roster that
  /// came back with nothing on it, and a body that never carried one — and
  /// only the first of them says a device was removed. Everything that reads
  /// a removal out of this list has to be able to tell them apart.
  final bool rosterKnown;

  /// Whether [deviceId] still holds a seat on this subscription.
  ///
  /// Unanswerable, and so answered as still registered, when the roster is
  /// not known: silence about the registrations is not a report that they are
  /// gone, and reading it as one would sign out every user at once the day the
  /// field stopped being sent.
  bool registers(String deviceId) =>
      !rosterKnown || devices.any((device) => device.deviceId == deviceId);
}
