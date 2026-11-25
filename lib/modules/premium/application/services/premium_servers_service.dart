import 'package:begzar/core/errors/api_failure.dart';
import 'package:begzar/modules/premium/data/repositories/premium_repository.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_label.dart';
import 'package:begzar/modules/premium/domain/entities/premium_server_listing.dart';
import 'package:fpdart/fpdart.dart';

/// The premium server list, as the picker needs it.
class PremiumServersService {
  const PremiumServersService(this._repository);

  final PremiumRepository _repository;

  /// Fetches the list and resolves the stored last-connected pair against it.
  ///
  /// The two reads happen together because neither answer is useful alone:
  /// a remembered server id means nothing until the current list says whether
  /// it is still offered.
  Future<Either<ApiFailure, PremiumServerListing>> loadListing() async {
    final lastConnected = await _repository.readLastConnected();
    final result = await _repository.fetchServers();

    return result.map(
      (servers) => PremiumServerListing.resolve(
        servers: servers,
        lastConnected: lastConnected,
      ),
    );
  }

  /// The list on its own, for quick connect.
  ///
  /// Quick connect tries every config until one answers, so which server was
  /// last used tells it nothing on the way in — and skipping that read keeps it
  /// off disk on the connect path. It still records where it landed on the way
  /// out, through [rememberLastConnected].
  Future<Either<ApiFailure, List<PremiumServer>>> fetchServers() =>
      _repository.fetchServers();

  /// The stored last-connected pair, unresolved against any list.
  ///
  /// [loadListing] is the usual way to read this, because a remembered id is
  /// only meaningful once the current list says whether it is still offered.
  /// This is the exception: quick connect writes the pair from outside the
  /// list, and the list's controller adopts it without re-fetching.
  Future<({int serverId, int configId})?> readLastConnected() =>
      _repository.readLastConnected();

  /// The names saved with the last-connected pair, which outlive the list
  /// that offered them.
  Future<PremiumServerLabel?> readLastConnectedLabel() =>
      _repository.readLastConnectedLabel();

  /// Remembers where a connect landed, so the next launch can point back
  /// at it, and name it even once the list stops offering it.
  Future<void> rememberLastConnected(
    PremiumServer server,
    PremiumServerConfig config,
  ) => _repository.saveLastConnected(
    serverId: server.id,
    configId: config.id,
    label: PremiumServerLabel.of(server, config),
  );

  /// Real-delay latency for each config, in input order.
  Future<List<int?>> measurePings(List<PremiumServerConfig> configs) =>
      _repository.measurePings(configs);
}
