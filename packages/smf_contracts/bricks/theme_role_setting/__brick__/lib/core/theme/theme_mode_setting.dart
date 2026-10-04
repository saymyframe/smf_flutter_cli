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
  Widget build(BuildContext context) => RadioGroup<ThemeMode>(
        groupValue: AppThemeModeScope.of(context),
        onChanged: (mode) {
          if (mode != null) appThemeMode.choose(mode);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text({{{text_title}}}),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              title: Text({{{text_system}}}),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              title: Text({{{text_light}}}),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              title: Text({{{text_dark}}}),
            ),
          ],
        ),
      );
}
