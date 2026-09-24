import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

void main() {
  group('StateManager', () {
    test('identifiers match the public state management constants', () {
      // The CLI maps --state-manager values back to StateManager by these ids.
      expect(StateManager.bloc.stateManager, kBlocStateManagement);
      expect(StateManager.riverpod.stateManager, kRiverpodStateManagement);
    });

    test('identifiers are unique', () {
      final ids = StateManager.values.map((s) => s.stateManager).toList();

      expect(ids.toSet(), hasLength(ids.length));
    });
  });
}
