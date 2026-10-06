# Generate a Flutter app that remembers its settings

`shared_preferences` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) with which the app remembers its settings that are no secret between its launches. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m shared_preferences --no-input
```

The module adds shared_preferences to the `pubspec.yaml` of the app, and `lib/core/preferences/shared_app_preferences.dart` with the preferences on `SharedPreferencesWithCache`. The rest of the app uses the interface in `lib/core/preferences/app_preferences.dart`, which the preferences role adds: `AppPreferences` has a read and a write for a `String`, a `bool`, an `int`, a `double` and a `List<String>`, such as `getString(key)` and `setString(key, value)`, and `remove(key)`.

`bootstrap()` opens the preferences before the first frame and gives them to each function of `_restorers` in `lib/core/preferences/app_preferences.dart`. Code of the app gets the preferences there. To remember a setting, write such a function and add it to that list. It reads the setting into the state that the widgets listen to, and keeps the preferences for the writes. This one is in a file of `lib/features/reader/`:

```dart
import 'package:flutter/foundation.dart';

import '../../core/preferences/app_preferences.dart';

/// The font size of the reader, which its widgets listen to.
final readerFontSize = ValueNotifier<double>(16);

AppPreferences? _preferences;

/// Restores the font size from the preferences, and keeps them.
void restoreReaderFontSize(AppPreferences preferences) {
  _preferences = preferences;
  readerFontSize.value =
      preferences.getDouble('reader.font_size') ?? readerFontSize.value;
}

/// Changes the font size, and saves it.
Future<void> setReaderFontSize(double size) async {
  readerFontSize.value = size;
  await _preferences?.setDouble('reader.font_size', size);
}
```

A read is synchronous, and returns `null` when the key has no value of its type.

A number is read only as the type that it was saved as: after `setInt('reader.font_size', 18)`, `getDouble('reader.font_size')` returns `null`, and `getInt` returns `null` for a key with a `double`, even a whole number such as `18.0`. So save and read a setting as one type.

shared_preferences keeps the values in DataStore on Android and in `UserDefaults` on iOS. Neither is encrypted, and a backup of the device carries them, so never store a token, a password, an API key or an encryption key in the preferences.

With a module of dependency injection, such as `get_it`, the preferences are registered in the container, and a feature takes them with `resolve` in its composition file.

Without `-m`, `smf create` asks which module provides the preferences of the app.

The documentation has more on [the shared_preferences module](https://doc.saymyframe.com/modules/shared-preferences).
