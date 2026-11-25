/// The post-connect ad gate: whether an ad is holding the screen, and for how
/// much longer.
class ConnectionAdGateState {
  const ConnectionAdGateState({
    this.isActive = false,
    this.canClose = false,
    this.remainingSeconds = 0,
    this.forceClosed = false,
    this.openedAdClick = false,
  });

  final bool isActive;
  final bool canClose;
  final int remainingSeconds;
  final bool forceClosed;

  /// True after the user opened the ad CTA. Backgrounding for that browser
  /// must not count as skipping the wait, and must not drop the connection.
  final bool openedAdClick;

  ConnectionAdGateState copyWith({
    bool? isActive,
    bool? canClose,
    int? remainingSeconds,
    bool? forceClosed,
    bool? openedAdClick,
  }) {
    return ConnectionAdGateState(
      isActive: isActive ?? this.isActive,
      canClose: canClose ?? this.canClose,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      forceClosed: forceClosed ?? this.forceClosed,
      openedAdClick: openedAdClick ?? this.openedAdClick,
    );
  }

  /// Home-button / app-switch skip: the user left the ad rather than watching
  /// it, so the tunnel it paid for goes away with them.
  ///
  /// An ad CTA launch is not leaving — [openedAdClick] covers the browser the
  /// user was sent to. Neither is a system alert: the VPN permission sheet and
  /// the macOS keychain prompt overlay the app without backgrounding it, which
  /// reaches Flutter as `inactive`, and only `paused` / `hidden` / `detached`
  /// are routed here. That distinction is what this used to spend a blanket
  /// Apple exemption on — an exemption that also handed every iOS and macOS
  /// user a way to keep the tunnel without watching anything.
  bool shouldPenalizeBackground({required bool connectionActive}) {
    if (!isActive || canClose || openedAdClick) {
      return false;
    }
    return connectionActive;
  }
}
