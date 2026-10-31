# Generate a Flutter app with CI on GitHub Actions

`github_actions` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that gives an app its CI on GitHub Actions. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m github_actions --no-input
```

The app gets `.github/workflows/ci.yml`. Push the app to a repository on GitHub, and each push runs these commands in a fresh copy of the repository:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

With the workflow on the default branch of the repository, build a release APK for `dev`, `staging` or `prod` from the Actions tab, or with the GitHub CLI:

```bash
gh workflow run ci.yml -f environment=staging
```

The APK is an artifact of the run. The Android project of the app signs a release with the debug key, so the APK is for testers.

In an app with a provider of the env role, such as `dart_define`, a build takes the values of `.env` from the variables of the GitHub environment of that name:

```bash
gh variable set MY_SERVICE_KEY --env staging --body '<value>'
```

Every value ends up in the app, so never use one for a secret.

The documentation has more on [the github_actions module](https://doc.saymyframe.com/modules/github-actions).
