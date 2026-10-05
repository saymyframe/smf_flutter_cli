# smf_gen_l10n

The SMF module of localization with [gen-l10n](https://docs.flutter.dev/ui/internationalization), the generator of localizations in the Flutter SDK. It provides the localization role of SMF: the app shows its texts in the language of the device, among the languages that the texts are in, or in the one that the user chose.

The modules of the app give their texts to the localization role, each in English and in the other languages of the module. The role names a getter for each text, and code reads a text as `context.l10n.<getter>`. The role also lists the languages of the app in `lib/core/l10n/app_locale.dart`, and gives the root of the app its locale, its supported locales and the delegates of Flutter's own texts. This module writes the texts into ARB files in `lib/l10n`, one file for each language, and adds `l10n.yaml` and `generate: true` to the app, with which `flutter pub get` generates the `AppLocalizations` class. After you change the ARB files, `flutter gen-l10n` generates it again. A text without a translation into a language reads in English there.

The app remembers the language that the user chose in its preferences, so an app with this module needs a module that provides them. `smf create` adds `shared_preferences` by itself while it is the only module that provides the preferences, and asks otherwise. In an app with a settings screen, the role adds the setting of the language to that screen.

The app gets every language that a text of its modules is in, English first. `--locales` narrows them, as in `--locales en,uk`. An app can be only in a language in which Flutter has the texts of its own widgets, so SMF leaves any other language of a text out with a warning. Without a module that provides the localization, the modules show their texts in English.

## Use with the SMF CLI

`smf create` asks which module provides the localization of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m gen_l10n
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The gen_l10n module](https://doc.saymyframe.com/modules/gen-l10n)
