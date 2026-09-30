# Test fixtures of smf_pipeline

Fake modules for the tests of the generation pipeline. **They are not modules to use in an app.**

The real SMF modules do not yet use every feature of the module model in `package:smf_contracts/smf_contracts.dart`. These fake modules do, so each feature is tested on real code: [`fixture_registry`](../../fixture_registry/) runs the contract harness and the pipeline over them, together with real modules:

- `flutter_core`, which creates the app;
- `go_router`, which routes the fake features as well as `fake_router` does;
- `bottom_tabs`, around which both routers build the tabs of their destinations;
- `get_it`, which registers their services as well as `fake_di` does.

`fixture_registry` keeps snapshots of the apps they render in `fixture_registry/test/snapshots/`, and a CI job generates these apps and analyzes them with Flutter. Its registry of several providers puts the fixture providers of crash reporting and analytics next to the modules of the CLI that provide the same roles, with a fixture whose start-up waits for a timer, and the job runs the app tests of those modules in its app. There the tests of the two roles check, through a fixture that provides both and notes every call, that each call reaches every provider once, whatever the other providers do with it.

| Package | What it has |
| --- | --- |
| `fake_state` | Two providers of the state management role. |
| `fake_roles` | Two roles defined outside `smf_contracts` with the same data type, one module that provides both, and a module that uses them under `when` and inside `{{#has_badge}}`. |
| `fake_di` | A DI container whose capabilities each test sets, which renders the registrations with the imports of their files as a variable of its render hook. |
| `fake_router` | A router with navigator observers, listeners of the screen, the main navigation of a layout and annotations on screens, which renders the screens with the imports of their files as a variable of its render hook. |
| `fake_feature` | A feature with a variant per state manager, a composition file and the navigation facade; a second feature whose start screen is a destination of the main navigation too, so an app with both has two screens that can start it. |
| `fake_infra` | Every socket of the app entry and the `flutter:` section of the pubspec; a second module with the same keys, so their values merge; analytics with navigator observers, which note the routes they see, and a listener of the screen; a log of the screens, a second listener, which requires a router and has no routes, so an app with it alone starts on the fallback screen; analytics, crash reporting and events that start asynchronously, the first two through a platform channel of their own; a service log, which provides analytics and crash reporting created with the app, notes each call in lists that the tests of the two roles read, and throws or fails when a test says so; a start-up that waits for a timer, leaves one running and replaces the widget of the errors of a build; services with every DI capability; a module whose sockets a module that depends on it fills; code generation. |

## Rules

- Each fixture is a workspace package with `publish_to: none`, so melos bundles its bricks and analyzes it like any other package.
- A fixture follows the same rules as a real module, and the contract harness checks it like one.
- Fixtures are never part of the CLI's module registry or of a published package. The `.pubignore` of `smf_pipeline` leaves `test/fixtures/` and `fixture_registry/` out of its archive.
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
