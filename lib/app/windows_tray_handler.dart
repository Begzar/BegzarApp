import 'package:begzar/core/services/windows_tray_service.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wires the Windows tray's Disconnect entry to [connectionProvider].
///
/// This is composition, not platform code: [WindowsTrayService] knows how to
/// talk to the native tray and nothing else, and the connection module knows
/// how to drop a tunnel and nothing about trays. Joining the two is the
/// shell's job, which is why this lives here — `lib/core/` may not import a
/// module, and having the tray service reach for a notifier put the floor
/// above the feature standing on it.
class WindowsTrayHandler extends ConsumerStatefulWidget {
  const WindowsTrayHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WindowsTrayHandler> createState() => _WindowsTrayHandlerState();
}

class _WindowsTrayHandlerState extends ConsumerState<WindowsTrayHandler> {
  @override
  void initState() {
    super.initState();
    WindowsTrayService.instance.attach(
      onDisconnectRequested: () {
        final connection = ref.read(connectionProvider);
        // Stopping a connect is a cancel rather than a disconnect: the connect
        // is still running, and a disconnect would leave it free to land a
        // tunnel after the tray said it was gone.
        if (connection.status == ConnectionStatus.connecting) {
          ref.read(connectionProvider.notifier).cancelConnecting();
          return;
        }
        if (!connection.isActive &&
            connection.status != ConnectionStatus.disconnecting) {
          return;
        }
        ref.read(connectionProvider.notifier).disconnect();
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
