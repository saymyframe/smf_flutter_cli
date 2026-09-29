@TestOn('vm')
library;

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test('follows the rules of the package of a module', () {
    expect(
      const ModulePackage(
        'smf_flutter_core',
        // The bundle of its brick.
        dependencies: {'mason'},
        // Other modules render the apps of their tests with this one, and
        // pub.dev resolves dev dependencies when it analyzes a package, so
        // its tests use no other module: that would make a cycle.
      ).problems(),
      isEmpty,
    );
  });
}
