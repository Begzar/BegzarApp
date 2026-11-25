// The open engine stub's copy of the private engine's public model, with the
// wire conversions it has no use for removed. Keep it in step with the engine:
// scripts/check_engine_stub.sh fails when the app uses something it lacks.

/// Every user-visible string on the ongoing tunnel notification.
///
/// The plugin posts the notification but owns none of its wording. It ships no
/// locales and no product name, so an embedder that has both passes the text
/// in; anything hardcoded here would reach users in one language.
class BegzarNotificationText {
  const BegzarNotificationText({
    required this.title,
    required this.body,
    required this.disconnectLabel,
    required this.channelName,
    required this.channelDescription,
  });

  /// First line, naming what is connected.
  final String title;

  /// Second line. Usually which mode the tunnel is running in.
  final String body;

  /// Label on the action that stops the tunnel.
  final String disconnectLabel;

  /// Channel name, as it reads in the system notification settings.
  final String channelName;

  /// Channel description, shown under the name in those same settings.
  final String channelDescription;
}
