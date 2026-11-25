import 'dart:io';

/// Local IPv4 addresses another device on the LAN can reach the SOCKS port
/// at, the likeliest first.
Future<List<String>> getDeviceLanIpv4Addresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
    return await rankLanIpv4Addresses(interfaces);
  } catch (_) {
    return const [];
  }
}

/// Whether [address] is one this machine currently holds.
typedef LanAddressProbe = Future<bool> Function(InternetAddress address);

/// The private IPv4 addresses on [interfaces], ordered so the one a user
/// should copy comes first, without the ones [isHeld] refuses.
///
/// Home routers hand out 192.168/16, so that block leads. 10/8 follows: a LAN
/// can use it, but so does many a VPN client's adapter. 172.16/12 comes last,
/// because that is where Hyper-V, WSL and Docker put their virtual switches,
/// which nothing else on the LAN can reach. Within a block the addresses sort
/// by their numbers rather than as text, so `.9` comes before `.10`.
///
/// Dart says nothing about whether an interface is up, and Windows keeps
/// listing the adapter of a VPN client that is not connected, its address
/// still tentative. [isHeld] asks the platform, and drops what it refuses.
Future<List<String>> rankLanIpv4Addresses(
  Iterable<NetworkInterface> interfaces, {
  LanAddressProbe isHeld = _acceptsBind,
}) async {
  final seen = <String>{};
  final ranked = <({int block, List<int> octets, String address})>[];

  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (address.type != InternetAddressType.IPv4 || address.isLoopback) {
        continue;
      }
      final octets = address.rawAddress;
      final block = _privateBlockRank(octets);
      if (block == null || !seen.add(address.address)) continue;
      if (!await isHeld(address)) continue;

      ranked.add((block: block, octets: octets, address: address.address));
    }
  }

  ranked.sort((a, b) {
    if (a.block != b.block) return a.block.compareTo(b.block);
    for (var i = 0; i < a.octets.length; i++) {
      final byOctet = a.octets[i].compareTo(b.octets[i]);
      if (byOctet != 0) return byOctet;
    }
    return 0;
  });
  return [for (final entry in ranked) entry.address];
}

/// Where an address's private block ranks, lowest first, or null for an
/// address outside all three.
int? _privateBlockRank(List<int> octets) {
  final [a, b, ...] = octets;
  if (a == 192 && b == 168) return 0;
  if (a == 10) return 1;
  if (a == 172 && b >= 16 && b <= 31) return 2;
  return null;
}

/// Whether the platform will bind a socket to [address].
///
/// It will not bind one it does not hold, which is how a tentative address
/// on a disconnected adapter shows itself. Only that refusal drops an
/// address: any other failure, such as a sandbox that allows no sockets,
/// says nothing about the address and leaves it listed.
Future<bool> _acceptsBind(InternetAddress address) async {
  try {
    final socket = await RawDatagramSocket.bind(address, 0);
    socket.close();
    return true;
  } on SocketException catch (e) {
    return e.osError?.errorCode != _addressNotAvailable;
  }
}

/// EADDRNOTAVAIL, as each platform numbers it.
final _addressNotAvailable = Platform.isWindows
    ? 10049
    : Platform.isMacOS || Platform.isIOS
    ? 49
    : 99;
