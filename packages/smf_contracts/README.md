[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=saymyframe_smf_flutter_cli&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=saymyframe_smf_flutter_cli)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=saymyframe_smf_flutter_cli&metric=coverage)](https://sonarcloud.io/component_measures?id=saymyframe_smf_flutter_cli&metric=coverage)

# smf_contracts

The module model of [Say My Frame](https://doc.saymyframe.com) (SMF), which generates Flutter apps from independent modules with the [SMF CLI](https://pub.dev/packages/smf_flutter_cli). A module is a Dart class that describes what it adds to an app:

- the roles it provides, requires or uses, such as the router or dependency injection, instead of the modules that implement them;
- its contributions: files from templates, code for the sockets of roles, such as the start-up of the app, data for roles, such as routes and services, dependencies of `pubspec.yaml`, checks of the machine and commands to run after generation.

The generation pipeline, [smf_pipeline](https://pub.dev/packages/smf_pipeline), resolves the modules of an app, checks their contributions against the rules of their roles and turns them into the app.

The package has two libraries to import:

- `package:smf_contracts/smf_contracts.dart`, the model with the roles of SMF: the app entry, the router, the layout, state management, dependency injection, events, preferences, analytics and crash reporting;
- `package:smf_contracts/core.dart`, the core of the model without concrete roles, which the pipeline uses.

`lib/bundles/` holds the templates of these roles, bundled from `bricks/`, which the roles give the pipeline to render.

## A module

This module adds the logging package to the app and a line to the start-up of the app that prints the log records, INFO and above by default:

```dart
import 'package:smf_contracts/smf_contracts.dart';

final class LoggingModule extends SmfModule {
  const LoggingModule();

  static const id = ModuleId('logging');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Logging with the logging package',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        const PubspecContribution.hosted('logging', '^1.3.0'),
        const SocketContribution.code(
          AppEntryRole.bootstrapEarly,
          Fragment(
            r"Logger.root.onRecord.listen((record) => debugPrint('${record.level.name}: ${record.message}'));",
            imports: [
              ImportRef('package:flutter/foundation.dart', show: ['debugPrint']),
              ImportRef('package:logging/logging.dart', show: ['Logger']),
            ],
          ),
        ),
      ];
}
```

To offer the module, a command of your own passes it to `runCli` of [smf_flutter_cli](https://pub.dev/packages/smf_flutter_cli) with the modules of SMF, and the tests of the module check it with the contract harness of `package:smf_pipeline/testing.dart` in every app it can be part of.

## Documentation

- [Extending SMF](https://doc.saymyframe.com/extending): write a module, provide a role or define a new one, and test and publish it.
- [The module model](https://doc.saymyframe.com/concepts/module-model) and [sockets and contributions](https://doc.saymyframe.com/concepts/sockets).
- [API reference](https://pub.dev/documentation/smf_contracts/latest/).
