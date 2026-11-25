/// What came of asking for a connect.
///
/// The widget used to decide all of this itself: read the force-update flag,
/// read the connection status, drive the premium entitlement check, put the
/// connection into and out of `connecting`, and pick a dialog. Everything up
/// to the dialog is a decision about the app rather than about the widget, so
/// the controller makes it and reports which of these happened.
///
/// Both ways of asking report the same set: the home dial, which picks its own
/// config, and a config tapped in the premium list. They run the same gate, so
/// they can be refused for the same reasons.
///
/// Every outcome except [ignored] is something the user asked for and got an
/// answer to, even when the answer is a refusal.
enum ConnectTapOutcome {
  /// Nothing to do: a tap while a connect or disconnect is already in flight.
  ignored,

  /// The error was sticky and this tap dismissed it. A second tap connects.
  errorCleared,

  /// A connect is under way. The connection state carries it from here.
  connecting,

  /// A disconnect is under way.
  disconnecting,

  /// A connect was under way and this tap called it off. The connection is
  /// back on ready, which says all there is to say.
  cancelled,

  /// Blocked behind the force-update dialog. The versions and the update URL
  /// are on the force-update state.
  updateRequired,

  /// Another app's VPN is on and Begzar could not turn it off. Quick connect
  /// would measure every server through it, so nothing is dialled until the
  /// user turns it off.
  otherVpnOn,

  /// No premium subscription. The free path was not taken because the
  /// account is signed in but not entitled.
  notEntitled,

  /// Signed in, subscription lapsed.
  subscriptionExpired,

  /// Signed in, account disabled by the server. Renewing would not help.
  accountInactive,

  /// The entitlement check did not complete — the server was unreachable or
  /// would not answer. The reason is on the premium state, not the connection
  /// state: a refused gate takes the connection back to ready, so nothing
  /// surfaces on its own and the refusal would otherwise be silent.
  checkFailed;

  /// Whether the outcome has anything for the user to be shown.
  ///
  /// A `switch` rather than a list of comparisons so that adding an outcome
  /// does not silently default to unexplained — the analyzer asks.
  ///
  /// [otherVpnOn] is the one refusal explained elsewhere. The premium list's
  /// measurement is refused for the same reason and has no outcome to carry
  /// it, so the other-VPN alert raises the warning for both, and explaining it
  /// here as well would show it twice.
  bool get needsExplaining => switch (this) {
    ignored ||
    errorCleared ||
    connecting ||
    disconnecting ||
    cancelled ||
    otherVpnOn => false,
    updateRequired ||
    notEntitled ||
    subscriptionExpired ||
    accountInactive ||
    checkFailed => true,
  };
}
