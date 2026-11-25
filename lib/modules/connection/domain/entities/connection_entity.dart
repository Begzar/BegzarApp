import 'package:begzar/modules/connection/domain/enums/connection_status_enum.dart';
import 'package:begzar/modules/connection/domain/value_objects/ping_result.dart';

/// The connection, as a value.
///
/// There is only ever one connection, so this carries no identity: two of these
/// are the same thing exactly when they say the same thing. It used to hold a
/// generated `ConnectionId` and a `createdAt` that nothing read, with the id
/// sitting in `==` beside the fields a transition does change. That dropped no
/// notification on its own — a status change still compared unequal — but it
/// left the class looking like it had identity to defend, and
/// `ConnectionNotifier` defended it with an `updateShouldNotify` override
/// returning `!identical(previous, next)`. That notified on every new instance,
/// which turned the filtering off entirely and republished states saying exactly
/// what was already on screen. The override and the id went together.
///
/// Comparing what a transition actually changes is what makes the default `==`
/// filtering correct on its own: a transition is published, and republishing
/// what is already on screen is skipped. A notifier holding one of these needs
/// no `updateShouldNotify` override, and should not have one.
class ConnectionEntity {
  const ConnectionEntity({
    required this.status,
    this.connectedAt,
    this.lastPingResult,
    this.errorMessage,
    this.adopted = false,
  });

  /// A connection nothing has been asked of yet.
  const ConnectionEntity.create() : this(status: ConnectionStatus.ready);

  final ConnectionStatus status;
  final DateTime? connectedAt;
  final PingResult? lastPingResult;

  /// Always a `UserFacingErrorKeys` value, never raw text.
  final String? errorMessage;

  /// True when this app found the tunnel already up rather than dialling it.
  ///
  /// A relaunch reaches connected the same way a connect does — the state
  /// starts at ready and `reconcileWithNative` promotes it — so the transition
  /// alone cannot tell a session the user just started from one that was
  /// already running before the process was. Anything that should happen once
  /// per connect, the post-connect ad above all, reads this to tell them apart.
  final bool adopted;

  /// State transition methods
  ConnectionEntity connecting() => copyWith(
    status: ConnectionStatus.connecting,
    errorMessage: null,
    adopted: false,
  );

  /// [at] is when the tunnel came up, where the platform can say — the home
  /// screen counts a session from it, and the app is not always running when
  /// a tunnel starts. Falling back to now is right for the case it covers: a
  /// connect this app just performed, where the two are the same moment.
  ///
  /// [adopted] marks a tunnel that was already up; see the field.
  ConnectionEntity connected({DateTime? at, bool adopted = false}) => copyWith(
    status: ConnectionStatus.connected,
    connectedAt: at ?? DateTime.now(),
    errorMessage: null,
    adopted: adopted,
  );

  ConnectionEntity disconnecting() =>
      copyWith(status: ConnectionStatus.disconnecting, errorMessage: null);

  ConnectionEntity disconnected() => copyWith(
    status: ConnectionStatus.ready,
    errorMessage: null,
    adopted: false,
  );

  ConnectionEntity failed(String error) => copyWith(
    status: ConnectionStatus.error,
    errorMessage: error,
    adopted: false,
  );

  ConnectionEntity withPingResult(PingResult result) =>
      copyWith(lastPingResult: result);

  /// Computed properties
  bool get isActive => status.isActive;
  bool get isTransitional => status.isTransitional;
  bool get hasError => status.hasError;

  Duration? get connectionDuration => connectedAt != null && isActive
      ? DateTime.now().difference(connectedAt!)
      : null;

  ConnectionEntity copyWith({
    ConnectionStatus? status,
    DateTime? connectedAt,
    PingResult? lastPingResult,
    Object? errorMessage = _unset,
    bool? adopted,
  }) => ConnectionEntity(
    status: status ?? this.status,
    connectedAt: connectedAt ?? this.connectedAt,
    lastPingResult: lastPingResult ?? this.lastPingResult,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    adopted: adopted ?? this.adopted,
  );

  /// Equality covers every field, because every field is one a transition can
  /// change and something on screen can read.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionEntity &&
        other.status == status &&
        other.connectedAt == connectedAt &&
        other.lastPingResult == lastPingResult &&
        other.errorMessage == errorMessage &&
        other.adopted == adopted;
  }

  @override
  int get hashCode =>
      Object.hash(status, connectedAt, lastPingResult, errorMessage, adopted);

  @override
  String toString() =>
      'ConnectionEntity(status: $status, errorMessage: $errorMessage)';
}

const Object _unset = Object();
