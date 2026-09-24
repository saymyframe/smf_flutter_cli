import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:test/test.dart';

void main() {
  group('smfModules', () {
    for (final stateManager in StateManager.values) {
      final profile = ModuleProfile(stateManager: stateManager);

      group('for ${stateManager.stateManager}', () {
        // ModuleCreator resolves dependencies by registry key, so the key must
        // match the name of the module the factory creates.
        test('registers each factory under its module name', () {
          for (final MapEntry(key: key, value: factory) in smfModules.entries) {
            if (!factory.supports(profile)) continue;

            expect(
              factory.create(profile).moduleDescriptor.name,
              key,
              reason: '${factory.runtimeType} is registered as "$key"',
            );
          }
        });

        test('registers every module dependency', () {
          for (final factory in smfModules.values) {
            if (!factory.supports(profile)) continue;
            final descriptor = factory.create(profile).moduleDescriptor;

            expect(
              smfModules.keys,
              containsAll(descriptor.dependsOn),
              reason: '${descriptor.name} depends on ${descriptor.dependsOn}',
            );
          }
        });
      });
    }

    test('includes the core modules that create always adds', () {
      expect(smfModules, contains(kFlutterCoreModule));
      expect(smfModules, contains(kContractsModule));
    });
  });
}
