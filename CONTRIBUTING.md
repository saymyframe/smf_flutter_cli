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
8. Open a Pull Request with a Conventional Commit as its title. PRs are squash-merged and the commit on main takes the title, so CI checks it. Mark a breaking change with `!` in the title (`feat(contracts)!: ...`).

## Development setup

CI pins Dart 3.12.2, and the output of the formatter depends on its version, so develop with that Dart, which Flutter 3.44.2 comes with.

1. Clone the repository
2. Install Melos and the Mason CLI: `dart pub global activate melos` and `dart pub global activate mason_cli`
3. Install dependencies and bundle bricks: `melos bootstrap`
4. Run all checks: `melos run check` (format, analyze, banlist, tests)

The bundles in `lib/bundles/` are generated from the bricks, so change the brick, run `melos bootstrap` and commit both. When a change alters what an app renders, update the snapshots of the CLI or of the fixtures with `SMF_UPDATE_SNAPSHOTS=1 dart test test/snapshot_test.dart` in the package, and review their diff.

CI also runs the tests with coverage, and fails when they do not cover a line or a branch of `lib/`. To check it locally, install the coverage tool with `dart pub global activate coverage`, then run `melos run test:coverage` and `melos run coverage:check`, which names each line and branch that no test reaches. Code that no test can run goes between `// coverage:ignore-start` and `// coverage:ignore-end`, with the reason in a comment.

Besides these checks, CI generates apps with Flutter and runs `flutter analyze` on each, then `flutter test` with the tests that packages keep for the apps in `app_tests/`. To run it locally, with `flutter` on the `PATH`:

```bash
dart run packages/smf_flutter_cli/tool/matrix.dart /tmp/smf_apps
dart run packages/smf_pipeline/fixture_registry/tool/matrix.dart /tmp/smf_fixture_apps
```

To check only some apps of the matrix, name them after the directory, such as `'every module (bloc)'`. In a directory whose path has letters beyond ASCII, the matrix analyzes the apps with `dart analyze`, as `flutter analyze` of Flutter 3.44 and 3.47 fails there.

CI also runs the tests on macOS and Windows, and on all three systems it generates apps in directories whose names have a space and letters beyond ASCII. The macOS job builds apps for the iOS simulator and archives one with Crashlytics, and a Windows job runs the install script of the Firebase CLI. On Linux it also builds an app with every module for Android. Every night, CI runs the jobs with Flutter on each stable release that the generated apps allow instead of the pinned one: the jobs on Linux on all of them, and those on macOS and Windows on the oldest and on the latest patch of each minor version. So a release of Flutter that breaks the generated apps shows up before users run into it. The nightly run also installs `smf_flutter_cli` from pub.dev, as a user does, and on each of those releases generates with it the apps with every module, analyzes and tests them and builds them for Android. A failure there affects the users of the published version, and its fix needs a release.

CI also starts apps on an Android emulator and on an iOS simulator, with a check as the entry of the app, which writes whether the app started and showed its first screen. The CLI keeps it in `app_tests/start`: it knows no module, only `main()` in `lib/main.dart`, which every app has whichever module provides its entry. CI starts an app without Firebase, and an app with every module that it configures with `flutterfire configure` in a Firebase project of its own. `.github/scripts/start_app.sh` builds the app with the check, installs and launches it with `adb` or `xcrun simctl`, and waits for the result. To start an app of yours with the check, on a running Android emulator or device, or on a booted iOS simulator:

```bash
dart run packages/smf_flutter_cli/tool/matrix.dart --add-app-tests <app> packages/smf_flutter_cli/app_tests/start
cd <app>
<repository>/.github/scripts/start_app.sh android <device> 600   # such as emulator-5554
<repository>/.github/scripts/start_app.sh ios <UDID of the simulator> 600
```

The last argument is the time for the build and the start, in seconds. The script finds the Android SDK through `ANDROID_HOME`, or where Android Studio installs it. `flutter run -d <device> -t integration_test/start_check.dart` runs the check too, and prints `SMF_START_CHECK: passed`, or `SMF_START_CHECK: failed: ` and the problems. An app with Firebase starts only once `flutterfire configure` configured it, as its README says.

The jobs with Flutter take the better part of an hour, so only pushes to main and pull requests into main run them. A pull request into another branch, such as one that collects the pull requests of a larger change, gets the job of the checks and the check of its title. The jobs with Flutter run once that branch goes into main through a pull request of its own. To run every job on a branch before that, use Run workflow on the Build workflow in the Actions tab.

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
