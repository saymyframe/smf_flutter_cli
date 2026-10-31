@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_github_actions',
        // The app entry of the apps that the tests render, and the provider
        // of the env role whose argument they see in the workflow.
        testModules: {'smf_flutter_core', 'smf_dart_define'},
      ).problems(),
      isEmpty,
    );
  });
}
