import 'package:flutter/material.dart';

import 'theme_mode.dart';

/// The setting of the theme mode of the app, an entry of the settings
/// screen: it shows the mode that the user selected, and lets the user
/// select whether the app is light, dark, or follows the device.
///
/// The entry does not wait until a choice is saved. If the preferences fail
/// to save it, the app shows the selected mode while it runs, its next
/// launch has the mode that was saved before, and the error is one that
/// nothing here catches: it reaches the handlers of the uncaught errors of
/// the app.
class ThemeModeSetting extends StatelessWidget {
  /// Creates the setting.
  const ThemeModeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  {{{text_title}}},
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // The names of the modes share the width of the entry, so at a
          // large text size they grow only by half.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                ),
              ),
              segments: [
                for (final (mode, icon, name) in [
                  (
                    ThemeMode.system,
                    Icons.brightness_auto_outlined,
                    {{{text_system}}},
                  ),
                  (
                    ThemeMode.light,
                    Icons.light_mode_outlined,
                    {{{text_light}}},
                  ),
                  (
                    ThemeMode.dark,
                    Icons.dark_mode_outlined,
                    {{{text_dark}}},
                  ),
                ])
                  ButtonSegment(
                    value: mode,
                    // The icon above the name, so that a long name of a
                    // mode has the width of its segment.
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(height: 4),
                        // On one line, and scaled down where it is wider
                        // than its segment.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(name, maxLines: 1, softWrap: false),
                        ),
                      ],
                    ),
                  ),
              ],
              selected: {AppThemeModeScope.of(context)},
              onSelectionChanged: (modes) => appThemeMode.choose(modes.single),
            ),
          ),
        ],
      ),
    );
  }
}
