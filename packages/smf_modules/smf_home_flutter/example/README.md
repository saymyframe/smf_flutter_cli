# Generate a Flutter app with a start screen

`home` is the start screen of the apps that the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) generates. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home --no-input
```

A screen needs a router, so `smf create` adds `go_router` and says why:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding go_router: the only provider of the router role, which home requires.
```

The module writes `lib/features/home/home_screen.dart`:

```dart
import 'package:flutter/material.dart';

/// A neutral screen with the name of the app, which the app can start on.
class HomeScreen extends StatelessWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('My App')));
}
```

The screen is at `/home`, and the app opens on it. Code of the app goes there with `context.nav.home.home().go()`, which does not name go_router. With a layout such as `bottom_tabs`, the screen is the Home tab.

The documentation has more on [the home module](https://doc.saymyframe.com/modules/home) and on [navigation in the generated app](https://doc.saymyframe.com/guides/navigation).
