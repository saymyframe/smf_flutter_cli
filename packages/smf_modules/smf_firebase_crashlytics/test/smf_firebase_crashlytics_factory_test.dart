import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics_factory.dart';
import 'package:smf_firebase_crashlytics/src/smf_firebase_crashlytics_module.dart';
import 'package:test/test.dart';

void main() {
  group('SmfFirebaseCrashlyticsFactory', () {
    final factory = SmfFirebaseCrashlyticsFactory();

    test('creates SmfFirebaseCrashlyticsModule for every state manager', () {
      for (final stateManager in StateManager.values) {
        expect(
          factory.create(ModuleProfile(stateManager: stateManager)),
          isA<SmfFirebaseCrashlyticsModule>(),
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

    test('creates modules named kFirebaseCrashlytics', () {
      for (final stateManager in StateManager.values) {
        final module =
            factory.create(ModuleProfile(stateManager: stateManager));

        expect(
          module.moduleDescriptor.name,
          kFirebaseCrashlytics,
          reason: stateManager.name,
        );
      }
    });
  });
}
