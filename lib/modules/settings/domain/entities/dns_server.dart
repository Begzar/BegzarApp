/// The resolver address the engine is told to use.
///
/// The engine is handed this string verbatim, so a value that is not an
/// address is not a setting that behaves oddly — it is a resolver that never
/// answers, and every lookup fails once the tunnel is up. It is checked at
/// the point the user types it instead.
///
/// Only literal addresses are accepted. A hostname would need resolving
/// before it could resolve anything, which is a bootstrap the app does not
/// offer anywhere in its UI, and the suggestions beside the field are all
/// literals.
class DnsServer {
  const DnsServer._(this.address);

  /// Google's resolver, used until the user names another one.
  static const fallback = DnsServer._('8.8.8.8');

  /// The address as the engine receives it.
  final String address;

  /// Returns null when [raw] is not an address the engine can query.
  static DnsServer? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (!_isIpv4(value) && !_isIpv6(value)) return null;
    return DnsServer._(value);
  }

  /// Four decimal octets. Anything shorter is a typo rather than a shorthand:
  /// treating `1.1` as `1.0.0.1` would silently configure a resolver the user
  /// did not name.
  static bool _isIpv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return false;

    return parts.every((part) {
      if (part.isEmpty || part.length > 3) return false;
      if (!_isDigits(part)) return false;
      final octet = int.parse(part);
      return octet <= 255;
    });
  }

  /// Up to eight groups of one to four hex digits, with at most one `::`
  /// standing in for the zeroed groups between.
  static bool _isIpv6(String value) {
    if (!value.contains(':')) return false;

    final halves = value.split('::');
    if (halves.length > 2) return false;

    final compressed = halves.length == 2;
    final groups = <String>[
      for (final half in halves)
        ...half.split(':').where((group) => group.isNotEmpty),
    ];

    // A leading or trailing single colon is not a compression marker.
    if (!compressed && (value.startsWith(':') || value.endsWith(':'))) {
      return false;
    }
    if (compressed && groups.length > 7) return false;
    if (!compressed && groups.length != 8) return false;

    return groups.every((group) => group.length <= 4 && _isHexDigits(group));
  }

  static bool _isDigits(String value) =>
      value.codeUnits.every((unit) => unit >= 0x30 && unit <= 0x39);

  static bool _isHexDigits(String value) {
    return value.codeUnits.every((unit) {
      return (unit >= 0x30 && unit <= 0x39) || // 0-9
          (unit >= 0x41 && unit <= 0x46) || // A-F
          (unit >= 0x61 && unit <= 0x66); // a-f
    });
  }

  @override
  bool operator ==(Object other) =>
      other is DnsServer && other.address == address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'DnsServer($address)';
}
