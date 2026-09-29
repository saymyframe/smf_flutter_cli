# AGENTS.md

Guidance for AI coding agents working in this repository. Human contributors: see [CONTRIBUTING.md](CONTRIBUTING.md) and [README.md](README.md). The documentation for users and module authors is at [doc.saymyframe.com](https://doc.saymyframe.com).

SMF (Say My Frame) is a Flutter CLI (`smf create`) that generates apps from independent modules (routing, DI, Firebase, features, ...). It is a Dart pub workspace managed by Melos. Every package is versioned and published to pub.dev on its own.

## The module model

- A module declares the roles it provides, requires or uses (router, DI, state management, ...) instead of depending on the modules that implement them. It puts code into typed sockets instead of patching files, and never learns which provider of a role was selected. The model is `package:smf_contracts/smf_contracts.dart`; `package:smf_contracts/core.dart` is its core without concrete roles.
- `packages/smf_pipeline/` is the generation pipeline of `smf create`. It imports only `core.dart` and knows no concrete module or role; `test/architecture_test.dart` checks this.
- The CLI offers the modules listed in `packages/smf_flutter_cli/lib/src/modules.dart`:

  | Package | Module (`-m`) | What it is |
  | --- | --- | --- |
  | `smf_flutter_core` | `flutter_core` | Provides the app entry, which every app has exactly one of (`FlutterCoreModule`, brick `bricks/flutter_core`). |
  | `smf_go_router` | `go_router` | Provides the router role. |
  | `smf_bloc`, `smf_riverpod` | `bloc`, `riverpod` | Provide the state management role; an app has at most one. |
  | `smf_home_flutter` | `home` | The feature `home` (`HomeModule`), the start screen at `/home`; requires the router role. |
  | `smf_bottom_tabs` | `bottom_tabs` | Provides the layout role: tabs in a bar at the bottom for the destinations of the features, which the router builds its main navigation around. The layout requires the router role. |
  | `smf_get_it` | `get_it` | Provides the dependency injection (DI) role and registers in get_it the services that the modules of the app declare. |
  | `smf_event_bus` | `event_bus` | Provides the events role: a service on the event_bus package through which parts of the app that do not know each other exchange events. |
  | `smf_firebase_core` | `firebase_core` | Infrastructure without a role that sets up Firebase; a run in a terminal offers it among the modules of its kind. |
  | `smf_firebase_crashlytics` | `firebase_crashlytics` | Provides the crash reporting role with Firebase Crashlytics (an app can have several providers of it); depends on `smf_firebase_core`. |
  | `smf_firebase_analytics` | `firebase_analytics` | Provides the analytics role with Firebase Analytics (several providers too); depends on `smf_firebase_core` and logs each screen the user sees through a listener of the router. |

- Within `smf_contracts`, `test/architecture_test.dart` keeps the core free of concrete roles. A module package checks in its own `test/architecture_test.dart`, with `ModulePackage` of `package:smf_pipeline/testing.dart`, that its code uses only the module model and the modules it depends on, and what the package depends on. A module package other than `smf_flutter_core` renders the apps of its tests with `smf_flutter_core` as a dev dependency, for their app entry; its `lib/` imports no other module but those it depends on. Dev dependencies between module packages must not form a cycle, because pub.dev resolves them when it analyzes a package: `smf_flutter_core` has none on modules, and of two modules whose tests need each other's role, one tests with a provider of its own in `test/`. `tools/package_graph_test.dart` checks the packages of the workspace for a cycle.

## Layout

```
packages/
  smf_contracts/              # the module model: modules, roles, sockets, contributions
  smf_pipeline/               # the generation pipeline of `smf create` and the contract test harness
    fixture_registry/         # the apps of the fixtures: snapshots and their Flutter matrix
    test/fixtures/            # fake modules for the features of the model that no real module uses yet
  smf_modules/
    smf_contribution_engine/  # a standalone engine that patches Dart files; no module uses it
    smf_<module>/             # first-party modules: go_router, get_it, firebase_*, event_bus, home, flutter_core, bloc, riverpod, bottom_tabs
  smf_flutter_cli/            # the `smf` binary: the modules it offers, and the terminal, files and processes of the machine
tools/                        # bundle_bricks.dart, sync_cli_version.dart, banlist.dart and coverage_check.dart with their tests, package_graph_test.dart, app_tests_test.dart
```

Dependencies point one way only: `smf_contracts` ← `smf_pipeline` and modules ← `smf_flutter_cli`. Contracts never depend on modules, the pipeline or the CLI; the pipeline never depends on a module. Modules use `smf_pipeline` only in their tests, for the contract harness.

## The core principle: modules are independent

Module independence is the foundation of the project. Never break it, not even to fix a bug quickly.

- A module knows **only** the modules it lists in `ModuleDescriptor.dependsOn`, and only in one direction. For example, `firebase_analytics` depends on `firebase_core`, but `firebase_core` knows nothing about its dependents.
- A module never references another module's generated artifacts (classes, files, packages) unless it declares that dependency, and it should avoid needing to.
- Nothing is hardcoded for a particular combination. Any selection of modules and variants (e.g. state manager `bloc` / `riverpod`) must generate an app that compiles.
- Modules describe *what* they need through the DSLs in `smf_contracts`: routes (`RoutesData` of the router role), DI (`DiRegistration` of the DI role), code for sockets (`SocketContribution`s) and bricks. The router and DI modules turn those descriptions into code. A feature module must not assume a specific router or DI container.
- Generated UI talks only to its state-management layer (a Cubit via `context.read`, a Riverpod provider via `ref`), never directly to a DI container or infrastructure service.
- State-manager variants: a module whose code depends on the state manager declares `Variants` of the state management role in its descriptor, keyed by the id of each provider (`bloc`, `riverpod`), and each variant adds the package of its state manager with the constraint `any`, leaving the version to the provider (see the fixture `fake_feature` in `packages/smf_pipeline/test/fixtures/`).
- The package of a provider of a role, such as `flutter_riverpod` of `riverpod`, goes into another module only through its variant for the provider, with the constraint `any`, or through its `dependsOn` on the provider: the pipeline rejects any other module that adds it in an app with the provider. A module that imports or exports such a package adds it itself, even when it depends on the provider; a provider of a role may import, for a fragment, the package that a module which gives the role data adds.

## Commands

Dart 3.12.2 is pinned in CI (`.github/workflows/build.yml`). The formatter output depends on the SDK version.

```bash
melos bootstrap             # resolve the workspace and re-bundle every brick (needs the Mason CLI: dart pub global activate mason_cli)
melos run format            # format lib/test/bin/tool/app_tests/example of every package, and tools/
melos run analyze           # dart analyze --fatal-infos --fatal-warnings, every package and tools/
melos run banlist           # no file uses the names the module model replaced (tools/banlist.dart)
melos run test              # dart test in every package with a test/ dir, and in tools/
melos run check             # format:check + analyze + banlist + test
melos run test:coverage     # test, and write coverage/lcov.info in each package (needs dart pub global activate coverage)
melos run coverage:check    # after test:coverage: the tests cover every line and branch of lib/ (tools/coverage_check.dart)
```

CI has a job that runs these checks, with coverage for SonarCloud, and a job with Flutter for each of two registries, `Generated apps (real)` and `Generated apps (fixtures)`. They generate apps with `smf create --no-input --skip-external-setup --no-dart-fix --strict` and run `flutter analyze` on each: `packages/smf_flutter_cli/tool/matrix.dart` for the modules of the CLI and `packages/smf_pipeline/fixture_registry/tool/matrix.dart` for the fixture modules. Each takes a directory for the apps and needs `flutter` on the `PATH`. Then it copies into each app the tests that apply to it, from the `app_tests/` directories of the packages that each tool lists (`MatrixAppTest`), such as the start-up of Firebase with its platform side mocked, adds the dev dependencies of those tests with `flutter pub add dev:…`, and runs `flutter analyze` and `flutter test`: tests of what only a running app shows, which are not part of the generated apps. In the files of `app_tests/`, `{{app_name}}` becomes the name of the package of the app and `{{<key>}}` a value of `MatrixAppTest.values`; a placeholder that nothing fills fails the run. A dev dependency from the Flutter SDK takes its descriptor after `@`, as `flutter pub add` reads it: `integration_test@{sdk: flutter}`. With `--add-app-tests`, the directory of an app and the directories of some of its `MatrixAppTest`s, the matrix tool of the CLI adds those tests and their dev dependencies to an app that `smf create` generated outside the matrix, where only `{{app_name}}` is filled, and runs nothing else. The start check of `smf_flutter_core`, `app_tests/start/integration_test/start_check.dart`, is an entry of the app rather than a test: it runs `main()` of the app, waits for the first screen to settle and writes whether the app started and showed it without an error. The apps of the matrix only analyze it, and CI starts it on a device (see below). It applies to every app, so the matrix runs `flutter test` in each, with the tests that the modules put into the app. A new `MatrixAppTest` goes into the `tool/matrix.dart` of its registry with the apps it `appliesTo`, and one that applies to no app fails the run too. Each directory right in the `app_tests/` of a package is the directory of one `MatrixAppTest`. `tools/app_tests_test.dart` runs each matrix tool with `--app-tests`, which prints the directories of its `MatrixAppTest`s, and fails when no tool lists such a directory, when a file lies right in `app_tests/`, and when a tool lists a directory that does not exist or is not one of them. `app_tests/` stays out of the analysis of its package, of its published archive (`.pubignore`) and of SonarCloud, but `melos run format` formats it; give a `testWidgets` there an explicit `timeout`.

The matrix tools take the names of apps after the directory, such as `'every module (bloc)'`, and then check only those. In a directory whose path has letters beyond ASCII, where `flutter analyze` of Flutter 3.44 and 3.47 fails on every system, they analyze the apps with `dart analyze --fatal-infos` instead. The Flutter jobs run the matrices in a directory with a space in its name, then one app of each in a directory whose name has letters beyond ASCII too. `Generated apps (real)` also builds an app with every module for Android, with `flutter build apk --debug`. Then it starts an Android emulator, adds the start check to an app without Firebase with `--add-app-tests`, and starts the app there with `.github/scripts/start_app.sh`, which the macOS job runs on an iOS simulator too. The script builds a debug app with the check as its entry (`flutter build apk` or `flutter build ios --simulator`, with `-t`), installs it anew, launches it with `adb` or `xcrun simctl` and reads the line that the check writes to `smf_start_check` in the temporary directory of the app: `passed`, or `failed: ` and the problems. Nothing connects to the app. `flutter test`, which CI ran before, must reach the VM service of the app it installed, and on the emulators and simulators of CI it sometimes never did. So the script makes one try, and prints the log of the app and fails when the check fails, when the app stops before the check writes its result, as in a crash at start-up, and when no result comes in time. It does the same with an app with every module that `test/flutterfire_configure_test.dart` of `smf_firebase_core` configures first for Android: the test runs the `flutterfire configure` of the README of the app in the Firebase project of CI, `saymyframe-app-cli`, with the key of a service account of the project from the secret `FIREBASE_SERVICE_ACCOUNT`, since the placeholder of the options throws at start-up. The app has the organization `com.saymyframe.ci`, so flutterfire finds the Firebase apps that an earlier run registered, and the test fails when the project has more than one app with the id of the app. Without the secret, as in a pull request from a fork, the jobs start only the app without Firebase.

Two more jobs run on the macOS and Windows runners of GitHub, with the pinned Flutter, 3.44.2, from its release archive. Both run the tests of every package and of `tools/`; a test of something that only one system does is marked `@TestOn('mac-os')` or `testOn: 'windows'`. The macOS job generates an app without Firebase and one with every module in a directory whose name has a space and letters beyond ASCII, and builds both for the iOS simulator. A test of `smf_firebase_core` then archives the second app with `flutter build ipa --no-codesign`: it adds the build phase for Crashlytics with the Ruby gem xcodeproj, as `flutterfire configure` does on macOS, and fixes the phase with the command from the README of the app. The job then boots an iPhone simulator and starts there, with the start check, the app without Firebase and an app with every module of its own that the test of `smf_firebase_core` configures for iOS first, fixing the phase for Crashlytics with the command from the README of the app. The Windows job runs the matrix of the CLI for the apps with every module, and generates one more app as a user does, with the full `dart fix`, in a directory whose name has letters beyond ASCII. SMF generates the apps in `%TEMP%` and moves them to another drive. The job also finds the FlutterFire CLI through `dart.bat`. A job of its own runs the install script of the Firebase CLI on Windows for real.

The jobs with Flutter are in the reusable workflow `.github/workflows/apps.yml`, which takes the version of Flutter, the version of its Dart and the SHA-256 of its archive for each system. `build.yml` runs them with the pinned Flutter on every push and pull request. `nightly.yml` runs them every night, and when someone starts it by hand, with every stable release of Flutter that the generated apps allow. `packages/smf_flutter_cli/tool/flutter_versions.dart` finds those releases: it intersects the Flutter and Dart constraints of the apps of the matrix of the CLI, which the pipeline merges from the `PubspecContribution.environment`s of their modules, and takes the releases from the lists that Flutter publishes for Linux, macOS and Windows. The jobs on Linux run with each of them, and the jobs on macOS and Windows with the oldest and with the latest patch of each minor version. The nightly run skips the jobs without Flutter, and the comparison of the brick of `flutter_core` with `flutter create`, since the brick follows the template of the pinned Flutter. It also checks what users install: `Generated apps (real)` of each version activates `smf_flutter_cli` from pub.dev with `dart pub global activate`, which resolves its dependencies from pub.dev rather than from the workspace, generates with it an app with every module for each state manager, with the full `dart fix`, and runs `flutter analyze`, `flutter test` and `flutter build apk --debug` in each. A failure there affects the users of the published version, and its fix needs a release. What Gradle downloads for the Android builds goes into one cache for every version of Flutter, by the Gradle files of the brick of `flutter_core` and the week, since Maven Central answers 403 to a runner that downloads too much: every job restores the newest one, and the runs of pushes and pull requests save it, as does the job of the nightly run with the latest Flutter, so it gets new versions of plugins within a week even without pushes.

The job `CI` of `build.yml` sums up the other jobs of the workflow: it needs all of them and fails when one of them failed or was cancelled, while a skipped job counts as passed. The ruleset of main requires the checks `CI` and `PR title`, so the ruleset does not have to change when jobs come and go. A job added to `build.yml` goes into the `needs` of `CI` too. `tools/build_workflow_test.dart` fails when one is missing there, and when `CI` lacks `if: ${{ !cancelled() }}`, without which a failed job would skip `CI` and a ruleset would take the skipped check as passed.

Run the CLI from source. It finds the Flutter SDK through `flutter` on the `PATH` before it generates anything, and runs `flutter pub get`, `dart fix` and `dart format` in the new app:

```bash
cd packages/smf_flutter_cli
dart run bin/smf_flutter.dart create my_app -o /tmp/out --org com.example --no-input --on-conflict replace
```

Modules are chosen with `-m`, and every option of `create` comes from the command line with `--no-input`. `--explain` prints what would be generated and whether the machine is ready, without changing anything.

## Generated files and templates

- `lib/bundles/*_bundle.dart` are generated from `bricks/` by `tools/bundle_bricks.dart`, which `melos bootstrap` runs. Never edit them by hand. Change the brick, re-bundle and commit the result. CI fails if a committed bundle differs from what the bricks produce.
- `bricks/**/__brick__/**` holds mason templates, not Dart. They are excluded from analysis and formatting. They use mason syntax: `{{app_name.snakeCase()}}`.
- Bricks have no mason hooks. The pipeline rejects a brick with hooks and runs none: modules check the machine and run tools through `Preflight` and `PostGenStep` contributions.
- The snapshots in `packages/smf_flutter_cli/test/snapshots/` and `packages/smf_pipeline/fixture_registry/test/snapshots/` hold the files of the apps the CLI and the fixtures render. When a change alters them, update them with `SMF_UPDATE_SNAPSHOTS=1 dart test test/snapshot_test.dart` in the package and review the diff.
- `smf_firebase_core` generates `lib/firebase_options.dart` as a placeholder in the form that `flutterfire configure` writes, which throws an `UnsupportedError` until the FlutterFire CLI fills it in, and initializes Firebase with it in `bootstrap()`. Its preflight checks look for the Firebase CLI, a Firebase login, the FlutterFire CLI and, on macOS, the Ruby gem xcodeproj; elsewhere a check tells that the Xcode project is set up on a Mac. They only warn: a run in a terminal offers to set up what it can, asking first. After generation it runs `flutterfire configure` in the terminal with the ids of the app; that needs a Firebase account, so a run with `--no-input` or `--skip-external-setup` generates the app with the placeholder and prints the command to run later. A follow-up of that step (`PostGenStep.followUps`), which runs only after it and only on macOS, points the build phase for Crashlytics that flutterfire adds at the upload script in `build/ios/SourcePackages`, which `flutter build ipa` needs.

## Tests

- Tests live in each package's `test/`. Sonar counts coverage only within the package that runs the tests, so a module's code needs tests in that module.
- Keep coverage at 100% of the lines and branches of `lib/` with tests that pin behavior someone relies on, never with tests that only touch a line. Remove code that cannot run instead of covering it. Code that no automated test can run, such as the terminal of a user, goes between `// coverage:ignore-start` and `// coverage:ignore-end`, with the reason in a comment next to it. Don't use `coverage:ignore-file`: the file then drops out of `lcov.info` and Sonar counts all of it as uncovered. `melos run test:coverage` measures branches as well as lines, and `melos run coverage:check` after it fails on any line or branch of `lib/` that the tests do not cover, with its `path:line`. CI runs both.
- The contract harness of `package:smf_pipeline/testing.dart` checks a module against the rules of the roles it declares and renders every app it can be part of. `packages/smf_flutter_cli/test/modules_test.dart` runs it over every module the CLI offers, and a module package runs it over itself in its own tests. New modules must pass it.
- For each package of a provider of a role that a module adds, the harness builds a case of the module with that provider, `<module> with <provider>` or `<module> (<provider of its variant>) with <provider>`, when they can be in one app. So the registry of a module's tests holds the providers of the roles it requires or uses, the providers it has variants for, and the providers whose packages it adds.
- Generator tests check generated code for real: they parse it or type-check it with the analyzer, not just string-match.
- Tests are hermetic: no network, no Flutter SDK, temp dirs cleaned up. The few that need more skip themselves unless CI provides it: an app from `flutter create` (`SMF_FLUTTER_CREATE_APP`), an app with Crashlytics to archive on macOS (`SMF_CRASHLYTICS_APP`), an app with Firebase to configure with flutterfire for a platform in a Firebase project, with the key of a service account of the project (`SMF_FIREBASE_APP`, `SMF_FIREBASE_PLATFORM`, `SMF_FIREBASE_PROJECT`, `SMF_FIREBASE_SERVICE_ACCOUNT`), or a machine where the Firebase CLI may be installed (`SMF_INSTALL_FIREBASE_CLI=1`).
- A bug found but not fixed gets a test for the *correct* behavior, marked `skip: 'Bug: <description>'`. Never write a test that locks buggy behavior in. The fix removes the `skip`.

## Git and PRs

- Use [Conventional Commits](https://www.conventionalcommits.org/) with the package's short name as scope: `fix(go_router): ...`, `feat(contracts): ...`, `test(cli): ...`, `chore(ci): ...`. `melos version` derives version bumps and CHANGELOGs from them.
- Name branches `fix/<topic>`, `feat/<topic>`, `chore/<topic>`, `docs/<topic>`, `test/<topic>`. PRs are squash-merged.
- The squash commit on main takes the title of the PR as its only line, so the title must be a Conventional Commit too, and CI checks it (`.github/workflows/pr-title.yml`). A breaking change needs `!` in the title, such as `feat(contracts)!: ...`: a `BREAKING CHANGE:` footer in a commit of the branch does not reach main.
- Once a branch is pushed, add new commits on top. Don't force-push or rewrite pushed history unless a maintainer asks.
- Don't bump package versions or edit CHANGELOGs by hand. `melos version` does both, and its preCommit hook syncs `packages/smf_flutter_cli/lib/version.dart`.
- Keep PRs focused: one concern per PR, one logical change per commit.
