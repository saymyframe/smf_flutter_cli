import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_get_it/src/smf_get_it_module.dart';
import 'package:test/test.dart';

void main() {
  group('SmfGetItFactory', () {
    test('creates the get_it module for every state manager', () {
      final factory = SmfGetItFactory();

      for (final stateManager in StateManager.values) {
        final profile = ModuleProfile(stateManager: stateManager);

        expect(factory.supports(profile), isTrue, reason: '$stateManager');
        expect(factory.create(profile), isA<SmfGetItModule>());
      }
    });
  });
}
