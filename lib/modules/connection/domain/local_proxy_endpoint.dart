/// The loopback endpoint the proxy engine opens on this device.
///
/// These are engine facts rather than user preferences: the ports are fixed by
/// what the engine binds, and the listen address is a choice between loopback
/// and every interface. Settings decides which address to ask for and shows the
/// port to the user; this module is what actually opens them, so they live
/// here and both sides reference one definition.
library;

/// SOCKS5 port the engine listens on in proxy-only mode.
const kDefaultProxyPort = 2080;

/// HTTP port used when Windows routes the system proxy through the engine.
const kDefaultHttpProxyPort = 2081;

/// Tried in order when the preferred port will not bind.
///
/// Windows hands whole blocks of ports to Hyper-V, WSL and Docker, and a bind
/// inside one is refused outright even with nothing listening — which is what
/// 2080 runs into on a stock developer machine. These are spread across
/// decades of the port space rather than clustered next to the default,
/// because the reservations come in contiguous runs of a hundred: a neighbour
/// of a blocked port is usually blocked too.
///
/// The list is a courtesy, not the guarantee. A machine that blocks all of
/// them still connects on an OS-assigned port — these exist so the common case
/// keeps a predictable number that a user can type into another program.
const kProxyPortFallbacks = <int>[10808, 20800, 38080, 47100];

/// The same, for the Windows system-proxy HTTP listener.
const kHttpProxyPortFallbacks = <int>[10809, 20801, 38081, 47101];

/// Loopback only: nothing outside this device can reach the proxy.
const kLocalhostListen = '127.0.0.1';

/// Every interface, so other devices on the LAN can use this one as a gateway.
const kBypassLanListen = '0.0.0.0';

/// Reads the port the relay is listening on right now.
///
/// A function rather than an `int` because the answer changes at each start
/// and the readers outlive any one of them. It is also what keeps this a
/// downward dependency: the modules that dial through the relay take a reader
/// and never learn that a connection repository is what answers it.
typedef SocksPortReader = int Function();
