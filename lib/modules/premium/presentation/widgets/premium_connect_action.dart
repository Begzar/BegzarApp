import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/main/domain/connect_tap_outcome.dart';
import 'package:begzar/modules/main/presentation/controllers/main_screen_controller.dart';
import 'package:begzar/modules/main/presentation/widgets/connect_tap_dialogs.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/presentation/controllers/premium_servers_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What happens when a config in the premium list is tapped.
///
/// Only two things here are the list's own: whether an already-connected
/// tunnel means disconnect or switch, which needs to know the active config,
/// and the row's spinner. Everything else — the version gate, the entitlement
/// re-check, bracketing the connection into `connecting`, and explaining a
/// refusal — is the same sequence the home dial runs, and runs through
/// [MainScreenController.connectToConfig] rather than a second copy of it.
///
/// A mixin rather than a plain class so `context` and `mounted` are the
/// widget's own: the sequence awaits several times and shows dialogs after
/// each, which a hand-rolled mounted callback would hide from the analyzer.
mixin PremiumConnectAction<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  Future<void> selectConfig(
    PremiumServerConfig config,
    PremiumServer server,
  ) async {
    final status = ref.read(connectionProvider).status;

    // Mid-transition: the tap has nothing stable to act on.
    if (status.isTransitional) return;

    if (status == ConnectionStatus.connected) {
      final activeConfigId = ref.read(premiumServersProvider).activeConfigId;

      // Tapping the config already connected means disconnect.
      if (activeConfigId == config.id) {
        await ref.read(mainScreenProvider).stopConnection();
        return;
      }

      // Switching servers: drop the current tunnel first.
      await ref.read(mainScreenProvider).stopConnection();
      if (!mounted) return;
    }

    // Set before the gate, not after it: the entitlement re-check is a round
    // trip to the server, and the row it was tapped on is what should show it.
    ref.read(premiumServersProvider.notifier).setConnectingConfig(config.id);

    final outcome = await ref
        .read(mainScreenProvider)
        .connectToConfig(config.toProxyConfig(countryName: server.name));

    // A dial that went ahead ends on connected or error, and the list's own
    // listener resolves the spinner from that status. Every other outcome ends
    // the attempt without touching the connection, so nothing else would.
    if (outcome != ConnectTapOutcome.connecting) {
      ref.read(premiumServersProvider.notifier).setConnectingConfig(null);
    }

    if (!mounted || !outcome.needsExplaining) return;
    await showConnectTapExplanation(context, ref, outcome, status: status);
  }
}
