import 'package:smf_flutter_cli/prompts/prompt.dart';
import 'package:test/test.dart';

import '../../helpers/test_modules.dart';

void main() {
  group('ProjectPreferences', () {
    test('exposes the values it was created with', () {
      final modules = [TestModule('a'), TestModule('b')];

      final preferences = ProjectPreferences(
        name: 'demo',
        packageName: 'com.acme',
        initialRoute: null,
        selectedModules: modules,
      );

      expect(preferences.name, 'demo');
      expect(preferences.packageName, 'com.acme');
      expect(preferences.initialRoute, isNull);
      expect(preferences.selectedModules, same(modules));
    });
  });
}
