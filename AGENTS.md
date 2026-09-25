# AGENTS.md

Guidance for AI coding agents working in this repository. Human contributors: see [CONTRIBUTING.md](CONTRIBUTING.md) and [README.md](README.md).

SMF (Say My Frame) is a Flutter CLI (`smf create`) that scaffolds apps from independent modules (routing, DI, Firebase, features, ...). It is a Dart pub workspace managed by Melos. Every package is versioned and published to pub.dev on its own.

## Lego rework in progress

The module model is being replaced step by step on the branch `feat/lego`. Until the branch is merged, two models live side by side:

- The new model is `package:smf_contracts/lego.dart`, with its code in `packages/smf_contracts/lib/src/lego/`. `lego_core.dart` is its core without concrete roles.
- In the new model, a module declares the roles it provides, requires or uses (router, DI, state management, ...) instead of depending on the modules that implement them. It puts code into typed sockets instead of patching files, and never learns which provider of a role was selected.
- `packages/smf_pipeline/` is the new generation pipeline of `smf create`. It imports only `lego_core.dart` and knows no concrete module or role; `test/architecture_test.dart` checks this. The CLI switches to it later in the rework.
- A file imports either `lego*.dart` or `smf_contracts.dart`, never both. Within `smf_contracts`, `test/lego/architecture_test.dart` checks this and keeps the core free of concrete roles; the other packages are checked as they move to the new model.
- A module package that has moved keeps its old module next to the new one until the CLI switches, because the CLI still uses it. `smf_flutter_core` is the first: `FlutterCoreModule` (brick `bricks/flutter_core`) provides the app entry, and `SmfFlutterCoreFactory` with the older bricks stays for the CLI. Its `test/architecture_test.dart` keeps the two apart.
- The rest of this file describes the old model, which the CLI still uses. `ModuleProfile`, the DSLs (`RouteGroup`, `DiDependencyGroup`), `MustacheSlots`, mustachex strings and brick hooks go away as their modules move to the new model.

## Layout

```
packages/
  smf_contracts/              # public API that modules implement (descriptors, DSLs, contributions)
  smf_modules/
    smf_contribution_engine/  # AST engine that patches Dart files (imports, statements, widgets)
    smf_<module>/             # first-party modules: go_router, get_it, firebase_*, event_bus, home, flutter_core
  smf_flutter_cli/            # the `smf` CLI: prompts, module selection, generation pipeline
tools/                        # bundle_bricks.dart, sync_cli_version.dart
```

Dependencies point one way only: `smf_contracts` ← modules ← `smf_flutter_cli`. Contracts never depend on modules or the CLI.

## The core principle: modules are independent

Module independence is the foundation of the project. Never break it, not even to fix a bug quickly.

- A module knows **only** the modules it lists in `ModuleDescriptor.dependsOn`, and only in one direction. For example, `firebase_analytics` depends on `firebase_core`, but `firebase_core` knows nothing about its dependents.
- A module never references another module's generated artifacts (classes, files, packages) unless it declares that dependency, and it should avoid needing to.
- Nothing is hardcoded for a particular combination. Any selection of modules and variants (e.g. state manager `bloc` / `riverpod`) must generate an app that compiles.
- Modules describe *what* they need through the DSLs in `smf_contracts`: routes (`RouteGroup`, `Route`, `NestedRoute`), DI (`DiDependencyGroup`), shared-file patches (contribution-engine `Contribution`s) and bricks. The router and DI modules turn those descriptions into code. A feature module must not assume a specific router or DI container.
- Generated UI talks only to its state-management layer (a Cubit via `context.read`, a Riverpod provider via `ref`), never directly to a DI container or infrastructure service.
- State-manager variants follow the existing pattern: the module factory picks a variant from `ModuleProfile.stateManager`, and each variant declares its own state-manager package (see `smf_home_flutter`, `smf_firebase_analytics`).

## Commands

Dart **3.12.2** is pinned in CI (`.github/workflows/build.yml`). The formatter output depends on the SDK version.

```bash
melos bootstrap             # resolve the workspace and re-bundle every brick
melos run format            # format lib/test/bin of every package
melos run analyze           # dart analyze --fatal-infos --fatal-warnings, every package
melos run analyze:hooks     # brick hooks are separate packages; pub get + analyze each
melos run test              # dart test in every package with a test/ dir
melos run check             # format:check + analyze + analyze:hooks + test
```

Run the CLI from source (the post-gen hook needs `flutter` on PATH):

```bash
cd packages/smf_flutter_cli
dart run bin/smf_flutter.dart create my_app -o /tmp/out --org com.example -m get_it,go_router,home -s bloc --on-conflict replace
```

## Generated files and templates

- **`lib/bundles/*_bundle.dart` are generated** from `bricks/` by `tools/bundle_bricks.dart`, which `melos bootstrap` runs. Never edit them by hand. Change the brick, re-bundle and commit the result. CI fails if a committed bundle differs from what the bricks produce.
- **`bricks/**/__brick__/**` holds mason templates, not Dart.** They are excluded from analysis and formatting. They use mason syntax: `{{app_name.snakeCase()}}`.
- **Dart-side template strings** in module code (e.g. `InsertImport`, `Import.core`) are rendered by mustachex and use `{{app_name_sc}}` (`_sc` = snake_case). `PatchEngine` renders only the text a contribution inserts, never the user's file.
- **Some template sections are DSL slots** (`MustacheSlots` in contracts, e.g. `{{#tabsWidget}}`, `{{#imports}}`). They are deliberately left unrendered by mason and filled later by the router/DI generators.
- **`bricks/*/hooks/` are standalone Dart packages** with their own pubspec.
- **Firebase modules** run the Firebase/FlutterFire CLIs in their hooks and need an interactive `firebase login`, so they can't be generated in non-interactive runs.

## Tests

- Tests live in each package's `test/`. Sonar counts coverage only within the package that runs the tests, so a module's code needs tests in that module.
- `packages/smf_flutter_cli/test/modules/module_contract_test.dart` checks every registered module for both state managers:
  - bundle hygiene (no machine-local files)
  - bricks render without stray mustache
  - imports resolve within the module's `dependsOn` closure
  - valid dependency constraints

  New modules must pass it.
- Generator tests check generated code for real: they parse it or type-check it with the analyzer, not just string-match.
- Tests are hermetic: no network, no Flutter SDK, temp dirs cleaned up.
- **A bug found but not fixed** gets a test for the *correct* behavior, marked `skip: 'Bug: <description>'`. Never write a test that locks buggy behavior in. The fix removes the `skip`.

## Git and PRs

- Use [Conventional Commits](https://www.conventionalcommits.org/) with the package's short name as scope: `fix(go_router): ...`, `feat(contracts): ...`, `test(cli): ...`, `chore(ci): ...`. `melos version` derives version bumps and CHANGELOGs from them.
- Name branches `fix/<topic>`, `feat/<topic>`, `chore/<topic>`, `docs/<topic>`, `test/<topic>`. PRs are squash-merged.
- Once a branch is pushed, add new commits on top. Don't force-push or rewrite pushed history unless a maintainer asks.
- Don't bump package versions or edit CHANGELOGs by hand. `melos version` does both, and its preCommit hook syncs `packages/smf_flutter_cli/lib/version.dart`.
- Keep PRs focused: one concern per PR, one logical change per commit.
