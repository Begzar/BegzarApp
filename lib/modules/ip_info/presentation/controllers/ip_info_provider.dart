import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/presentation/controllers/connection_notifier.dart';
import 'package:begzar/modules/ip_info/di/ip_info_providers.dart';
import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:begzar/modules/ip_info/domain/errors/ip_info_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

/// Where the internet currently thinks this device is.
///
/// Watches only the connection *status*, so a ping or byte-count update does
/// not re-run the lookup. `autoDispose` so a screen that goes away stops
/// holding the answer.
///
/// The decision itself lives in `IpInfoService`; this reads the tunnel state
/// and hands it down, because the service sits below presentation and cannot
/// watch a notifier.
///
/// The nullable rides through unfolded because all three of its states are
/// ones the pill draws differently: `null` is the tunnel still coming up, a
/// left is every source having been asked and none answering, and a right is
/// an address.
final ipInfoProvider = FutureProvider.autoDispose<Either<IpInfoFailure, IpInfo>?>((
  ref,
) async {
  final status = ref.watch(
    connectionProvider.select((state) => state.status),
  );

  return ref
      .watch(ipInfoServiceProvider)
      .lookup(tunnelIsUp: status == ConnectionStatus.connected);
});
