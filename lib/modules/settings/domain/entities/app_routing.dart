/// Which apps the tunnel carries.
enum AppRoutingMode {
  /// Every app uses the VPN except the ones picked.
  allExcept('all_except'),

  /// Only the picked apps use the VPN.
  onlySelected('only_selected');

  const AppRoutingMode(this.storedName);

  /// The name written to disk and sent to analytics. Renaming a value of this
  /// enum must not change it, or every stored choice would read as the default.
  final String storedName;

  /// Reads a stored name back. A missing or unknown value is the mode every
  /// install had before the choice existed.
  static AppRoutingMode fromStored(String? value) {
    for (final mode in values) {
      if (mode.storedName == value) return mode;
    }
    return allExcept;
  }
}

/// What the engine is told about apps: one mode and the apps it applies to.
///
/// The list means the opposite thing in each mode, so it is split into the
/// two getters the engine rules are built from rather than read raw.
class AppRouting {
  const AppRouting({required this.mode, required this.apps});

  /// No app rules at all: the feature is off, or nothing is picked.
  static const none = AppRouting(mode: AppRoutingMode.allExcept, apps: []);

  final AppRoutingMode mode;

  /// The picked apps of the list in force.
  final List<String> apps;

  /// The apps that skip the tunnel. Empty unless every other app is carried.
  List<String> get bypassing =>
      mode == AppRoutingMode.allExcept ? apps : const [];

  /// The only apps that use the tunnel. Empty unless the mode names them.
  List<String> get onlyThrough =>
      mode == AppRoutingMode.onlySelected ? apps : const [];

  @override
  bool operator ==(Object other) {
    if (other is! AppRouting || other.mode != mode) return false;
    if (other.apps.length != apps.length) return false;
    for (var index = 0; index < apps.length; index++) {
      if (other.apps[index] != apps[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(mode, Object.hashAll(apps));

  // Counts only: an app or program name must never reach a log line.
  @override
  String toString() =>
      'AppRouting(mode: ${mode.storedName}, '
      'apps: ${apps.length})';
}

/// The user's choice: a mode and a separate list of picked apps for each.
///
/// Switching mode keeps both lists, because "everything except these" and
/// "only these" are different questions and answering one should not erase
/// the other.
class AppRoutingSelection {
  const AppRoutingSelection({
    this.mode = AppRoutingMode.allExcept,
    this.allExcept = const {},
    this.onlySelected = const {},
  });

  /// What a first launch starts with, and what storage failing falls back to.
  static const initial = AppRoutingSelection();

  final AppRoutingMode mode;

  /// The apps that skip the tunnel while the mode is all-except.
  final Set<String> allExcept;

  /// The apps that use the tunnel while the mode is only-selected.
  final Set<String> onlySelected;

  /// The list the current mode reads.
  Set<String> get inForce => switch (mode) {
    AppRoutingMode.allExcept => allExcept,
    AppRoutingMode.onlySelected => onlySelected,
  };

  /// Every app picked in either list, for showing a pick whose program is not
  /// running when the picker opens.
  Set<String> get everPicked => {...allExcept, ...onlySelected};

  /// Whether this app's traffic goes through the tunnel under the list in
  /// force. An only-selected mode with nothing picked carries everything,
  /// because a tunnel that carried nothing would read as a broken one.
  bool usesVpn(String id) => switch (mode) {
    AppRoutingMode.allExcept => !allExcept.contains(id),
    AppRoutingMode.onlySelected =>
      onlySelected.isEmpty || onlySelected.contains(id),
  };

  /// What the engine is told. Nothing when the feature is off or the list in
  /// force is empty, so a switch left on with no picks changes no routing.
  AppRouting routingWhen({required bool enabled}) {
    if (!enabled || inForce.isEmpty) return AppRouting.none;
    return AppRouting(mode: mode, apps: inForce.toList());
  }

  AppRoutingSelection withMode(AppRoutingMode mode) {
    return AppRoutingSelection(
      mode: mode,
      allExcept: allExcept,
      onlySelected: onlySelected,
    );
  }

  /// Replaces the list in force and leaves the other one untouched.
  AppRoutingSelection withInForce(Set<String> apps) {
    return AppRoutingSelection(
      mode: mode,
      allExcept: mode == AppRoutingMode.allExcept ? apps : allExcept,
      onlySelected: mode == AppRoutingMode.onlySelected ? apps : onlySelected,
    );
  }
}
