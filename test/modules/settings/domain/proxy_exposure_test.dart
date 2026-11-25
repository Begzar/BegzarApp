import 'package:begzar/modules/connection/domain/local_proxy_endpoint.dart';
import 'package:begzar/modules/settings/domain/entities/proxy_exposure.dart';
import 'package:flutter_test/flutter_test.dart';

ProxyExposure _windows({
  bool? tunnel,
  bool? proxyOnly,
  bool? systemProxy,
  bool? bypassLan,
}) => ProxyExposure.resolve(
  tunnel: tunnel,
  proxyOnly: proxyOnly,
  systemProxy: systemProxy,
  bypassLan: bypassLan,
  systemProxySupported: true,
);

ProxyExposure _mobile({
  bool? tunnel,
  bool? proxyOnly,
  bool? systemProxy,
  bool? bypassLan,
}) => ProxyExposure.resolve(
  tunnel: tunnel,
  proxyOnly: proxyOnly,
  systemProxy: systemProxy,
  bypassLan: bypassLan,
  systemProxySupported: false,
);

/// Everything storage can hand back for one flag: on, off, or never written.
const _storedValues = <bool?>[true, false, null];

void main() {
  group('initial', () {
    // What shows before storage answers. A connect pressed in that moment
    // must not raise an admin prompt nobody asked for, so it is the system
    // proxy even though an empty store resolves to the tunnel.
    test('a platform with a system proxy starts on it', () {
      final exposure = ProxyExposure.initial(systemProxySupported: true);

      expect(exposure.systemProxy, isTrue);
      expect(exposure.proxyOnly, isFalse);
    });

    test('a platform without one starts on neither', () {
      final exposure = ProxyExposure.initial(systemProxySupported: false);

      expect(exposure.systemProxy, isFalse);
      expect(exposure.proxyOnly, isFalse);
    });
  });

  group('resolve', () {
    // A mode is written only when the user picks one, so nothing on disk is
    // someone who never chose, and Windows gives them its tunnel.
    test('should start Windows on the tunnel when no mode was ever picked', () {
      expect(_windows().mode, ExposureMode.tunnel);
      expect(_windows(bypassLan: true).mode, ExposureMode.tunnel);
    });

    test('nothing stored means neither where there is no system proxy', () {
      expect(_mobile().systemProxy, isFalse);
      expect(_mobile().proxyOnly, isFalse);
    });

    // The either/or can be broken on disk by a build that wrote the two flags
    // independently. Proxy-only is the deliberate choice, so it survives.
    test('both stored on resolves to proxy-only', () {
      final exposure = _windows(proxyOnly: true, systemProxy: true);

      expect(exposure.proxyOnly, isTrue);
      expect(exposure.systemProxy, isFalse);
    });

    test('both stored off resolves to the system proxy', () {
      final exposure = _windows(proxyOnly: false, systemProxy: false);

      expect(exposure.proxyOnly, isFalse);
      expect(exposure.systemProxy, isTrue);
    });

    test('a stored system proxy is ignored where the platform has none', () {
      final exposure = _mobile(proxyOnly: true, systemProxy: true);

      expect(exposure.systemProxy, isFalse);
      expect(exposure.proxyOnly, isTrue);
    });

    test('bypass LAN is carried through as stored', () {
      expect(_windows(bypassLan: true).bypassLan, isTrue);
      expect(_windows().bypassLan, isFalse);
    });

    test('should resolve to tunnel only from a stored tunnel on Windows', () {
      final exposure = _windows(
        tunnel: true,
        proxyOnly: false,
        systemProxy: false,
      );

      expect(exposure.mode, ExposureMode.tunnel);
      expect(exposure.tunnel, isTrue);
      expect(exposure.proxyOnly, isFalse);
      expect(exposure.systemProxy, isFalse);
      expect(
        _windows(tunnel: false, proxyOnly: false, systemProxy: false).tunnel,
        isFalse,
      );
    });

    // An install from before the tunnel existed never wrote its key. One that
    // stored any other mode was a user's pick and lands where it was; only
    // one with nothing stored at all moves, to the tunnel.
    test('should keep a mode picked before the tunnel existed', () {
      for (final proxyOnly in _storedValues) {
        for (final systemProxy in _storedValues) {
          final neverPicked = proxyOnly == null && systemProxy == null;
          final exposure = _windows(
            tunnel: null,
            proxyOnly: proxyOnly,
            systemProxy: systemProxy,
          );

          expect(
            exposure.mode,
            neverPicked
                ? ExposureMode.tunnel
                : proxyOnly == true
                ? ExposureMode.proxyOnly
                : ExposureMode.systemProxy,
            reason: 'proxyOnly: $proxyOnly, systemProxy: $systemProxy',
          );
        }
      }
    });

    // A write cut short can leave a tunnel on disk beside another mode. The
    // tunnel costs an admin prompt, so it never wins that tie, and a system
    // proxy never written has always meant on.
    test('should let any other stored mode win over a stored tunnel', () {
      expect(
        _windows(tunnel: true, proxyOnly: true, systemProxy: false).mode,
        ExposureMode.proxyOnly,
      );
      expect(
        _windows(tunnel: true, proxyOnly: false, systemProxy: true).mode,
        ExposureMode.systemProxy,
      );
      expect(
        _windows(tunnel: true, proxyOnly: false).mode,
        ExposureMode.systemProxy,
      );
    });

    // There the tunnel is the platform's own VPN, which proxy-only alone has
    // always decided. The tunnel key is never written there either.
    test('should ignore a stored tunnel where there is no system proxy', () {
      for (final proxyOnly in _storedValues) {
        for (final systemProxy in _storedValues) {
          final unstored = _mobile(
            proxyOnly: proxyOnly,
            systemProxy: systemProxy,
          );

          for (final tunnel in [true, false]) {
            expect(
              _mobile(
                tunnel: tunnel,
                proxyOnly: proxyOnly,
                systemProxy: systemProxy,
              ),
              unstored,
              reason:
                  'tunnel: $tunnel, proxyOnly: $proxyOnly, '
                  'systemProxy: $systemProxy',
            );
          }
          expect(unstored.systemProxy, isFalse);
        }
      }
    });
  });

  group('withMode', () {
    test('should switch Windows to tunnel', () {
      final exposure = _windows().withMode(ExposureMode.tunnel);

      expect(exposure.mode, ExposureMode.tunnel);
      expect(exposure.tunnel, isTrue);
      expect(exposure.systemProxy, isFalse);
      expect(exposure.proxyOnly, isFalse);
    });

    // Nothing to take over, so the call is not a state change the caller
    // should persist or report.
    test('should refuse the system proxy where there is none', () {
      final exposure = _mobile(proxyOnly: true);

      expect(exposure.withMode(ExposureMode.systemProxy), same(exposure));
    });
  });

  group('withProxyOnly', () {
    test('should hand Windows back the system proxy when turned off', () {
      final exposure = _windows(proxyOnly: true).withProxyOnly(false);

      expect(exposure.mode, ExposureMode.systemProxy);
    });

    test('should return to the tunnel elsewhere when turned off', () {
      final exposure = _mobile(proxyOnly: true).withProxyOnly(false);

      expect(exposure.mode, ExposureMode.tunnel);
    });
  });

  group('ExposureMode', () {
    test('should name each mode for analytics', () {
      expect(ExposureMode.tunnel.analyticsValue, 'tunnel');
      expect(ExposureMode.systemProxy.analyticsValue, 'system_proxy');
      expect(ExposureMode.proxyOnly.analyticsValue, 'proxy_only');
    });
  });

  group('the either/or holds through every change', () {
    test('turning proxy-only on hands the system proxy off', () {
      final exposure = _windows().withProxyOnly(true);

      expect(exposure.proxyOnly, isTrue);
      expect(exposure.systemProxy, isFalse);
    });

    test('turning proxy-only off hands the system proxy back', () {
      final exposure = _windows(proxyOnly: true).withProxyOnly(false);

      expect(exposure.proxyOnly, isFalse);
      expect(exposure.systemProxy, isTrue);
    });

    test('proxy-only on a mobile platform leaves the system proxy off', () {
      final exposure = _mobile().withProxyOnly(true);

      expect(exposure.proxyOnly, isTrue);
      expect(exposure.systemProxy, isFalse);
    });
  });

  group('LAN sharing', () {
    test('needs an open SOCKS port, not just the flag', () {
      expect(_windows(bypassLan: true).sharesWithLan, isFalse);
      expect(_windows(proxyOnly: true, bypassLan: true).sharesWithLan, isTrue);
    });

    test('binds every interface only while it actually shares', () {
      expect(
        _windows(proxyOnly: true, bypassLan: true).listenAddress,
        kBypassLanListen,
      );
      expect(_windows(bypassLan: true).listenAddress, kLocalhostListen);
      expect(_windows(proxyOnly: true).listenAddress, kLocalhostListen);
    });

    test('the flag survives a proxy-mode change', () {
      final exposure = _mobile(bypassLan: true).withProxyOnly(true);

      expect(exposure.bypassLan, isTrue);
      expect(exposure.sharesWithLan, isTrue);
    });
  });
}
