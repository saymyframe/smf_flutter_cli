import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/constants/smf_options.dart';
import 'package:test/test.dart';

void main() {
  group('smfStateManagers', () {
    // CreatePrompt maps --state-manager to StateManager by identifier and
    // offers StateManager.values in the interactive picker.
    test('matches the identifiers of StateManager', () {
      expect(
        smfStateManagers,
        unorderedEquals(StateManager.values.map((s) => s.stateManager)),
      );
    });
  });
}
