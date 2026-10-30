# smf_github_actions

The SMF module that gives an app its CI on GitHub Actions. It provides the CI role of SMF.

The role says what CI runs, and this module writes that into `.github/workflows/ci.yml`:

- Each push to a branch runs `flutter pub get`, the format check, `flutter analyze` and `flutter test`. They pass on the first push without any setup.
- From the Actions tab of the repository, or with `gh workflow run ci.yml -f environment=staging`, a developer builds a release APK for `dev`, `staging` or `prod`. The APK is an artifact of the run. It is signed as the Android project of the app signs it, with the debug key, so it is for testers: uploading to a store, a signing key of your own and iOS are not part of it.

A build writes `.env` from the variables of the GitHub environment of that name, through `tool/write_env.dart`, which the role generates in an app with the env role. No value is a part of the text of a script. Each action is pinned to a full commit, with its tag in a comment, so the file does not change under you. Nothing updates the pins, and the workflow runs the latest stable Flutter. The README of the app tells how to stay on one version of Flutter.

## Use with the SMF CLI

`smf create` asks which module provides CI, and offers none as well. To choose it without the question:

```bash
smf create my_app -m github_actions
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The github_actions module](https://doc.saymyframe.com/modules/github-actions)
