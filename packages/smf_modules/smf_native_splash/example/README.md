# Generate a Flutter app with a splash screen for each mode

`native_splash` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that gives an app a splash screen with [flutter_native_splash](https://pub.dev/packages/flutter_native_splash), in place of the white screen of `flutter create`. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m native_splash --no-input
```

`smf create` runs the tool after it generates the app. The app starts with the mark of Say My Frame, in green on cream in the light mode of the device and in cream on green in the dark mode. All flavors share the screen.

To make the screen yours, replace `assets/branding/splash_light.png` and `assets/branding/splash_dark.png`, each 1152 by 1152 with a logo on a transparent background, inside a circle of two thirds of the width of the image. Set the colours behind them in `flutter_native_splash.yaml`. Then make the screen again and commit what changed under `android/` and `ios/`:

```bash
dart run flutter_native_splash:create
```

The documentation has more on [the native_splash module](https://doc.saymyframe.com/modules/native-splash).
