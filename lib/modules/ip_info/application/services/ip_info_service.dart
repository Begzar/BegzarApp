import 'package:begzar/modules/connection/domain/local_proxy_endpoint.dart';
import 'package:begzar/modules/ip_info/data/repositories/ip_info_repository.dart';
import 'package:begzar/modules/ip_info/domain/entities/ip_info.dart';
import 'package:begzar/modules/ip_info/domain/errors/ip_info_failure.dart';
import 'package:fpdart/fpdart.dart';

/// Answers where the internet currently thinks this device is.
///
/// Takes the tunnel state as an argument rather than reading it: this layer
/// sits below presentation and cannot watch the connection notifier, and
/// passing it in keeps the decision testable without a container.
class IpInfoService {
  const IpInfoService(this._repository, {SocksPortReader? socksPort})
    : _socksPort = socksPort;

  final IpInfoRepository _repository;

  /// Where the relay actually ended up listening.
  ///
  /// Asked per lookup rather than captured once, because the port is resolved
  /// at each start and a run that fell back lands somewhere other than
  /// [kDefaultProxyPort]. Reading the constant here would send the lookup at a
  /// port nothing is on, and the location pill would sit there failing while
  /// the tunnel underneath it worked.
  final SocksPortReader? _socksPort;

  /// The exit address, a failure describing why it could not be read, or
  /// `null` when no lookup was attempted at all.
  ///
  /// Those are three different answers and the caller needs to tell them
  /// apart. `null` means only one thing: the tunnel is down, so nothing was
  /// asked. A disconnected device clears the cache and answers nothing rather
  /// than serving the last known exit — a stale country on a screen that says
  /// "disconnected" is worse than a blank one. Failing to reach any source is
  /// a left, and is not the same state as not having looked.
  ///
  /// While the tunnel is up the lookup is forced through the local SOCKS port
  /// on purpose: asking directly would report the device's own address, which
  /// is the one the tunnel exists to hide.
  Future<Either<IpInfoFailure, IpInfo>?> lookup({
    required bool tunnelIsUp,
  }) async {
    if (!tunnelIsUp) {
      _repository.disableProxy();
      _repository.clearCache();
      return null;
    }

    _repository.enableProxy(
      host: kLocalhostListen,
      port: _socksPort?.call() ?? kDefaultProxyPort,
    );
    return _repository.getIpInfo(forceRefresh: true);
  }
}
