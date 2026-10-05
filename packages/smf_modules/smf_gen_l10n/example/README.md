# Generate a Flutter app with its texts in ARB files

`gen_l10n` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that keeps the texts of the app in ARB files, from which Flutter generates the code that reads them. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m gen_l10n --no-input
```

The module adds to the app:

- `l10n.yaml`, the options of gen-l10n, and `generate: true` in `pubspec.yaml`, with which `flutter pub get` generates the `AppLocalizations` class in `lib/l10n`;
- `lib/l10n/app_en.arb` with every text of the modules of the app in English, and a file for each other language that the texts are in, with the translations;
- `lib/core/l10n/l10n.dart` with `context.l10n`, the `AppLocalizations` of a `BuildContext`.

The localization role adds `lib/core/l10n/app_locale.dart` with the languages of the app, and gives the root of the app its locale, its supported locales and the delegates of Flutter's own texts.

To add a text of your own, add it to `lib/l10n/app_en.arb`, and its translations to the files of the other languages:

```json
{
  "@@locale": "en",
  "cartTitle": "Your cart"
}
```

After `flutter pub get`, read it where a `BuildContext` below the root of the app is at hand:

```dart
import 'package:my_app/core/l10n/l10n.dart';

Text(context.l10n.cartTitle)
```

A text without a translation into a language reads in English there. The README of the app tells how to add a language: its ARB file needs `flutter gen-l10n`, since `flutter pub get` does not notice a new file.

Without `-m`, `smf create` asks which module provides the localization of the app.

The documentation has more on [the gen_l10n module](https://doc.saymyframe.com/modules/gen-l10n).
