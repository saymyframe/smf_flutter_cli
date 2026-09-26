# AGENTS.md

Guidance for AI coding agents working in this repository. Human contributors: see [CONTRIBUTING.md](CONTRIBUTING.md) and [README.md](README.md).

SMF (Say My Frame) is a Flutter CLI (`smf create`) that scaffolds apps from independent modules (routing, DI, Firebase, features, ...). It is a Dart pub workspace managed by Melos. Every package is versioned and published to pub.dev on its own.

## Lego rework in progress

The module model is being replaced step by step on the branch `feat/lego`. Until the branch is merged, two models live side by side:

- The new model is `package:smf_contracts/lego.dart`, with its code in `packages/smf_contracts/lib/src/lego/`. `lego_core.dart` is its core without concrete roles.
- In the new model, a module declares the roles it provides, requires or uses (router, DI, state management, ...) instead of depending on the modules that implement them. It puts code into typed sockets instead of patching files, and never learns which provider of a role was selected.
- `packages/smf_pipeline/` is the generation pipeline of `smf create`. It imports only `lego_core.dart` and knows no concrete module or role; `test/architecture_test.dart` checks this.
- `smf create` runs on the new pipeline. The CLI offers only the modules that have moved to the new model, listed in `packages/smf_flutter_cli/lib/src/modules.dart`: so far `smf_flutter_core`, whose `FlutterCoreModule` (brick `bricks/flutter_core`) provides the app entry, `smf_go_router`, which provides the router role (`-m go_router`), `smf_bloc` and `smf_riverpod`, which provide the state management role (`-m bloc` or `-m riverpod`; an app has at most one), `smf_home_flutter`, whose `HomeModule` is the feature `home`, the start screen of the app at `/home` (`-m home`), which requires the router role, `smf_bottom_tabs`, which provides the layout role (`-m bottom_tabs`; tabs in a bar at the bottom for the destinations of the features, which the router builds its main navigation around; the layout requires the router role), `smf_get_it`, which provides the DI role (`-m get_it`) and registers in get_it the services that the modules of the app declare, and `smf_event_bus`, which provides the events role (`-m event_bus`): a service on the event_bus package through which parts of the app that do not know each other exchange events. The other module packages still use the old model, which the rest of this file describes, and the CLI does not offer them until they move. Their own tests keep running.
- A file imports either `lego*.dart` or `smf_contracts.dart`, never both. Within `smf_contracts`, `test/lego/architecture_test.dart` checks this and keeps the core free of concrete roles; a module package that has moved checks it in its own `test/architecture_test.dart`, with `ModulePackage` of `package:smf_pipeline/testing.dart`, which also checks what the package depends on. A module package other than `smf_flutter_core` renders the apps of its tests with `smf_flutter_core` as a dev dependency, for their app entry; its `lib/` imports no other module but those it depends on. Dev dependencies between module packages must not form a cycle, because pub.dev resolves them when it analyzes a package: `smf_flutter_core` has none on modules, and of two modules whose tests need each other's role, one tests with a provider of its own in `test/`. `tools/package_graph_test.dart` checks the packages of the workspace for a cycle.
- `ModuleProfile`, the DSLs (`RouteGroup`, `DiDependencyGroup`), `MustacheSlots` and mustachex strings go away as their modules move to the new model.

## Layout

```
packages/
  smf_contracts/              # public API that modules implement (descriptors, DSLs, contributions)
  smf_pipeline/               # the generation pipeline of `smf create` and the contract test harness
  smf_modules/
    smf_contribution_engine/  # AST engine that patches Dart files (imports, statements, widgets)
    smf_<module>/             # first-party modules: go_router, get_it, firebase_*, event_bus, home, flutter_core, bloc, riverpod, bottom_tabs
  smf_flutter_cli/            # the `smf` binary: the modules it offers, and the terminal, files and processes of the machine
tools/                        # bundle_bricks.dart, sync_cli_version.dart, banlist.dart
```

Dependencies point one way only: `smf_contracts` ← `smf_pipeline` and modules ← `smf_flutter_cli`. Contracts never depend on modules, the pipeline or the CLI; the pipeline never depends on a module. Modules use `smf_pipeline` only in their tests, for the contract harness.

## The core principle: modules are independent

Module independence is the foundation of the project. Never break it, not even to fix a bug quickly.

- A module knows **only** the modules it lists in `ModuleDescriptor.dependsOn`, and only in one direction. For example, `firebase_analytics` depends on `firebase_core`, but `firebase_core` knows nothing about its dependents.
- A module never references another module's generated artifacts (classes, files, packages) unless it declares that dependency, and it should avoid needing to.
- Nothing is hardcoded for a particular combination. Any selection of modules and variants (e.g. state manager `bloc` / `riverpod`) must generate an app that compiles.
- Modules describe *what* they need through the DSLs in `smf_contracts`: routes (`RoutesData` of the router role), DI (`DiRegistration` of the DI role), shared-file patches (contribution-engine `Contribution`s) and bricks. The router and DI modules turn those descriptions into code. A feature module must not assume a specific router or DI container.
- Generated UI talks only to its state-management layer (a Cubit via `context.read`, a Riverpod provider via `ref`), never directly to a DI container or infrastructure service.
- State-manager variants follow the existing pattern: the module factory picks a variant from `ModuleProfile.stateManager`, and each variant declares its own state-manager package (see `smf_firebase_analytics`).

## Commands

Dart **3.12.2** is pinned in CI (`.github/workflows/build.yml`). The formatter output depends on the SDK version.

```bash
melos bootstrap             # resolve the workspace and re-bundle every brick
melos run format            # format lib/test/bin/tool of every package, and tools/
melos run analyze           # dart analyze --fatal-infos --fatal-warnings, every package and tools/
melos run banlist           # no file uses the names the module model replaced (tools/banlist.dart)
melos run test              # dart test in every package with a test/ dir, and in tools/
melos run check             # format:check + analyze + banlist + test
```

A second CI job generates apps with Flutter and runs `flutter analyze` on each: `packages/smf_flutter_cli/tool/matrix.dart` for the modules of the CLI and `packages/smf_pipeline/fixture_registry/tool/matrix.dart` for the fixture modules. Each takes a directory for the apps and needs `flutter` on the `PATH`.

Run the CLI from source. It finds the Flutter SDK through `flutter` on the `PATH` before it generates anything, and runs `flutter pub get`, `dart fix` and `dart format` in the new app:

```bash
cd packages/smf_flutter_cli
dart run bin/smf_flutter.dart create my_app -o /tmp/out --org com.example --no-input --on-conflict replace
```

Modules are chosen with `-m`, and every option of `create` comes from the command line with `--no-input`. `--explain` prints what would be generated and whether the machine is ready, without changing anything.

## Generated files and templates

- **`lib/bundles/*_bundle.dart` are generated** from `bricks/` by `tools/bundle_bricks.dart`, which `melos bootstrap` runs. Never edit them by hand. Change the brick, re-bundle and commit the result. CI fails if a committed bundle differs from what the bricks produce.
- **`bricks/**/__brick__/**` holds mason templates, not Dart.** They are excluded from analysis and formatting. They use mason syntax: `{{app_name.snakeCase()}}`.
- **Dart-side template strings** in module code (e.g. `InsertImport`, `Import.core`) are rendered by mustachex and use `{{app_name_sc}}` (`_sc` = snake_case). `PatchEngine` renders only the text a contribution inserts, never the user's file.
- **Bricks have no mason hooks.** The pipeline rejects a brick with hooks and runs none: modules check the machine and run tools through `Preflight` and `PostGenStep` contributions.
- **Firebase:** `smf_firebase_core` generates `lib/firebase_options.dart` as a placeholder in the form that `flutterfire configure` writes, which throws an `UnsupportedError` until the FlutterFire CLI fills it in, and initializes Firebase with it in `bootstrap()`.

## Tests

- Tests live in each package's `test/`. Sonar counts coverage only within the package that runs the tests, so a module's code needs tests in that module.
- The contract harness of `package:smf_pipeline/testing.dart` checks a module against the rules of the roles it declares and renders every app it can be part of. `packages/smf_flutter_cli/test/modules_test.dart` runs it over every module the CLI offers, and a module package runs it over itself in its own tests. New modules must pass it.
- Generator tests check generated code for real: they parse it or type-check it with the analyzer, not just string-match.
- Tests are hermetic: no network, no Flutter SDK, temp dirs cleaned up.
- **A bug found but not fixed** gets a test for the *correct* behavior, marked `skip: 'Bug: <description>'`. Never write a test that locks buggy behavior in. The fix removes the `skip`.

## Git and PRs

- Use [Conventional Commits](https://www.conventionalcommits.org/) with the package's short name as scope: `fix(go_router): ...`, `feat(contracts): ...`, `test(cli): ...`, `chore(ci): ...`. `melos version` derives version bumps and CHANGELOGs from them.
- Name branches `fix/<topic>`, `feat/<topic>`, `chore/<topic>`, `docs/<topic>`, `test/<topic>`. PRs are squash-merged.
- Once a branch is pushed, add new commits on top. Don't force-push or rewrite pushed history unless a maintainer asks.
- Don't bump package versions or edit CHANGELOGs by hand. `melos version` does both, and its preCommit hook syncs `packages/smf_flutter_cli/lib/version.dart`.
- Keep PRs focused: one concern per PR, one logical change per commit.
