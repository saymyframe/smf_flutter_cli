# smf_launcher_icons

The SMF module of the app icon with [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons). It provides the app icon role of SMF: an opaque icon on iOS and an adaptive icon with a themed variant on Android, in place of the logo of Flutter. All flavors of the app share the icon.

The module generates the two images that the role names, in `assets/branding/`, which show the logo of Say My Frame, and `flutter_launcher_icons.yaml`. After generation it runs `tool/update_app_icon.dart`, a script of the app, which makes the icon in the Android and iOS projects. The tool is only a dev dependency of the app.

To put your own icon there, replace the two images and run the script again:

```bash
dart tool/update_app_icon.dart
```

Use the script rather than `dart run flutter_launcher_icons`. flutter_launcher_icons 0.14.4 writes the name of the icon into a build setting of the Xcode project that takes `YES` or `NO`, and the script repairs that setting.

## Use with the SMF CLI

`smf create` asks which module provides the app icon, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m launcher_icons
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The launcher_icons module](https://doc.saymyframe.com/modules/launcher-icons)
