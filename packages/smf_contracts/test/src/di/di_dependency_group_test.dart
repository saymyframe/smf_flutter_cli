import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

const _dependency = DiDependency(
  abstractType: 'IService',
  implementation: 'Service()',
  bindingType: DiBindingType.singleton,
);

DiDependencyGroup _group(DiScope scope, {String? pathToDiTemplate}) {
  return DiDependencyGroup(
    diDependencies: const [_dependency],
    scope: scope,
    imports: const [Import.direct("import 'dart:io';")],
    pathToDiTemplate: pathToDiTemplate,
  );
}

void main() {
  group('DiDependencyGroup', () {
    test('core scope does not need a DI template', () {
      final group = _group(DiScope.core);

      expect(group.scope, DiScope.core);
      expect(group.pathToDiTemplate, isNull);
      expect(group.diDependencies, [_dependency]);
      expect(group.imports, hasLength(1));
    });

    test('module scope accepts a DI template path', () {
      final group = _group(
        DiScope.module,
        pathToDiTemplate: 'lib/features/home/di/home_di.dart',
      );

      expect(group.pathToDiTemplate, 'lib/features/home/di/home_di.dart');
    });

    test('module scope requires a DI template path', () {
      expect(
        () => _group(DiScope.module),
        throwsA(isA<AssertionError>()),
      );
    });

    test('module scope rejects a blank DI template path', () {
      expect(
        () => _group(DiScope.module, pathToDiTemplate: ''),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => _group(DiScope.module, pathToDiTemplate: '  '),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
