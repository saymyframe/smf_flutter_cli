@TestOn('vm')
library;

import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
      'the fixture registry and the modules it depends on take the names of '
      'the classes of roles from the roles', () {
    final roles = ModuleRegistry.rolesOf([
      ...fixtureModules(),
      ...severalProvidersModules(),
    ]);

    expect(
      [
        for (final role in roles)
          ...role.interface.symbols.whereType<RequiredClass>(),
      ],
      isNotEmpty,
    );
    expect(
      roleClassNameProblems(roles),
      isEmpty,
      reason: 'Generated code takes the name of a class of a role from the '
          'role, such as AppEntryRole.fallbackStartScreen.name.',
    );
  });
}
