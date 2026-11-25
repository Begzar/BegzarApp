import 'package:begzar/modules/premium/domain/entities/premium_server.dart';

/// What a connect landed on, by the names the home row shows it under.
///
/// Stored beside the last-connected ids, because the list fetched on a later
/// launch may no longer carry the server a live tunnel was dialled through,
/// and an id alone cannot be shown.
class PremiumServerLabel {
  const PremiumServerLabel({
    required this.serverName,
    required this.configName,
    this.flagCode,
  });

  /// The label for [config] as the row names it under [server].
  factory PremiumServerLabel.of(
    PremiumServer server,
    PremiumServerConfig config,
  ) => PremiumServerLabel(
    serverName: server.name,
    configName: config.name,
    flagCode: server.flagCode,
  );

  final String serverName;
  final String configName;
  final String? flagCode;

  @override
  bool operator ==(Object other) =>
      other is PremiumServerLabel &&
      other.serverName == serverName &&
      other.configName == configName &&
      other.flagCode == flagCode;

  @override
  int get hashCode => Object.hash(serverName, configName, flagCode);
}
