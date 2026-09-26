# Test fixtures of smf_pipeline

Fake modules for the tests of the generation pipeline. **They are not modules to use in an app.**

The real SMF modules do not yet use every feature of the module model in `package:smf_contracts/lego.dart`. These fake modules do, so each feature is tested on real code: [`fixture_registry`](../../fixture_registry/) runs the contract harness and the pipeline over them, together with the real `flutter_core` module that creates the app, the real `go_router`, which routes the fake features as well as `fake_router` does, the real `bottom_tabs`, around which `go_router` builds the tabs of their destinations (`fake_router` has no tabs), and the real `get_it`, which registers their services as well as `fake_di` does, and keeps snapshots of the apps they render in `fixture_registry/test/snapshots/`. A CI job generates these apps and analyzes them with Flutter.

| Package | What it has |
| --- | --- |
| `fake_state` | Two providers of the state management role. |
| `fake_roles` | Two roles defined outside `smf_contracts` with the same data type, one module that provides both, and a module that uses them under `when` and inside `{{#has_badge}}`. |
| `fake_di` | A DI container whose capabilities each test sets, which renders the registrations with the imports of their files as a variable of its render hook. |
| `fake_router` | A router with navigator observers and annotations on screens, which renders the screens with the imports of their files as a variable of its render hook. |
| `fake_feature` | A feature with a variant per state manager, a composition file and the navigation facade; a second feature whose start screen is a destination of the main navigation too, so an app with both has two screens that can start it. |
| `fake_infra` | Every socket of the app entry and the `flutter:` section of the pubspec; a second module with the same keys, so their values merge; analytics with navigator observers; crash reporting and events that start asynchronously; services with every DI capability; a module whose sockets a module that depends on it fills; code generation. |

## Rules

- Each fixture is a workspace package with `publish_to: none`, so melos bundles its bricks and analyzes it like any other package.
- A fixture follows the same rules as a real module, and the contract harness checks it like one.
- Fixtures are never part of the CLI's module registry or of a published package. The `.pubignore` of `smf_pipeline` leaves `test/fixtures/` and `fixture_registry/` out of its archive.
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
