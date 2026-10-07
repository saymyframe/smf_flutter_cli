# Generate a Flutter app with a settings screen

`settings` is the settings screen of the apps that the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) generates. Choose it with `-m`, here with the start screen `home`, the tabs of `bottom_tabs` and the themes of `material_theme`, which bring a setting:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,settings,bottom_tabs,material_theme --no-input
```

The screens and the layout need a router, and the app remembers the theme mode in its preferences, so `smf create` adds the modules that provide them:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding go_router: the only provider of the router role, which home requires.
Adding shared_preferences: the only provider of the preferences role, which material_theme requires.
```

The module writes `lib/features/settings/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:my_app/core/theme/theme_mode_setting.dart' as entry0;

/// The settings of the app: an entry for each setting that a module of the
/// app has, one below the other in one group.
///
/// As a destination of the main navigation, the screen has no app bar.
/// Shown on top of another screen, it has one, for the back button.
class SettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        header: true,
        // A title that is too long for its line, as with a large text
        // size, gets smaller rather than break inside a word.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text('Settings', style: theme.textTheme.headlineLarge),
        ),
      ),
    );
    // Whether a screen below this one is there to go back to.
    final back = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return Scaffold(
      appBar: back ? AppBar() : null,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            title,
            const SizedBox(height: 20),
            const _Group(children: [entry0.ThemeModeSetting()]),
          ],
        ),
      ),
    );
  }
}

/// The group of the entries of the screen: its [children] one below the
/// other on a card, with a line between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const Divider(height: 1, indent: 56),
          child,
        ],
      ],
    ),
  );
}
```

The screen is at `/settings`, and it is the second tab of this app, after Home. Its group has one row, the theme mode, which the theme of the app brings. Each module with a setting adds its row to the group. In an app whose modules have no setting, the file has a note for you in place of the group: that the app has no settings yet, and the path of this file, where your own setting goes.

Without a layout such as `bottom_tabs`, nothing opens the screen: code of the app shows it on top of the current screen with `context.nav.settings.settings().push<void>()`. The screen then has an app bar with a back button. The call does not name go_router.

The documentation has more on [the settings module](https://doc.saymyframe.com/modules/settings) and on [navigation in the generated app](https://doc.saymyframe.com/guides/navigation).
