import 'package:begzar/core/widgets/app_glass.dart';
import 'package:begzar/modules/settings/presentation/settings_palette.dart';

/// The settings module's surfaces, drawn through [AppGlassPanel].
///
/// Opaque ink rather than frosted glass: the settings screens sit on the
/// account tab's ground, where a card reads by its own fill and a hairline
/// rim.
abstract final class SettingsGlass {
  /// The rim every settings card carries.
  static const _rimWidth = 1.0;

  static AppGlassStyle panel(
    SettingsPalette palette, {
    required double cornerRadius,
  }) => AppGlassStyle(
    cornerRadius: cornerRadius,
    color: palette.card,
    borderColor: palette.borderSoft,
    borderWidth: _rimWidth,
  );

  static AppGlassStyle chip(
    SettingsPalette palette, {
    required double cornerRadius,
  }) => AppGlassStyle(cornerRadius: cornerRadius, color: palette.cardRaised);
}

/// A settings card sized by [child].
class SettingsGlassPanel extends AppGlassPanel {
  const SettingsGlassPanel({
    super.key,
    required super.style,
    required super.child,
  });
}
