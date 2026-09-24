import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core_factory.dart';
import 'package:smf_firebase_core/src/firebase_core_module.dart';
import 'package:test/test.dart';

void main() {
  group('SmfFirebaseCoreFactory', () {
    final factory = SmfFirebaseCoreFactory();

    test('creates FirebaseCoreModule for every state manager', () {
      for (final stateManager in StateManager.values) {
        expect(
          factory.create(ModuleProfile(stateManager: stateManager)),
          isA<FirebaseCoreModule>(),
          reason: stateManager.name,
        );
      }
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

    test('creates modules named kFirebaseCore', () {
      for (final stateManager in StateManager.values) {
        final module =
            factory.create(ModuleProfile(stateManager: stateManager));

        expect(
          module.moduleDescriptor.name,
          kFirebaseCore,
          reason: stateManager.name,
        );
      }
    });
  });
}
