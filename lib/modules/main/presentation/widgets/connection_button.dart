import 'package:begzar/core/layout/app_layout.dart';
import 'package:begzar/modules/ads/di/ads_providers.dart';
import 'package:begzar/modules/connection/domain/entities/connection_entity.dart';
import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/presentation/controllers/main_screen_controller.dart';
import 'package:begzar/modules/main/presentation/widgets/connect_tap_dialogs.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_dial.dart';
import 'package:begzar/modules/main/presentation/widgets/connection_status_text.dart';
import 'package:begzar/modules/main/presentation/widgets/launch_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The home screen's free-tier body: one dial that connects and disconnects.
class ConnectionButtonWidget extends ConsumerStatefulWidget {
  const ConnectionButtonWidget({super.key});

  @override
  ConsumerState<ConnectionButtonWidget> createState() =>
      _ConnectionButtonWidgetState();
}

class _ConnectionButtonWidgetState
    extends ConsumerState<ConnectionButtonWidget> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(connectionProvider);

    _listenForConnected();

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _handleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LaunchDialSlot(
            builder: (context, covered) => ConnectionDial(
              status: connection.status,
              pressed: _pressed,
              invite: !covered,
            ),
          ),
          SizedBox(height: AppLayout.mainDialToTextGap.h),
          ConnectionStatusText(connection: connection),
        ],
      ),
    );
  }

  void _listenForConnected() {
    ref.listen(connectionProvider, (previous, next) {
      final justConnected =
          next.status == ConnectionStatus.connected &&
          previous?.status != ConnectionStatus.connected;
      if (justConnected) _showAdAfterConnection(next);
    });
  }

  Future<void> _handleTap() async {
    final status = ref.read(connectionProvider).status;
    final outcome = await ref.read(mainScreenProvider).toggleConnection();
    if (!mounted || !outcome.needsExplaining) return;

    await showConnectTapExplanation(context, ref, outcome, status: status);
  }

  Future<void> _showAdAfterConnection(ConnectionEntity connection) async {
    try {
      await ref
          .read(connectionAdHandlerProvider)
          .showAdAfterConnection(connection);
    } catch (_) {
      // Ads must not block the connection UI.
    }
  }
}
