import 'package:smf_contracts/lego.dart';
import 'package:test/test.dart';

const _home = ModuleId('home');

void main() {
  test('the kinds have distinct snake_case ids and labels', () {
    const kinds = [
      ModuleKinds.scaffold,
      ModuleKinds.infrastructure,
      ModuleKinds.feature,
      ModuleKinds.layout,
    ];
    final ids = [for (final kind in kinds) kind.id];

    expect(ids, ['scaffold', 'infrastructure', 'feature', 'layout']);
    for (final kind in kinds) {
      expect(SmfNames.isSnakeCase(kind.id), isTrue);
      expect(kind.label, isNotEmpty);
    }
  });

  test('an infrastructure module has no routes, features or variants', () {
    const kind = ModuleKinds.infrastructure;

    expect(kind.forbiddenData, {routerRole});
    expect(kind.requiredData, isEmpty);
    expect(kind.allowsVariants, isFalse);
    expect(kind.compositionFileOf(_home), isNull);
    expect(kind.allowsFile(_home, 'lib/core/router/app_router.dart'), isTrue);
    expect(kind.allowsFile(_home, 'lib/features/home/x.dart'), isFalse);
  });

  test('a feature requires the router and lives in its own directory', () {
    const kind = ModuleKinds.feature;

    expect(kind.impliedRequires, {routerRole});
    expect(kind.requiredData, {routerRole});
    expect(kind.allowsVariants, isTrue);
    expect(kind.fileRootsOf(_home), ['lib/features/home/']);
    expect(
      kind.allowsFile(_home, 'lib/features/home/home_screen.dart'),
      isTrue,
    );
    expect(kind.allowsFile(_home, 'lib/features/homes/x.dart'), isFalse);
    expect(
      kind.compositionFileOf(_home),
      'lib/features/home/home_composition.dart',
    );
    expect(
      const ModuleDescriptor(id: _home, description: 'Home', kind: kind)
          .effectiveRequires,
      {routerRole},
    );
  });

  test('a layout provides the layout role in lib/core/layout/', () {
    const kind = ModuleKinds.layout;

    expect(kind.mustProvide, {layoutRole});
    expect(kind.forbiddenData, {routerRole});
    expect(kind.allowsFile(_home, 'lib/core/layout/app_shell.dart'), isTrue);
    expect(kind.allowsFile(_home, 'lib/core/router/x.dart'), isFalse);
  });
}
