# Generate a Flutter app that asks its users to update

`update_required` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that shows the screen "Update required" in place of the app while its version is below the lowest version that may run. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m update_required --no-input
```

The module adds package_info_plus to the `pubspec.yaml` of the app, and the screen and its status in `lib/features/update_required/`. It takes the lowest version from remote config and the store page from the reviews of the app, so `smf create` adds a provider of each, such as `firebase_remote_config` and `in_app_review`.

To ask the users of `1.3.x` and older to update, set the parameter `update_required_minimum_version` of remote config to `1.4.0`, once `1.4.0` is in both stores. On iOS, the screen needs the App Store ID of the app in `REVIEW_APP_STORE_ID` of `.env`:

```
REVIEW_APP_STORE_ID=1234567890
```

The router shows the screen and leaves it, so no code of the app navigates to it. Its status is `updateStatus`, in `lib/features/update_required/update_status.dart`:

```dart
ValueListenableBuilder<bool>(
  valueListenable: updateStatus.supported,
  builder: (context, supported, _) => Text(supported ? 'Up to date' : 'Old'),
)
```

The documentation has more on [the update_required module](https://doc.saymyframe.com/modules/update-required).
