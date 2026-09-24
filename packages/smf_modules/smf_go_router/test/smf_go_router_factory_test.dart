import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_go_router/src/smf_go_router_module.dart';
import 'package:test/test.dart';

void main() {
  group('SmfGoRouterFactory', () {
    test('creates the go_router module for every state manager', () {
      final factory = SmfGoRouterFactory();

      for (final stateManager in StateManager.values) {
        final profile = ModuleProfile(stateManager: stateManager);

        expect(factory.supports(profile), isTrue, reason: '$stateManager');
        expect(factory.create(profile), isA<SmfGoRouterModule>());
      }
    });
  });
}
