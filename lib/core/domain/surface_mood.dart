/// What the app's chrome should feel like right now.
///
/// The floor paints backgrounds and navigation for every module, so it needs a
/// key to paint *by* — but it may not know what a tunnel is. This is that key,
/// stated in terms of the surface rather than the feature driving it: whatever
/// a module is doing, it is either resting, working, doing the thing, or
/// telling the user something went wrong.
///
/// Modules map their own state onto this rather than handing their vocabulary
/// down. See `ConnectionStatus.mood`.
enum SurfaceMood {
  /// Nothing in flight, nothing established. The resting state.
  idle,

  /// A transition is running and will settle on its own.
  busy,

  /// The thing the module exists to do is currently happening.
  active,

  /// Something failed and the user needs to see that it did.
  alert,
}
