import 'package:smf_contracts/bundles/smf_contracts_brick_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('SmfContractsFactory', () {
    final factory = SmfContractsFactory();

    for (final stateManager in StateManager.values) {
      test('supports and creates the module for ${stateManager.name}', () {
        final profile = ModuleProfile(stateManager: stateManager);

        expect(factory.supports(profile), isTrue);
        expect(factory.create(profile), isA<SmfContractsModule>());
      });
    }
  });

  group('SmfContractsModule', () {
    final module = SmfContractsModule();

    test('is registered under the contracts module name', () {
      expect(module.moduleDescriptor.name, kContractsModule);
      expect(module.moduleDescriptor.dependsOn, isEmpty);
    });

    test('contributes the contracts brick', () {
      final brick = module.brickContributions.single;

      expect(brick.bundle, same(smfContractsBrickBundle));
      expect(brick.mergeStrategy, FileMergeStrategy.overwrite);
    });

    test('contributes no DI, routes or shared file patches', () {
      expect(module.di, isEmpty);
      expect(module.routes.routes, isEmpty);
      expect(module.sharedFileContributions, isEmpty);
    });
  });
}
