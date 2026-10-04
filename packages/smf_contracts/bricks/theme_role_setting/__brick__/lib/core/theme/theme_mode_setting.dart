import 'package:flutter/material.dart';

import 'theme_mode.dart';

/// The entry of the theme mode on the settings screen of the app: the user
/// selects whether the app is light, dark, or follows the device.
///
/// The entry does not wait until a choice is saved. If the preferences fail
/// to save it, the app shows the selected mode while it runs, its next
/// launch has the mode that was saved before, and the error is one that
/// nothing here catches: it reaches the handlers of the uncaught errors of
/// the app.
class ThemeModeSetting extends StatelessWidget {
  /// Creates the entry.
  const ThemeModeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeModeScope.of(context);
    return RadioGroup<ThemeMode>(
      groupValue: controller.mode,
      onChanged: (mode) {
        if (mode != null) controller.select(mode);
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
}
