# smf_update_required

The SMF module of the screen "Update required". While the version of the app is below the lowest version that may run, the screen takes the place of the app, and its button "Update" opens the page of the app in its store.

How it works:

- The lowest version is `update_required_minimum_version`, a parameter of the remote config of the app, so you raise it without a new version of the app. Its default is empty, which sets no lowest version.
- The version of the app is its version name, such as `1.4.0` of `version: 1.4.0+12`, from [package_info_plus](https://pub.dev/packages/package_info_plus). The two compare number by number, so `1.10.0` is above `1.9.2`.
- Until the user taps "Update", the screen offers no way into the app. From then on, or at once when the store page did not open, it also offers "Not now", which lets the user in for this launch. So a lowest version set too early never locks anyone out.
- The store page comes from the review role of the app: Google Play on Android, and on iOS the App Store page, which needs the App Store ID of the app in `.env`.

The module takes the remote config and the reviews from the modules that provide them, such as `firebase_remote_config` and `in_app_review`.

## Use with the SMF CLI

```bash
smf create my_app -m update_required
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The update_required module](https://doc.saymyframe.com/modules/update-required)
