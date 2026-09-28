# Test an SMF module with the contract harness

The tests of a module package check the module with `package:smf_pipeline/testing.dart`. This test is for `LoggingModule`, the module of [the example of smf_contracts](https://pub.dev/packages/smf_contracts/example), in a package `smf_logging` with `smf_flutter_core`, `smf_pipeline` and `test` as dev dependencies:

```dart
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_logging/smf_logging.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  final registry = ModuleRegistry(const [FlutterCoreModule(), LoggingModule()]);

  test('every app of the module follows the rules of its roles', () async {
    final results = await ContractHarness(registry).checkAll();
    for (final result in results) {
      expect(result.errors, isEmpty, reason: '${result.contractCase}');
    }
  });

  test('bootstrap() prints the log records', () async {
    final result = await ContractHarness(registry).check(
      const ContractCase('logging', requested: [LoggingModule.id]),
    );
    final bootstrap = result.app!.files['lib/bootstrap.dart']!.text;
    expect(bootstrap, contains('Logger.root.onRecord.listen'));
  });

  test('the package follows the rules of a module package', () {
    expect(
      const ModulePackage(
        'smf_logging',
        testModules: {'smf_flutter_core'},
      ).problems(),
      isEmpty,
    );
  });
}
```

- `checkAll()` renders in memory every app that matters for the modules of the registry, here the app with `flutter_core` alone and the app with `logging`, and checks each against the rules of the module model.
- `check()` renders one app, and `result.app` holds its files.
- `ModulePackage` checks what the package imports and depends on. `flutter_core` provides the app entry of the apps that the tests render, which is why it is a test module.

[Test a module](https://doc.saymyframe.com/extending/testing) describes the harness and the cases it builds.
