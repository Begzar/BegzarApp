/// Where the internet currently thinks this device is.
class IpInfo {
  const IpInfo({
    required this.ip,
    required this.country,
    required this.countryCode,
  });

  final String ip;
  final String country;

  /// ISO 3166-1 alpha-2, uppercased on the way into [flagEmoji].
  final String countryCode;

  bool get isIPv6 => ip.contains(':');

  bool get isIPv4 => ip.contains('.') && !ip.contains(':');

  String get ipVersion => isIPv6 ? 'IPv6' : 'IPv4';

  /// The address with everything host-identifying taken out, for a screen
  /// someone may be showing to somebody else. An address in neither shape is
  /// returned untouched rather than guessed at.
  String get maskedIp {
    if (isIPv4) {
      final parts = ip.split('.');
      if (parts.length == _ipv4Groups) {
        return '${parts[0]}.${parts[1]}.***.***';
      }
    } else if (isIPv6) {
      final parts = ip.split(':');
      // The IPv4 shape, two groups kept and two hidden, so both families
      // take the same room on screen.
      if (parts.length >= _ipv6MinGroupsToMask) {
        return '${parts[0]}:${parts[1]}:****:****';
      }
    }
    return ip;
  }

  /// The country's flag, built from the two regional indicator symbols its
  /// code maps to. A code that is not two ASCII letters produces nothing
  /// meaningful, which is the same thing an unknown country should show.
  String get flagEmoji {
    final codePoints = countryCode
        .toUpperCase()
        .codeUnits
        .map((char) => _regionalIndicatorA + (char - _asciiA))
        .toList();
    return String.fromCharCodes(codePoints);
  }

  /// An IPv4 address is exactly four dotted groups.
  static const int _ipv4Groups = 4;

  /// Below three groups there is nothing to mask that is not already elided.
  static const int _ipv6MinGroupsToMask = 3;

  /// 🇦, the first of the 26 regional indicator symbols.
  static const int _regionalIndicatorA = 0x1F1E6;

  static const int _asciiA = 0x41;
}
