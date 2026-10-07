# SMF Flutter CLI

`smf` generates Flutter apps from independent modules. You pick what the app needs, such as a router, tabs at the bottom, dependency injection, a state manager, Firebase or a start screen, and `smf create` generates a Flutter project in which these parts already work together. The project does not depend on SMF at run time, so its code is yours from the first commit.

![smf create in a terminal: it asks for the app name and the modules, adds go_router for the start screen and generates a Flutter app with bottom tabs, BLoC and get_it](https://doc.saymyframe.com/demo/smf_create.gif)

With the modules `onboarding`, `home`, `settings`, `bottom_tabs`, `material_theme` and `gen_l10n`, the app opens on an onboarding and has a start screen, a settings screen with a theme mode and a language, and a light and a dark theme:

![The app that smf create generates, on a phone: the onboarding, the start screen, the settings screen, and the start screen in the dark theme and in Ukrainian](https://doc.saymyframe.com/demo/app_look.png)

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

The documentation is at [doc.saymyframe.com](https://doc.saymyframe.com).

## Install

```bash
dart pub global activate smf_flutter_cli
smf --version
```

`smf create` uses the Flutter SDK of the `flutter` on your `PATH`.

## Create an app

In a terminal, `smf create` asks for what the command line does not give: the name of the app, its organization and its modules:

```bash
smf create
```

With the modules on the command line and `--no-input`, it asks nothing:

```bash
smf create my_app --org com.example -m home,bottom_tabs,get_it,bloc --no-input
```

`smf create` adds the modules that the chosen ones need, such as `go_router` for the start screen of `home`. The main options:

| Option | What it does |
| --- | --- |
| `-m`, `--modules` | The modules, separated by commas. |
| `--org` | The organization in reverse domain notation, `com.example` by default. |
| `-o`, `--output` | The directory in which the app's directory is created. |
| `--no-input` | Ask nothing; everything comes from the options. |
| `--explain` | Print what would be generated and whether the machine is ready, then stop. |
| `--strict` | Stop instead of leaving out a module that cannot work in the app. |
| `--skip-external-setup` | Never install tools, log in or configure external services. |
| `--on-conflict` | What to do when the app's directory exists and is not empty: `prompt`, `replace`, `copy` or `cancel`. |
| `--start` | The full path of the screen the app starts on, such as `/home`. |
| `--locales` | The languages of the app among those that the texts of its modules are in, such as `en,uk`. All of them by default. |

`smf create` exits with 0 on success, 1 when generation failed, 64 for a wrong command line, 70 for an unexpected error and 130 when you cancel it. The [reference of `smf create`](https://doc.saymyframe.com/guides/smf-create) has the details.

## Modules

| Module | What it adds to the app |
| --- | --- |
| [`flutter_core`](https://doc.saymyframe.com/modules/flutter-core) | The Flutter project for Android and iOS, `main()`, the start-up, the root widget, and the screen that an app shows while it has no screen to start on. Every app has it. |
| [`go_router`](https://doc.saymyframe.com/modules/go-router) | Routes and a typed navigation facade, with go_router. |
| [`bottom_tabs`](https://doc.saymyframe.com/modules/bottom-tabs) | The main navigation as tabs in a bar at the bottom. |
| [`home`](https://doc.saymyframe.com/modules/home) | A start screen that welcomes the developer of the app, with the name of the app and the next steps. |
| [`settings`](https://doc.saymyframe.com/modules/settings) | A settings screen with the settings of the modules of the app in one group, a row for each. |
| [`onboarding`](https://doc.saymyframe.com/modules/onboarding) | An onboarding that a new user goes through on the first launch, before every other screen. |
| [`material_theme`](https://doc.saymyframe.com/modules/material-theme) | A light and a dark Material 3 theme with a palette and a bundled font, and the theme mode that the user selects, which the app remembers. |
| [`bloc`](https://doc.saymyframe.com/modules/bloc) | State management with flutter_bloc. |
| [`riverpod`](https://doc.saymyframe.com/modules/riverpod) | State management with flutter_riverpod. |
| [`gen_l10n`](https://doc.saymyframe.com/modules/gen-l10n) | Localization with gen-l10n of Flutter: the texts of the modules in ARB files, one for each language of the app. |
| [`get_it`](https://doc.saymyframe.com/modules/get-it) | Dependency injection: the services of the modules, registered in get_it. |
| [`event_bus`](https://doc.saymyframe.com/modules/event-bus) | Events between parts of the app that do not know each other, with event_bus. |
| [`shared_preferences`](https://doc.saymyframe.com/modules/shared-preferences) | The settings of the app that are no secret, such as the theme mode, remembered between its launches with shared_preferences. |
| [`firebase_core`](https://doc.saymyframe.com/modules/firebase-core) | Firebase, set up with `flutterfire configure` after generation. |
| [`firebase_crashlytics`](https://doc.saymyframe.com/modules/firebase-crashlytics) | Crash reporting with Firebase Crashlytics. |
| [`firebase_analytics`](https://doc.saymyframe.com/modules/firebase-analytics) | Analytics with Firebase Analytics and, with a router, a screen view for each screen the user sees. |

A module knows only the modules it depends on. A screen needs *a* router, not go_router, and analytics follows the screens of whichever router the app has. SMF calls these shared parts roles: a module that needs a role works with every module that provides it. You can also write modules of your own, and a command of your own with them; see [Extending SMF](https://doc.saymyframe.com/extending).

## Support

- Discord: [saymyframe.com/discord](https://saymyframe.com/discord)
- Issues: [GitHub Issues](https://github.com/saymyframe/smf_flutter_cli/issues)
- Email: support@saymyframe.com
