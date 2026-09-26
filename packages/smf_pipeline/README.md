[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=saymyframe_smf_flutter_cli&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=saymyframe_smf_flutter_cli)

# smf_pipeline

The generation pipeline of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli): it selects modules, checks their contributions against the roles they declare, and generates a Flutter app from them.

The pipeline knows no concrete module or role. It depends only on the core of the lego model, `package:smf_contracts/lego_core.dart`, and receives the modules and the machine it runs on from the CLI.

Most users use it through the SMF CLI, which passes its modules and the machine to `runSmf`:

```dart
exitCode = await runSmf(
  arguments,
  modules: modules,
  hostFor: ({required verbose}) => host,
);
```

`smf create` renders the app in memory, finishes it in a temporary directory (`flutter pub get`, code generation, the steps of the modules, `dart fix` and `dart format`), and then moves it into place. `package:smf_pipeline/testing.dart` has the contract test harness, which checks that modules follow the rules of their roles and renders the apps they make, and `ModulePackage`, which checks what the package of a module imports and depends on.

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_pipeline) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See [LICENSE](LICENSE).
