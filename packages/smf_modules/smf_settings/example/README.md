# Generate a Flutter app with a settings screen

`settings` is the settings screen of the apps that the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) generates. Choose it with `-m`, here with the start screen `home` and the tabs of `bottom_tabs`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,settings,bottom_tabs --no-input
```

The screens and the layout need a router, so `smf create` adds `go_router`, naming the first module that needs it:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding go_router: the only provider of the router role, which home requires.
```

The module writes `lib/features/settings/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';

/// The settings of the app: an entry for each setting that a module of the
/// app has, and what the app is, with its licenses.
class SettingsScreen extends StatelessWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: const [
        AboutListTile(
          icon: Icon(Icons.info_outline),
          applicationName: 'My App',
        ),
      ],
    ),
  );
}
```

The screen is at `/settings`, and it is the second tab of this app, after Home. No module of this app has a setting, so the list has the About row alone; a module with a setting puts its row before it. Without a layout such as `bottom_tabs`, nothing opens the screen: code of the app goes there with `context.nav.settings.settings().go()`, which does not name go_router.

The documentation has more on [the settings module](https://doc.saymyframe.com/modules/settings) and on [navigation in the generated app](https://doc.saymyframe.com/guides/navigation).
