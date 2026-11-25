import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The latency reading on the home screen.
///
/// `null` data means nothing has been measured yet, which the pill shows as
/// an invitation to tap rather than as a zero.
class PingNotifier extends Notifier<AsyncValue<int?>> {
  /// Long enough after the tunnel reports connected for the first packets to
  /// have a route. Measuring the instant the status flips reads the handshake
  /// rather than the connection.
  static const settleDelay = Duration(milliseconds: 1500);

  @override
  AsyncValue<int?> build() {
    ref.listen(connectionProvider, (previous, next) {
      final justConnected =
          next.status == ConnectionStatus.connected &&
          previous?.status != ConnectionStatus.connected;
      if (!justConnected) return;

      Future.delayed(settleDelay, () {
        if (!ref.mounted) return;
        measure();
      });
    });

    return const AsyncValue.data(null);
  }

  /// Measures through the connection controller, which owns the tunnel and
  /// publishes the result on its own state as well as handing it back.
  Future<void> measure() async {
    state = const AsyncValue.loading();

    final result = await ref.read(connectionProvider.notifier).measurePing();
    if (!ref.mounted) return;

    state = result.isSuccessful
        ? AsyncValue.data(result.latencyMs)
        : AsyncValue.error(
            result.errorMessage ?? ConnectionNotifier.pingFailedKey,
            StackTrace.current,
          );
  }
}

final pingProvider = NotifierProvider<PingNotifier, AsyncValue<int?>>(
  PingNotifier.new,
);
