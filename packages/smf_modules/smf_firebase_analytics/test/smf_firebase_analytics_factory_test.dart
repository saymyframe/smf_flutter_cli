import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_analytics/src/module.dart';
import 'package:test/test.dart';

void main() {
  group('SmfFirebaseAnalyticsFactory', () {
    final factory = SmfFirebaseAnalyticsFactory();

    test('creates the bloc variant for bloc projects', () {
      final module = factory.create(
        const ModuleProfile(stateManager: StateManager.bloc),
      );

      expect(module, isA<FirebaseAnalyticsBlocModule>());
    });

    test('creates the riverpod variant for riverpod projects', () {
      final module = factory.create(
        const ModuleProfile(stateManager: StateManager.riverpod),
      );

      expect(module, isA<FirebaseAnalyticsRiverpodModule>());
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
  });
}
