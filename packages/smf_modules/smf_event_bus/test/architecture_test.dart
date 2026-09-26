@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_event_bus',
        // The bundle of its brick.
        dependencies: {'mason'},
        // The app entry of the apps that the tests render, and a DI
        // container that registers the service in some of them.
        testModules: {'smf_flutter_core', 'smf_get_it'},
      ).problems(),
      isEmpty,
    );
  });
}
