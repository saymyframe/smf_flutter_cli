# smf_shared_preferences

The SMF module of preferences with [shared_preferences](https://pub.dev/packages/shared_preferences). It provides the preferences role of SMF: the app remembers its settings that are no secret between its launches, such as the theme mode, the language, or whether the user has seen the onboarding.

The preferences role generates the `AppPreferences` interface, whose reads are synchronous and whose writes complete once the value is saved, and opens the preferences in `bootstrap()`, before the first frame. This module adds `shared_preferences` to the app and implements the interface on `SharedPreferencesWithCache`, which keeps the values in DataStore on Android and in `UserDefaults` on iOS. With a module that provides dependency injection, the preferences are registered in its container.

Nothing in the preferences is encrypted, and a backup of the device carries them: never store a token, a password, an API key or an encryption key there.

A read returns `null` when its key has no value of its type, and a number is read only as the type that it was saved as: `getDouble` returns `null` for a key with an `int`, and `getInt` for a key with a `double`.

## Use with the SMF CLI

`smf create` asks which module provides the preferences of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m shared_preferences
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The shared_preferences module](https://doc.saymyframe.com/modules/shared-preferences)
- [Preferences](https://doc.saymyframe.com/guides/preferences)
