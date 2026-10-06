# Contributing to SMF Flutter CLI

Thank you for your interest in contributing to SMF Flutter CLI! This document provides guidelines and information for contributors.

## Code of conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How can I contribute?

### Reporting bugs

- Use the GitHub issue tracker
- Include detailed steps to reproduce the bug
- Provide your environment details (OS, Flutter version, etc.)
- Include error messages and stack traces

### Suggesting enhancements

- Use the GitHub issue tracker with the "enhancement" label
- Describe the feature and its benefits
- Provide use cases and examples

### Submitting code changes

1. Fork the repository
2. Create a branch named after the change type (`git checkout -b feat/amazing-feature`, or `fix/...`, `docs/...`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all checks pass (`melos run check`)
6. Commit using [Conventional Commits](https://www.conventionalcommits.org/) (`git commit -m 'feat(go_router): add amazing feature'`)
7. Push to the branch (`git push origin feat/amazing-feature`)
8. Open a Pull Request with a Conventional Commit as its title. It is squash-merged, and the commit takes the title as its only line, so CI checks it. Mark a breaking change with `!` in the title (`feat(contracts)!: ...`).

## Development setup

CI pins Dart 3.12.2, and the output of the formatter depends on its version, so develop with that Dart, which Flutter 3.44.2 comes with.

1. Clone the repository
2. Install Melos and the Mason CLI: `dart pub global activate melos` and `dart pub global activate mason_cli`
3. Install dependencies and bundle bricks: `melos bootstrap`
4. Run all checks: `melos run check` (format, analyze, banlist, tests)

The bundles in `lib/bundles/` are generated from the bricks, so change the brick, run `melos bootstrap` and commit both. When a change alters what an app renders, update the snapshots of the CLI or of the fixtures with `SMF_UPDATE_SNAPSHOTS=1 dart test test/snapshot_test.dart` in the package, and review their diff.

CI also runs the tests with coverage, and fails when they do not cover a line or a branch of `lib/`. To check it locally, install the coverage tool with `dart pub global activate coverage`, then run `melos run test:coverage` and `melos run coverage:check`, which names each line and branch that no test reaches. Code that no test can run goes between `// coverage:ignore-start` and `// coverage:ignore-end`, with the reason in a comment.

Besides these checks, CI generates apps with Flutter and runs `flutter analyze` on each, then `flutter test` with the tests that packages keep for the apps in `app_tests/`, which `packages/smf_flutter_cli/lib/matrix_app_tests.dart` and `packages/smf_pipeline/fixture_registry/lib/matrix_app_tests.dart` register. To run it locally, with `flutter` on the `PATH`:

```bash
dart run packages/smf_flutter_cli/tool/matrix.dart /tmp/smf_apps
dart run packages/smf_pipeline/fixture_registry/tool/matrix.dart /tmp/smf_fixture_apps
dart run packages/smf_pipeline/fixture_registry/tool/several_providers_matrix.dart /tmp/smf_several_providers
dart run packages/smf_pipeline/fixture_registry/tool/broken_providers_matrix.dart /tmp/smf_broken_providers
```

To check only some apps of the matrix, name them after the directory, such as `'go_router with layout'`. The apps with every module grow with the product of the numbers of providers of the roles that take one: there is one for each combination, such as one for each state manager. So the tools take a pairwise covering of them, in which every pair of providers of two roles is in one of the apps. `--combinations 3-wise` or `--combinations all` before the directory takes more. With `--every-module` before the directory, the tools check only the apps with every module, and with `--app` and the name of one as well, such as `--every-module --app 'every module (riverpod)'`, only that one. `--shard 1/2` before the directory checks only the first of two shares of the apps. The third command runs the app tests of the CLI and of its modules in one app, next to other providers of the roles of those modules and a start-up that waits for a timer, so that they pass whatever else an app has. It takes no names of apps. In that app, the tests of the analytics role and of the crash reporting role also check that each call reaches every provider of the role once, whatever the other providers do with it. The fourth command checks the tests themselves, since a test of a role that passes whatever the provider of the role does checks nothing. It generates a small app for each fixture provider of a role with one known bug (`brokenProviders()` in `packages/smf_pipeline/fixture_registry/lib/broken_providers.dart`) and runs there the app tests that apply to it: the tests of the role that the registry names must fail on the bug, with the reason it gives for each, and every other test must pass. It does the same for the apps of `brokenModuleApps()`, whose tests must fail for what a module does: the walk of the routes must fail on a guard that nothing opens for the tests. CI runs it in a job of its own, Generated apps (broken providers). Each role whose contract the app tests check needs such a provider, or an exemption with its reason, and a test of the fixture registry fails otherwise. A module whose start-up or services call a platform channel keeps the mocks of its platform side with its app tests and declares them (`MatrixAppTest.mocks`). The matrix sets them up before the tests of every module of an app with the module. A module with a guard of the routes opens the guard in those mocks, so that the tests of the other modules see the screens of the app; the walk of the routes fails on a guard that does not allow, by its name. In a directory whose path has letters beyond ASCII, the matrix analyzes the apps with `dart analyze`, as `flutter analyze` of Flutter 3.44 and 3.47 fails there.

CI also runs the tests on macOS and Windows, and on all three systems it generates apps in directories whose names have a space and letters beyond ASCII. A job named Plan runs the matrix tools with `--plan`, which print the plan of the jobs that check, build and start the apps as JSON. Each of those jobs takes one shard or one app of the plan:

- the shards of the matrices;
- a pairwise covering of the apps with every module, which CI builds for Android on Linux and for the iOS simulator on macOS, and checks on Windows;
- a pairwise covering of those without the modules whose steps need an external service, which it starts on devices;
- the app with every module of each provider of the app entry, which it archives with Crashlytics on macOS and configures with Firebase to start it.

A job on Windows also runs the install script of the Firebase CLI. The workflows name neither the modules nor the apps of these jobs: the matrix tool of the CLI generates each app with `--create --app`, named after the providers of the roles that take one other than the first of each, such as `android_app` and `android_app_riverpod`. So the jobs of a new provider of a role, such as a second app entry, which owns the Android and Xcode projects, come from the plan rather than from a change of CI. `tools/workflow_apps_test.dart` fails when a workflow selects an app of a matrix tool by a name it writes, names the modules of an app with `-m`, refers to the package of a module outside a step that runs its tests or a tool of it with `dart run`, but for the exceptions it lists with their reasons, checks a whole selection of apps in one job rather than its app or shard of the plan, or adds the tests of the matrix to an app without `--app`, which names the app of the plan that the job generated. Every night, CI runs the jobs with Flutter on each stable release that the generated apps allow instead of the pinned one: the jobs on Linux on all of them, and those on macOS and Windows on the oldest and on the latest patch of each minor version. So a release of Flutter that breaks the generated apps shows up before users run into it. With the latest release, the jobs of the matrices check every combination of the providers, or a 3-wise covering of more than 100, and the job of the broken providers runs only with that release. The nightly run also installs `smf_flutter_cli` from pub.dev, as a user does, and on each of those releases generates with it the apps with every module of that release, analyzes and tests them and builds them for Android. A failure there affects the users of the published version, and its fix needs a release.

CI also starts apps on an Android emulator and on an iOS simulator, with a check as the entry of the app, which writes whether the app started and showed its first screen. The CLI keeps it in `app_tests/start`: it knows no module, only `main()` in `lib/main.dart`, which every app has whichever module provides its entry. Once the first screen settled, the check also runs the probes of the tests of the app, for at most a minute in all, and fails on the problems they find: the walk of the routes goes to the locations that need no values, and expects the target of a guard of the routes in place of each location that the guard keeps the user from; the probe of the DI role resolves each service of the app without calling it; the probe of the preferences role saves values under keys of its own, reads them back and removes them; the probe of `shared_preferences` opens the preferences again and reads back what it saved, as the platform returns it; and the probe of `onboarding` finishes the onboarding that a first launch shows, and checks that the app saved that and left the screen of the onboarding. A probe depends on no other: it holds whichever probes ran before it. A test declares its probe in `MatrixAppTest.startProbe`, and the matrix tool lists the probes of the tests that it adds to an app in `integration_test/start_probes.dart`. CI starts a pairwise covering of the apps with every module but the modules whose steps need an external service, such as Firebase, and the app with every module of each provider of the app entry, which it configures with `flutterfire configure` in a Firebase project of its own. Only the runs of the Build workflow register a new app in that project, such as the app of a new provider of the app entry in the run of its pull request into main. CI activates the version of the FlutterFire CLI that `smf_firebase_core` activates on the machine of a user, which `packages/smf_modules/smf_firebase_core/tool/flutterfire_version.dart` prints, and `tools/flutterfire_version_test.dart` fails when a workflow or a script of CI writes a version of the FlutterFire CLI of its own, or activates the CLI without a version. `.github/scripts/start_app.sh` builds an app with the check, installs and launches it with `adb` or `xcrun simctl`, and waits for the result. To generate the apps that CI starts without Firebase, each in a directory of its own in `/tmp/smf_start`, run `dart run packages/smf_flutter_cli/tool/matrix.dart --create --without-external-steps /tmp/smf_start start_app`. To start one of them with the check, on a running Android emulator or device, or on a booted iOS simulator:

```bash
dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests --without-external-steps --app 'every module (bloc)' /tmp/smf_start/start_app packages/smf_flutter_cli/app_tests/start
cd /tmp/smf_start/start_app
<repository>/.github/scripts/start_app.sh android <device> 240   # such as emulator-5554
<repository>/.github/scripts/start_app.sh ios <UDID of the simulator> 240
```

`--app` names the app with every module that the app was generated as, such as `'every module (riverpod)'` for `start_app_riverpod`, and `--without-external-steps` goes with it when `--create` had it. The tool then adds the tests of that app that have a probe, with the files that they read, and their dev dependencies with `flutter pub add`. To start an app of yours that `smf create` generated, leave both out, and the check runs no probe. The last argument of the script is how many seconds the app has to start once it is built. The build itself has no limit, as it can take minutes longer on a busy machine. The script finds the Android SDK through `ANDROID_HOME`, or where Android Studio installs it. `flutter run -d <device> -t integration_test/start_check.dart` runs the check too, and prints `SMF_START_CHECK: passed`, or `SMF_START_CHECK: failed: ` and the problems. An app with Firebase starts only once `flutterfire configure` configured it, as its README says.

The jobs with Flutter are many, mostly one for each app or shard of the plan, those on macOS among them, and take about half an hour, so only pushes to main and pull requests into main run them. A pull request into another branch, such as one that collects the pull requests of a larger change, gets the job of the checks and the check of its title. The jobs with Flutter run once that branch goes into main through a pull request of its own, which is merged with a merge commit, so that the squash commit of each of its pull requests reaches main as it is. To run every job on a branch before that, use Run workflow on the Build workflow in the Actions tab. A new run of Build cancels the run of the same pull request that is still in progress, and the run of a pull request stops once it is merged or closed.

The job `CI` sums up the jobs of `.github/workflows/build.yml`: it fails when any of them failed or was cancelled, and when one was skipped in a run that runs every job. The ruleset of main requires the checks `CI` and `PR title` before a pull request can be merged. A new job in `build.yml` goes into the `needs` of `CI`, and a test in `tools/` fails when it does not.

The repository layout, the module-independence rules and the conventions for generated files and tests are described in [AGENTS.md](AGENTS.md). It is written for AI coding agents but is just as useful for people. The documentation of SMF, with a guide to writing modules, is at [doc.saymyframe.com](https://doc.saymyframe.com).

## Code style

- Follow the Dart style guide; CI checks formatting with Dart 3.12.2
- `very_good_analysis` is enabled in every package
- Use Conventional Commits with the package as scope (`fix(contracts): ...`); versions and changelogs are generated from them
- Add tests for new functionality

## Copyright and licensing

By contributing to this project, you agree that your contributions will be licensed under the Apache License, Version 2.0.

When submitting code, please ensure you have the right to license your contributions under the Apache License.

## Questions?

If you have questions about contributing, please contact us at support@saymyframe.com or open an issue on GitHub.

Thank you for contributing to SMF Flutter CLI!
