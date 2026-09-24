import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_home_flutter/smf_home_module_factory.dart';
import 'package:smf_home_flutter/src/module.dart';
import 'package:test/test.dart';

void main() {
  group('SmfHomeModuleFactory', () {
    final factory = SmfHomeModuleFactory();

    test('creates the bloc variant for bloc projects', () {
      expect(
        factory.create(const ModuleProfile(stateManager: StateManager.bloc)),
        isA<SmfHomeBlocModule>(),
      );
    });

    test('creates the riverpod variant for riverpod projects', () {
      expect(
        factory
            .create(const ModuleProfile(stateManager: StateManager.riverpod)),
        isA<SmfHomeRiverpodModule>(),
      );
    });

    test('supports every state manager', () {
      for (final stateManager in StateManager.values) {
        expect(
          factory.supports(ModuleProfile(stateManager: stateManager)),
          isTrue,
          reason: stateManager.name,
        );
      }
    });

    test('creates modules named kHomeFeatureModule', () {
      for (final stateManager in StateManager.values) {
        final module =
            factory.create(ModuleProfile(stateManager: stateManager));

        expect(
          module.moduleDescriptor.name,
          kHomeFeatureModule,
          reason: stateManager.name,
        );
      }
    });
  });
}
