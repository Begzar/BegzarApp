import 'package:begzar/core/domain/surface_mood.dart';

/// Enumeration of possible connection states
enum ConnectionStatus {
  /// Initial state, ready to connect
  ready,

  /// Currently establishing connection
  connecting,

  /// Successfully connected and operational
  connected,

  /// Connection is being disconnected
  disconnecting,

  /// Connection failed or error occurred
  error;

  /// Check if connection is in a transitional state
  bool get isTransitional =>
      this == ConnectionStatus.connecting ||
      this == ConnectionStatus.disconnecting;

  /// Check if connection is stable (either connected or ready)
  bool get isStable =>
      this == ConnectionStatus.connected || this == ConnectionStatus.ready;

  /// Check if connection is active
  bool get isActive => this == ConnectionStatus.connected;

  /// Check if connection has failed
  bool get hasError => this == ConnectionStatus.error;

  /// How the app's chrome should read while the connection is in this state.
  ///
  /// The translation lives here rather than in the theme so that `lib/core/`
  /// never has to learn what a tunnel is: it paints by [SurfaceMood], and each
  /// module says which mood its own states correspond to. Both transitional
  /// states map to [SurfaceMood.busy] — from the surface's point of view
  /// connecting and disconnecting are the same event, something in flight that
  /// will settle without the user doing anything.
  SurfaceMood get mood => switch (this) {
    ConnectionStatus.ready => SurfaceMood.idle,
    ConnectionStatus.connecting => SurfaceMood.busy,
    ConnectionStatus.disconnecting => SurfaceMood.busy,
    ConnectionStatus.connected => SurfaceMood.active,
    ConnectionStatus.error => SurfaceMood.alert,
  };
}
