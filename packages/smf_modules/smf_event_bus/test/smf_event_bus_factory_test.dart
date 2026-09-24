import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_event_bus/smf_event_bus_factory.dart';
import 'package:smf_event_bus/src/module.dart';
import 'package:test/test.dart';

void main() {
  group('SmfEventBusFactory', () {
    final factory = SmfEventBusFactory();

    test('creates SmfEventBusModule for every state manager', () {
      for (final stateManager in StateManager.values) {
        expect(
          factory.create(ModuleProfile(stateManager: stateManager)),
          isA<SmfEventBusModule>(),
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

    test('creates modules named kCommunicationModule', () {
      for (final stateManager in StateManager.values) {
        final module =
            factory.create(ModuleProfile(stateManager: stateManager));

        expect(
          module.moduleDescriptor.name,
          kCommunicationModule,
          reason: stateManager.name,
        );
      }
    });
  });
}
