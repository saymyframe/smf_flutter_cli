import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the env role, after what the role says there: the commands of
/// the `flutter` tool with the argument that gives the app the values of
/// `.env`, the restart of `flutter run` after an edit of `.env`, how the
/// getter of a new key reads its value, and what `AppEnv.supplied` needs.
/// Its first line names the argument, as the note of a provider that wraps a
/// package names the package.
const agentNote = '''
With `--dart-define-from-file`:

- Every command of the `flutter` tool that builds, runs or tests the app takes `--dart-define-from-file=${EnvRole.dotEnvFile}`, such as `flutter run --dart-define-from-file=${EnvRole.dotEnvFile}`, `flutter test` and `flutter build`. Without it, every getter of `AppEnv` is `null`, and a release build stops with an error.
- A command reads `${EnvRole.dotEnvFile}` only when it starts. After a change of `${EnvRole.dotEnvFile}`, stop `flutter run` and start it again: hot reload and hot restart keep the values that the app was built with.
- The getter of a new key in `${EnvRole.readerFile}` reads `const String.fromEnvironment('MY_SERVICE_KEY')`, with the key in place of `MY_SERVICE_KEY`, and returns `null` for an empty value, as the other getters do.
- `AppEnv.supplied` is `true` once `--dart-define-from-file=${EnvRole.dotEnvFile}` declared one of the keys that it names, so a new key needs no change there. An app without keys has `true` there: with its first key, make it `bool.hasEnvironment('MY_SERVICE_KEY')` with that key.
''';
