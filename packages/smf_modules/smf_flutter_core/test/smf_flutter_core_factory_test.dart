import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core_factory.dart';
import 'package:smf_flutter_core/src/module.dart';
import 'package:test/test.dart';

void main() {
  group('SmfFlutterCoreFactory', () {
    final factory = SmfFlutterCoreFactory();

    test('creates the bloc variant for bloc projects', () {
      expect(
        factory.create(const ModuleProfile(stateManager: StateManager.bloc)),
        isA<SmfCoreModule>(),
      );
    });

    test('creates the riverpod variant for riverpod projects', () {
      expect(
        factory
            .create(const ModuleProfile(stateManager: StateManager.riverpod)),
        isA<SmfCoreModuleRiverpod>(),
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

    test('creates modules named kFlutterCoreModule', () {
      for (final stateManager in StateManager.values) {
        final module =
            factory.create(ModuleProfile(stateManager: stateManager));

        expect(
          module.moduleDescriptor.name,
          kFlutterCoreModule,
          reason: stateManager.name,
        );
      }
    });
  });
}
