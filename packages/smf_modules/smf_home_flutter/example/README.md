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

The module writes `lib/features/home/home_screen.dart`, a welcome to the developer of the app. The screen greets by the time of the day and names the app. A card shows the app as a cell of the periodic table, and the module makes the symbol and the number of the cell from the name of the app:

```dart
/// The name of the app, as the screen shows it.
const _appName = 'My App';

/// The symbol of the app in its cell, as an element of the periodic table
/// has one: the first letters of the first two words of its name, or the
/// first two letters of a name of one word.
const _appSymbol = 'Ma';

/// The number in the cell of the app: how many letters and digits its name
/// has.
const _appNumber = 5;
```

Below the card, the screen lists three next steps, each with the path or the address that it is about, which a tap copies. The first step is to replace the content of the screen with your own:

```dart
/// The screen that the app starts on: a welcome to the developer of the app,
/// with what to do next. Replace its content with the first screen of the
/// app.
class HomeScreen extends StatefulWidget {
  /// Creates the screen, which greets by the time that [now] tells.
  const HomeScreen({super.key, this.now = DateTime.now});

  /// Tells the time, for the greeting of the screen. A test gives a time of
  /// its own.
  final DateTime Function() now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
```

The screen shows the mark of Say My Frame. The module writes the image into the folder of the feature, with files for sharper screens in `2.0x/` and `3.0x/` next to it, and declares it in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - lib/features/home/assets/smf_mark.png
```

The screen is at `/home`, and the app opens on it. Code of the app goes there with `context.nav.home.home().go()`, which does not name go_router. With a layout such as `bottom_tabs`, the screen is the Home tab.

The documentation has more on [the home module](https://doc.saymyframe.com/modules/home) and on [navigation in the generated app](https://doc.saymyframe.com/guides/navigation).
