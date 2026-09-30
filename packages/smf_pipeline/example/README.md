# Test an SMF module with the contract harness

The tests of a module package check the module with `package:smf_pipeline/testing.dart`. This test is for `LoggingModule`, the module of [the example of smf_contracts](https://pub.dev/packages/smf_contracts/example), in a package `smf_logging` with `smf_flutter_core`, `smf_pipeline` and `test` as dev dependencies:

```dart
import 'package:smf_contracts/smf_contracts.dart';
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

  test('bootstrap() prints the log records first', () async {
    final result = await ContractHarness(registry).check(
      const ContractCase('logging', requested: [LoggingModule.id]),
    );
    // What the first phase of the start-up runs, whichever module provides
    // the app entry and renders it into bootstrap().
    final early = result.app!.socketOrders[AppEntryRole.bootstrapEarly]!;
    expect(
      [
        for (final collected in early.contributions)
          (collected.contribution as SocketContribution).fragment!.code,
      ],
      [contains('Logger.root.onRecord.listen')],
    );
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
- `check()` renders one app. `result.app` holds its files and, in `socketOrders`, what each socket got, in the order it was rendered; `result.hook` holds the data and the roles of the app, as the hooks of the roles got them. So a test checks what the module gives a role through the role, whichever module provides it, rather than in the files of that module.
- `ModulePackage` checks what the package imports and depends on. `flutter_core` provides the app entry of the apps that the tests render, which is why it is a test module.

[Test a module](https://doc.saymyframe.com/extending/testing) describes the harness and the cases it builds.
