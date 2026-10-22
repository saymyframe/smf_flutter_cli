# smf_dart_define

The SMF module that gives an app the values of its `.env` file through `--dart-define-from-file`, an option of the `flutter` tool. It provides the env role of SMF.

The modules of an app declare the values that a developer fills in after generating the app, such as the public key of a service, as keys of the env role. The role writes `.env`, which stays out of git, and `.env.example`, which has the same keys without values. This module adds `lib/core/env/app_env.dart` with `AppEnv`, which has a static getter for each key. A getter reads its value with `const String.fromEnvironment` and returns `null` while the value is empty or missing.

The `flutter` tool reads `.env` when a command that builds, runs or tests the app starts, given `--dart-define-from-file=.env`, and compiles each value into the app. No code is generated after you edit `.env`, and the analyzer sees the empty values, so a fresh clone of the app analyzes and builds. The module also adds run configurations that pass the argument. In VS Code, `.vscode/launch.json` passes it to Run and Debug (F5), to the Run and Debug links above `main()`, and to the tests run from their links or from the Testing view. In Android Studio, `.run/main.run.xml` passes it only to the run configuration named after the app, not to a test that you run there. The README of the app lists the commands.

Every value ends up in the app, where anyone who has the app can read it. So `.env` holds only values that may be public, never a secret.

## Use with the SMF CLI

`smf create` asks which module provides the values in `.env`, and offers none as well. When a module of the app needs them and no other module provides them, it adds this module without the question. To choose it without the question:

```bash
smf create my_app -m dart_define
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The dart_define module](https://doc.saymyframe.com/modules/dart-define)
