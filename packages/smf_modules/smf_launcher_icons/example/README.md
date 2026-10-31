# Generate a Flutter app with its own icon

`launcher_icons` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that gives the app an icon in place of the logo of Flutter. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m launcher_icons --no-input
```

The app gets two images, `flutter_launcher_icons.yaml` and a script, `tool/update_app_icon.dart`, which `smf create` runs once:

- `assets/branding/icon.png`, 1024 by 1024 and opaque, for iOS and for Android below API 26.
- `assets/branding/icon_foreground.png`, 1024 by 1024, the logo on a transparent background, for the adaptive icon of Android from API 26 on and for its themed variant.

Both show the logo of Say My Frame until you replace them. Launchers cut the second image to a shape of their own, so keep the whole logo inside a circle around its centre, as wide as 90% of the image. Then make the icon again and commit what changed under `android/` and `ios/`:

```bash
dart tool/update_app_icon.dart
```

`adaptive_icon_background` of `flutter_launcher_icons.yaml` is the colour behind the logo on Android.

All flavors of the app share the icon. A file `flutter_launcher_icons-<flavor>.yaml` turns `flutter_launcher_icons.yaml` off, and on iOS it does not switch the icon of a flavor, so one icon for each flavor needs more than that file.

Without `-m`, `smf create` asks which module provides the app icon.
