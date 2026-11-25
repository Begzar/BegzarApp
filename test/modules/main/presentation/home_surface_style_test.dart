import 'package:begzar/core/theme/app_palette.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/main/presentation/home_surface_style.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';
import 'package:begzar/modules/premium/domain/premium_account.dart';
import 'package:begzar/modules/premium/presentation/premium_palette.dart';
import 'package:begzar/modules/premium/presentation/states/premium_servers_state.dart';
import 'package:begzar/modules/premium/presentation/states/premium_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Far enough out that nothing here depends on the clock drifting past it.
final _future = DateTime.now().add(const Duration(days: 30)).toIso8601String();

final _entitled = PremiumSignedIn(
  account: PremiumAccount(username: 'someone', expireDate: _future),
);

const _palette = PremiumPalette(AppPalette.dark);

const _server = PremiumServer(
  id: 7,
  name: 'Sweden',
  configs: [PremiumServerConfig(id: 41, name: 'SE-01', url: 'vless://one')],
);

/// What a connect through [_server] stored about it.
const _storedLabel = PremiumServerLabel(
  serverName: 'Sweden',
  configName: 'SE-01',
  flagCode: 'se',
);

/// A list that no longer offers [_server].
const _otherServer = PremiumServer(
  id: 8,
  name: 'Norway',
  configs: [PremiumServerConfig(id: 52, name: 'NO-01', url: 'vless://two')],
);

void main() {
  group('homeSurfaceChoice', () {
    test('should name the server whose config is connected', () {
      final choice = homeSurfaceChoice(
        _entitled,
        const PremiumServersState(servers: [_server], activeConfigId: 41),
      );

      expect(choice?.serverName, 'Sweden');
      expect(choice?.configName, 'SE-01');
      expect(choice?.configId, 41);
      expect(choice?.withdrawn, isFalse);
    });

    test('should name the config picked from the list while it dials', () {
      final choice = homeSurfaceChoice(
        _entitled,
        const PremiumServersState(servers: [_server], connectingConfigId: 41),
      );

      expect(choice?.serverName, 'Sweden');
    });

    // The list is fetched again on every launch, and the server a live tunnel
    // was dialled through may have been taken off it since.
    test('should name a connected server the list no longer offers', () {
      final choice = homeSurfaceChoice(
        _entitled,
        const PremiumServersState(
          hasLoaded: true,
          servers: [_otherServer],
          activeConfigId: 41,
          activeLabel: _storedLabel,
        ),
      );

      expect(choice?.serverName, 'Sweden');
      expect(choice?.flagCode, 'se');
      expect(choice?.withdrawn, isTrue);
    });

    test('should not call the server withdrawn before the list loads', () {
      final choice = homeSurfaceChoice(
        _entitled,
        const PremiumServersState(
          activeConfigId: 41,
          activeLabel: _storedLabel,
        ),
      );

      expect(choice?.serverName, 'Sweden');
      expect(choice?.withdrawn, isFalse);
    });

    test('should not call the server withdrawn when the list failed', () {
      final choice = homeSurfaceChoice(
        _entitled,
        const PremiumServersState(
          hasLoaded: true,
          errorMessage: 'errNetwork',
          activeConfigId: 41,
          activeLabel: _storedLabel,
        ),
      );

      expect(choice?.serverName, 'Sweden');
      expect(choice?.withdrawn, isFalse);
    });

    test('should name nothing once the tunnel is down', () {
      final choice = homeSurfaceChoice(
        _entitled,
        const PremiumServersState(
          servers: [_server],
          lastConnectedConfigId: 41,
          lastConnectedServerId: 7,
        ),
      );

      expect(choice, isNull);
    });

    // A relaunch that adopts a live tunnel knows the config's id before the
    // listing lands with the server it belongs to.
    test('should name nothing until the listing holds the config', () {
      final choice = homeSurfaceChoice(
        _entitled,
        const PremiumServersState(activeConfigId: 41),
      );

      expect(choice, isNull);
    });

    test('should name nothing while the row makes an offer', () {
      final choice = homeSurfaceChoice(
        const PremiumSignedOut(),
        const PremiumServersState(servers: [_server], activeConfigId: 41),
      );

      expect(choice, isNull);
    });
  });

  group('homeSurfaceBorderColor', () {
    test('should stay neutral once the tunnel is down', () {
      // The config connected last is not what the dial will use, so it gives
      // the surface no tint of its own.
      final color = homeSurfaceBorderColor(
        _palette,
        premium: _entitled,
        servers: const PremiumServersState(
          lastConnectedConfigId: 41,
          lastConnectedServerId: 7,
        ),
        status: ConnectionStatus.ready,
      );

      expect(color, _palette.border);
    });

    test('should light up blue while a config is connected', () {
      final color = homeSurfaceBorderColor(
        _palette,
        premium: _entitled,
        servers: const PremiumServersState(activeConfigId: 41),
        status: ConnectionStatus.connected,
      );

      expect(color, _palette.blue.withValues(alpha: PremiumPalette.liveAlpha));
    });
  });

  group('homeServerRowBorderColor', () {
    test('should turn amber while it names a server the list dropped', () {
      final color = homeServerRowBorderColor(
        _palette,
        premium: _entitled,
        servers: const PremiumServersState(
          hasLoaded: true,
          servers: [_otherServer],
          activeConfigId: 41,
          activeLabel: _storedLabel,
        ),
        status: ConnectionStatus.connected,
      );

      expect(
        color,
        _palette.amberInk.withValues(alpha: PremiumPalette.liveAlpha),
      );
    });

    test('should share the surface tint for a server still offered', () {
      const servers = PremiumServersState(
        hasLoaded: true,
        servers: [_server],
        activeConfigId: 41,
        activeLabel: _storedLabel,
      );

      final color = homeServerRowBorderColor(
        _palette,
        premium: _entitled,
        servers: servers,
        status: ConnectionStatus.connected,
      );

      expect(
        color,
        homeSurfaceBorderColor(
          _palette,
          premium: _entitled,
          servers: servers,
          status: ConnectionStatus.connected,
        ),
      );
    });
  });
}
