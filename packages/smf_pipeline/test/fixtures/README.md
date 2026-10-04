# Test fixtures of smf_pipeline

Fake modules for the tests of the generation pipeline. **They are not modules to use in an app.**

The real SMF modules do not yet use every feature of the module model in `package:smf_contracts/smf_contracts.dart`. These fake modules do, so each feature is tested on real code: [`fixture_registry`](../../fixture_registry/) runs the contract harness and the pipeline over them, together with real modules:

- `flutter_core`, which creates the app;
- `go_router`, which routes the fake features as well as `fake_router` does;
- `bottom_tabs`, around which both routers build the tabs of their destinations;
- `get_it`, which registers their services as well as `fake_di` does.

`fixture_registry` keeps snapshots of the apps they render in `fixture_registry/test/snapshots/`, and a CI job generates these apps and analyzes them with Flutter. Its registry of several providers puts the fixture providers of crash reporting and analytics next to the modules of the CLI that provide the same roles, with a fixture whose start-up waits for a timer, `get_it`, in which those roles register their services, and the fixture events, and the job runs the app tests of those modules, the tests of the DI role and of the events role, and the walk of the routes, in its app. There the tests of the two roles check, through a fixture that provides both and notes every call, that each call reaches every provider once, whatever the other providers do with it.

A test of a role that passes whatever the provider of the role does checks nothing. So `fake_broken` has providers of roles with one known bug each, and a CI job generates an app with each of them and runs there the app tests of the fixtures and of the app of several providers that apply to it: the tests of its role that the registry names for it must fail on the bug, each with its reason, and every other test must pass (`brokenProviders` in `fixture_registry/lib/broken_providers.dart`).

| Package | What it has |
| --- | --- |
| `fake_state` | Two providers of the state management role. |
| `fake_roles` | Two roles defined outside `smf_contracts` with the same data type; one module that provides both, whose render hook generates a file for each time zone that the modules ask the clock for; and a module that uses them under `when`, inside `{{#has_badge}}` and with a variable of its brick whose code depends on the presence of the clock (`RoleVar`). |
| `fake_di` | A DI container whose capabilities each test sets, which renders the registrations with the imports of their files as a variable of its render hook. |
| `fake_router` | A router with navigator observers, listeners of the screen, the main navigation of a layout and annotations on screens, which renders the screens with the imports of their files as a variable of its render hook. |
| `fake_feature` | A feature with a variant per state manager, a composition file and the navigation facade; a second feature whose start screen is a destination of the main navigation too, so an app with both has two screens that can start it, and whose other screen is outside the main navigation, so a router shows its page over it. |
| `fake_infra` | Every socket of the app entry, with a theme mode of the root of the app that reads an inherited widget among the root wrappers from the context of the root, and the `flutter:` section of the pubspec; a second module with the same keys, so their values merge; analytics with navigator observers, which note the routes they see, and a listener of the screen; a log of the screens, a second listener, which requires a router and has no routes, so an app with it alone starts on the fallback screen; analytics, crash reporting and events that start asynchronously, the first two through a platform channel of their own; preferences created with the app, which keep the settings in memory over a map that stands for the disk of a device and that each start of the app reads anew; a setting that works with the preferences when the app has them, whose two restorers note what they read and throw when a test says so, one an error and one an exception; a service log, which provides analytics and crash reporting created with the app, notes each call in lists that the tests of the two roles read, and misbehaves when a test says so: its factories throw, its services throw or fail, and its analytics changes the parameters that it gets; a start-up that waits for a timer, leaves one running and replaces the widget of the errors of a build; services with every DI capability, which note what the functions that dispose of them do; a module whose sockets a module that depends on it fills; code generation. |
| `fake_broken` | Providers of roles with one known bug each: `fake_router` with a change of the code it renders, which tells the listeners of the screen of the page on top each time it builds, calls them one after another so that one that throws silences the others, pushes a location in the main navigation over a page over it, creates its configuration anew each time it is read, or shows the screen of the first destination in the page of a route outside the main navigation; the fixture events with one whose `on<T>()` gives a listener the events of every type; the fixture preferences with one whose writes never reach its disk, one that never copies a list, neither the one it is given nor the one that a read returns, and one whose reads cast the value to the type they ask for; a layout whose `AppShell` gives only its first destination to the code that reads them; `fake_di` with one that registers a service only in a condition that is false when the app runs; the service log with one whose analytics notes each call twice; and the fixture crash reporting with one whose start sets the handler of the errors of Flutter to a report of its own. |

## Rules

- Each fixture is a workspace package with `publish_to: none`, so melos bundles its bricks and analyzes it like any other package.
- A fixture follows the same rules as a real module, and the contract harness checks it like one.
- Fixtures are never part of the CLI's module registry or of a published package. The `.pubignore` of `smf_pipeline` leaves `test/fixtures/` and `fixture_registry/` out of its archive.
- A provider with a known bug keeps every rule of its role that the contract harness checks, so that only a running app shows the bug, and has one bug only. It is in no registry of apps that must work, only in `brokenProviders`, with the smallest app that its tests need and the tests of its role that must fail on the bug, each with its reason. An app with a fixture provider of analytics or crash reporting has all of them, the service log too, since the tests of both roles apply to it and look at each. Every role whose contract the app tests check has one there, or an exemption with its reason (`brokenProviderExemptions`).
- A fixture whose start-up or services call a platform channel keeps the mocks of its platform side in its `app_tests/`, as `fake_infra` does for its crash reporting and analytics, and `fixture_registry` declares them where it registers the app tests of its matrix tools (`MatrixAppTest.mocks`, in `lib/matrix_app_tests.dart`): the matrix sets them up before the tests of every app with the fixture, whichever module the tests test.
- Never run `dart format` on a `bricks/` folder: it breaks templates that parse as Dart, such as `<String>[{{{labels}}}]`.

## Running the tests

```bash
cd packages/smf_pipeline/fixture_registry
dart test
```

When a change to the pipeline or the fixtures changes what the apps render, update the snapshots and review their diff:

```bash
SMF_UPDATE_SNAPSHOTS=1 dart test test/snapshot_test.dart
```
