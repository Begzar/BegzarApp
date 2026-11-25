import 'package:flutter/widgets.dart';

/// The router's root navigator.
///
/// In core rather than beside the router so a module can raise a dialog from
/// code that holds no context of its own — the purchase launcher, whose tap
/// has usually taken its own widget off screen by the time it acts.
final rootNavigatorKey = GlobalKey<NavigatorState>();
