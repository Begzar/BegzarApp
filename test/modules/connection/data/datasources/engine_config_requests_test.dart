import 'package:begzar/modules/connection/data/datasources/engine_config_requests.dart';
import 'package:begzar/modules/settings/domain/entities/app_routing.dart';
import 'package:begzar/modules/settings/domain/entities/custom_routing_rules.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// Not a real server: the request only carries the link to the engine.
const _link = 'vless://id@vpn.example.net:443?security=tls#t';

const _dnsServer = '192.0.2.53';

const _rules = CustomRoutingRules(
  directDomains: ['domain:direct.example'],
  directIps: ['198.51.100.0/24'],
  blockDomains: ['domain:block.example'],
  blockIps: ['203.0.113.7'],
  proxyDomains: ['domain:proxy.example'],
  proxyIps: ['192.0.2.0/24'],
);

const _forwardingPlatforms = [
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.macOS,
];

void main() {
  group('engineConfigRequest', () {
    test('should carry every routing list to the engine', () {
      final request = engineConfigRequest(
        shareLink: _link,
        customRouting: _rules,
      );

      expect(request.shareLink, _link);
      expect(request.directDomains, _rules.directDomains);
      expect(request.directIps, _rules.directIps);
      expect(request.blockDomains, _rules.blockDomains);
      expect(request.blockIps, _rules.blockIps);
      expect(request.proxyDomains, _rules.proxyDomains);
      expect(request.proxyIps, _rules.proxyIps);
    });

    test('should send the picked programs as the list in force', () {
      final bypassing = engineConfigRequest(
        shareLink: _link,
        appRouting: const AppRouting(
          mode: AppRoutingMode.allExcept,
          apps: ['steam.exe'],
        ),
      );
      expect(bypassing.appsBypassing, ['steam.exe']);
      expect(bypassing.appsOnlyThrough, isEmpty);

      final onlyThrough = engineConfigRequest(
        shareLink: _link,
        appRouting: const AppRouting(
          mode: AppRoutingMode.onlySelected,
          apps: ['chrome.exe'],
        ),
      );
      expect(onlyThrough.appsBypassing, isEmpty);
      expect(onlyThrough.appsOnlyThrough, ['chrome.exe']);
    });

    test('should keep the defaults the engine has always started with', () {
      final request = engineConfigRequest(shareLink: _link);

      expect(request.socksPort, 2080);
      expect(request.listenAddress, '127.0.0.1');
      expect(request.logLevel, 'warning');
      expect(request.dnsServer, '8.8.8.8');
      expect(request.httpPort, isNull);
      expect(request.appsBypassing, isEmpty);
      expect(request.appsOnlyThrough, isEmpty);
      expect(request.resolveServerOutsideTunnel, isFalse);
      expect(request.forwardTunnelDns, isFalse);
    });
  });

  group('vpnModeEngineConfigRequest', () {
    test("should forward the tunnel's DNS on Android and Apple", () {
      for (final platform in _forwardingPlatforms) {
        final request = vpnModeEngineConfigRequest(
          shareLink: _link,
          platform: platform,
          dnsServer: _dnsServer,
          customRouting: _rules,
        );

        expect(
          request.forwardTunnelDns,
          isTrue,
          reason: '${platform.name} hands the system DNS to the engine',
        );
        expect(request.dnsServer, _dnsServer);
        expect(request.blockIps, _rules.blockIps);
      }
    });

    test("should leave the server's lookup and dial to the system", () {
      // Neither tunnel carries the engine's own traffic, so nothing about how
      // the server is reached changes.
      for (final platform in _forwardingPlatforms) {
        final request = vpnModeEngineConfigRequest(
          shareLink: _link,
          platform: platform,
        );
        expect(
          request.resolveServerOutsideTunnel,
          isFalse,
          reason: '${platform.name} must not resolve the server in Xray',
        );
      }
    });

    test('should ask for the config as it always was on Windows and Linux', () {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        final request = vpnModeEngineConfigRequest(
          shareLink: _link,
          platform: platform,
          dnsServer: _dnsServer,
        );
        expect(
          request.forwardTunnelDns,
          isFalse,
          reason: '${platform.name} has no VPN mode of its own',
        );
        expect(request.resolveServerOutsideTunnel, isFalse);
      }
    });
  });
}
