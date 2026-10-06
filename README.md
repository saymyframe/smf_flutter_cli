[![pub package](https://img.shields.io/pub/v/smf_flutter_cli.svg)](https://pub.dev/packages/smf_flutter_cli)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=saymyframe_smf_flutter_cli&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=saymyframe_smf_flutter_cli)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=saymyframe_smf_flutter_cli&metric=coverage)](https://sonarcloud.io/component_measures?id=saymyframe_smf_flutter_cli&metric=coverage)
[![license](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Join us on Discord](https://img.shields.io/badge/Join%20us-Discord-5865F2?logo=discord&logoColor=white)](https://saymyframe.com/discord)

# SMF Flutter CLI

Say My Frame (SMF) generates Flutter apps from independent modules. You pick what the app needs, such as a router, tabs at the bottom, dependency injection, a state manager, Firebase or a start screen, and `smf create` generates a Flutter project in which these parts already work together. The project does not depend on SMF at run time, so its code is yours from the first commit.

![smf create in a terminal: it asks for the app name and the modules, adds go_router for the start screen and generates a Flutter app with bottom tabs, BLoC and get_it](https://doc.saymyframe.com/demo/smf_create.gif)

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
| [`flutter_core`](https://doc.saymyframe.com/modules/flutter-core) | The Flutter project for Android and iOS, `main()`, the start-up and the root widget. Every app has it. |
| [`go_router`](https://doc.saymyframe.com/modules/go-router) | Routes and a typed navigation facade, with go_router. |
| [`bottom_tabs`](https://doc.saymyframe.com/modules/bottom-tabs) | The main navigation as tabs in a bar at the bottom. |
| [`home`](https://doc.saymyframe.com/modules/home) | A start screen with the name of the app. |
| [`settings`](https://doc.saymyframe.com/modules/settings) | A settings screen with a row for each setting of the modules of the app and an About row. |
| [`onboarding`](https://doc.saymyframe.com/modules/onboarding) | An onboarding that a new user goes through on the first launch, before every other screen. |
| [`material_theme`](https://doc.saymyframe.com/modules/material-theme) | A light and a dark Material 3 theme from one seed colour, and the theme mode that the user selects, which the app remembers. |
| [`bloc`](https://doc.saymyframe.com/modules/bloc) | State management with flutter_bloc. |
| [`riverpod`](https://doc.saymyframe.com/modules/riverpod) | State management with flutter_riverpod. |
| [`gen_l10n`](https://doc.saymyframe.com/modules/gen-l10n) | Localization with gen-l10n of Flutter: the texts of the modules in ARB files, one for each language of the app. |
| [`get_it`](https://doc.saymyframe.com/modules/get-it) | Dependency injection: the services of the modules, registered in get_it. |
| [`event_bus`](https://doc.saymyframe.com/modules/event-bus) | Events between parts of the app that do not know each other, with event_bus. |
| [`shared_preferences`](https://doc.saymyframe.com/modules/shared-preferences) | The settings of the app that are no secret, such as the theme mode, remembered between its launches with shared_preferences. |
| [`firebase_core`](https://doc.saymyframe.com/modules/firebase-core) | Firebase, set up with `flutterfire configure` after generation. |
| [`firebase_crashlytics`](https://doc.saymyframe.com/modules/firebase-crashlytics) | Crash reporting with Firebase Crashlytics. |
| [`firebase_analytics`](https://doc.saymyframe.com/modules/firebase-analytics) | Analytics with Firebase Analytics and, with a router, a screen view for each screen the user sees. |

A module knows only the modules it depends on. A screen needs *a* router, not go_router, and analytics follows the screens of whichever router the app has. SMF calls these shared parts roles: a module that needs a role works with every module that provides it, and CI generates apps from many combinations of modules and checks each with `flutter analyze`. You can also write modules of your own; see [Extending SMF](https://doc.saymyframe.com/extending).

## Contributing

The repository is a Dart workspace managed with Melos, with a package for the module model (`smf_contracts`), the generation pipeline (`smf_pipeline`), each module and the CLI. [CONTRIBUTING.md](CONTRIBUTING.md) describes how to set it up and run its checks, and [AGENTS.md](AGENTS.md) describes its layout and rules.

## Support

- Discord: [saymyframe.com/discord](https://saymyframe.com/discord)
- Issues: [GitHub Issues](https://github.com/saymyframe/smf_flutter_cli/issues)
- Email: support@saymyframe.com

## License

Apache License 2.0; see [LICENSE](LICENSE). "Say My Frame" and "SMF Flutter CLI" are trademarks; see [TRADEMARKS.md](TRADEMARKS.md).
