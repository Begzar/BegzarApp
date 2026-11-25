/// One app on the device that the user can keep off the tunnel.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.name,
    this.icon,
  });

  /// The identity the engine excludes by. Never shown as the app's name.
  final String packageName;

  /// The launcher label, as the user knows the app.
  final String name;

  /// Raw launcher icon bytes, absent when the platform did not supply one.
  final List<int>? icon;

  /// Whether this app matches what the user typed into the search field.
  ///
  /// The package name is searched as well as the label, because two apps can
  /// share a label and the package is what tells them apart.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return name.toLowerCase().contains(needle) ||
        packageName.toLowerCase().contains(needle);
  }

  /// Case-insensitive by label, which is the order the list is shown in.
  static int byName(InstalledApp a, InstalledApp b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  static const _executableSuffix = '.exe';

  /// A program's label when the platform did not give one: its file name
  /// without the extension, which is how the user knows it.
  static String labelFromId(String id) {
    final isExecutable = id.toLowerCase().endsWith(_executableSuffix);
    if (!isExecutable) return id;
    return id.substring(0, id.length - _executableSuffix.length);
  }

  /// [listed] plus a stub for each picked id the platform did not list.
  ///
  /// A program that is not running, or an app uninstalled since, still holds
  /// a pick; leaving it out of the list would make it impossible to see or
  /// undo. A stub has no icon.
  static List<InstalledApp> withMissing(
    List<InstalledApp> listed,
    Set<String> picked,
  ) {
    final listedIds = {for (final app in listed) app.packageName};
    return [
      ...listed,
      for (final id in picked)
        if (!listedIds.contains(id))
          InstalledApp(packageName: id, name: labelFromId(id)),
    ]..sort(byName);
  }
}
