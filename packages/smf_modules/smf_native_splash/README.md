# smf_native_splash

The SMF module of the splash screen of the app. It provides the splash role of SMF with [flutter_native_splash](https://pub.dev/packages/flutter_native_splash): the system shows the screen while the app starts, in place of the white screen of `flutter create`.

The module generates `assets/branding/splash_light.png` and `assets/branding/splash_dark.png`, the mark of Say My Frame for each mode of the device, and `flutter_native_splash.yaml`, with the colours behind them: cream in the light mode and a deep green in the dark mode. `smf create` then runs the tool, which writes the screen into the Android and iOS projects. The tool is a dev dependency, so no code of the app imports it.

All flavors share the screen. The images are for you to replace before you release the app: each is 1152 by 1152, a logo on a transparent background, inside a circle of two thirds of the width of the image, since Android 12 and later cut the rest. After a change of an image or of `flutter_native_splash.yaml`, run this and commit what changed under `android/` and `ios/`:

```bash
dart run flutter_native_splash:create
```

If the tool fails during `smf create`, you still get the app, with a warning and that command to run later.

## Use with the SMF CLI

`smf create` asks which module provides the splash screen, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m native_splash
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The native_splash module](https://doc.saymyframe.com/modules/native-splash)
