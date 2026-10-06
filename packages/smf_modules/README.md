# smf_modules

The modules that the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) offers, each a package of its own on pub.dev:

| Package | Module (`-m`) |
| --- | --- |
| `smf_flutter_core` | `flutter_core`, the Flutter project that every app starts from |
| `smf_go_router` | `go_router`, routes and navigation with go_router |
| `smf_bottom_tabs` | `bottom_tabs`, tabs in a bar at the bottom |
| `smf_home_flutter` | `home`, a start screen |
| `smf_settings` | `settings`, a settings screen |
| `smf_onboarding` | `onboarding`, the onboarding of the first launch |
| `smf_material_theme` | `material_theme`, a light and a dark Material 3 theme |
| `smf_bloc`, `smf_riverpod` | `bloc` and `riverpod`, state management |
| `smf_gen_l10n` | `gen_l10n`, localization with gen-l10n of Flutter |
| `smf_get_it` | `get_it`, dependency injection |
| `smf_event_bus` | `event_bus`, events |
| `smf_shared_preferences` | `shared_preferences`, the settings that the app remembers |
| `smf_firebase_core` | `firebase_core`, Firebase |
| `smf_firebase_crashlytics` | `firebase_crashlytics`, crash reporting |
| `smf_firebase_analytics` | `firebase_analytics`, analytics |

`smf_contribution_engine` is not a module: it patches existing Dart files, and the modules do not use it.

`smf create` puts what the modules generate into an app, so you never add these packages to an app yourself. See the [modules](https://doc.saymyframe.com/modules) in the documentation.
