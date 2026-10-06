[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=saymyframe_smf_flutter_cli&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=saymyframe_smf_flutter_cli)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=saymyframe_smf_flutter_cli&metric=coverage)](https://sonarcloud.io/component_measures?id=saymyframe_smf_flutter_cli&metric=coverage)

# smf_pipeline

The generation pipeline of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli): it selects modules, checks their contributions against the roles they declare, and generates a Flutter app from them.

The pipeline knows no concrete module or role. It depends only on the core of the module model, `package:smf_contracts/core.dart`, and receives the modules and the machine it runs on from the CLI.

Most users use it through the SMF CLI, which passes its modules and the machine to `runSmf`:

```dart
exitCode = await runSmf(
  arguments,
  modules: modules,
  hostFor: ({required verbose}) => host,
);
```

`smf create` renders the app in memory, finishes it in a temporary directory (`flutter pub get`, code generation, the steps of the modules, `dart fix` and `dart format`), and then moves it into place. `package:smf_pipeline/testing.dart` has the contract test harness, which checks that modules follow the rules of their roles and renders the apps they make. It also has `ModulePackage`, which checks what the package of a module imports and depends on, and `roleClassNameProblems`, which checks that the code of modules takes the names of the classes that roles require from the roles, such as `LayoutRole.appShell.name`, instead of spelling them out in strings. `roleNoteProblems` checks the notes of the roles, such as those in the guide for coding agents of an app. A note of a role holds whichever modules provide the roles, so it has no id and no package of a provider of any role, or of a module that a provider depends on, no name that only their code declares, no name in upper camel case that only code with one of their packages has, and no file that only they generate. What the roles guarantee is free. The check reads the text of a note only for ids and packages, and it knows a module only from the generated files, so it misses a method of a package and one word of an id of several words. It also takes a name of Flutter that only files with one package have for a name of that package. Its `allowed` argument is for that case: it has what a note may have after all, as the note gives it and with the reason. It also serves the author of a module whose registry gets a line about a note of `smf_contracts`, which the author cannot change.

## Documentation

- [Test a module](https://doc.saymyframe.com/extending/testing): the contract harness and `ModulePackage` in the tests of a module.
- [The generation pipeline](https://doc.saymyframe.com/concepts/pipeline): the stages of `smf create`.
- [API reference](https://pub.dev/documentation/smf_pipeline/latest/).
