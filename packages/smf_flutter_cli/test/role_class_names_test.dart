@TestOn('vm')
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  test(
      'the CLI and the modules that it offers take the names of the classes '
      'of roles from the roles', () {
    final roles = ModuleRegistry(smfModules).roles;

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
          'role, such as LayoutRole.destination.name.',
    );
  });
}
