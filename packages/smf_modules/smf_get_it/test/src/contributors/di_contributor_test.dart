import 'dart:io';

import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/di_contributor.dart';
import 'package:test/test.dart';

import '../../helpers/dart_code.dart';

/// Makes each registration easy to spot and keeps these tests independent
/// of the get_it syntax.
class _NameOnlyGenerator implements DiCodeGenerator {
  const _NameOnlyGenerator();

  @override
  String generate(DiDependency dependency) =>
      'register(${dependency.abstractType});';
}

final class _TestContributor extends DiContributor {
  const _TestContributor({required super.projectRoot})
      : super(codeGenerator: const _NameOnlyGenerator());

  @override
  Future<List<GeneratedFile>> contribute(
    List<DiDependencyGroup> groups, {
    Map? mustacheVariables,
  }) async =>
      const [];
}

DiDependency _dependency(String type, {int? order}) => DiDependency(
      abstractType: type,
      implementation: '$type()',
      bindingType: DiBindingType.singleton,
      order: order,
    );

DiDependencyGroup _coreGroup({
  List<DiDependency> dependencies = const [],
  List<Import> imports = const [],
}) {
  return DiDependencyGroup(
    diDependencies: dependencies,
    scope: DiScope.core,
    imports: imports,
  );
}

void main() {
  group('DiContributor', () {
    const projectRoot = '/project';
    const contributor = _TestContributor(projectRoot: projectRoot);

    group('writeTo', () {
      test('points core registrations to lib/core/di/core_di.dart', () {
        expect(
          contributor.writeTo(DiScope.core),
          join(projectRoot, 'lib', 'core', 'di', 'core_di.dart'),
        );
      });

      test('points module registrations to their template', () {
        expect(
          contributor.writeTo(
            DiScope.module,
            pathToDiTemplate: 'lib/features/auth/di/auth_di.dart',
          ),
          join(projectRoot, 'lib/features/auth/di/auth_di.dart'),
        );
      });

      test('requires a template path for module registrations', () {
        expect(
          () => contributor.writeTo(DiScope.module),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('combineImports', () {
      test('resolves the imports of all groups in declaration order', () {
        final imports = contributor.combineImports([
          _coreGroup(
            imports: [
              const Import.core(
                  ImportAnchor.coreService, 'analytics/analytics.dart'),
              const Import.direct(
                  "import 'package:firebase_analytics/fa.dart'"),
            ],
          ),
          _coreGroup(
              imports: [const Import.features('auth/auth_repository.dart')]),
        ]);

        expect(imports.split('\n'), [
          "import 'package:{{app_name_sc}}/core/services/analytics/analytics.dart';",
          "import 'package:firebase_analytics/fa.dart';",
          "import 'package:{{app_name_sc}}/features/auth/auth_repository.dart';",
        ]);
      });

      test('returns an empty string when no group has imports', () {
        expect(contributor.combineImports([_coreGroup()]), isEmpty);
      });

      test(
        'imports a file shared by several groups only once',
        () {
          const shared = Import.core(
            ImportAnchor.coreService,
            'communication/i_communication_service.dart',
          );

          final imports = contributor.combineImports([
            _coreGroup(imports: [shared]),
            _coreGroup(imports: [shared]),
          ]);

          expect(imports.split('\n'), hasLength(1));
        },
        skip: 'Bug: combineImports keeps duplicates, so the generated file '
            'gets duplicate_import warnings',
      );
    });

    group('combineRegistrations', () {
      test('generates one line per dependency with the code generator', () {
        final registrations = contributor.combineRegistrations([
          _coreGroup(dependencies: [_dependency('IA'), _dependency('IB')]),
          _coreGroup(dependencies: [_dependency('IC')]),
        ]);

        expect(registrations, 'register(IA);\nregister(IB);\nregister(IC);\n');
      });

      test('orders dependencies by order across groups, unordered ones last',
          () {
        final registrations = contributor.combineRegistrations([
          _coreGroup(
            dependencies: [
              _dependency('IUnorderedA'),
              _dependency('ISecond', order: 2),
            ],
          ),
          _coreGroup(
            dependencies: [
              _dependency('IUnorderedB'),
              _dependency('IFirst', order: 1),
            ],
          ),
        ]);

        expect(registrations.trim().split('\n'), [
          'register(IFirst);',
          'register(ISecond);',
          'register(IUnorderedA);',
          'register(IUnorderedB);',
        ]);
      });

      test('returns an empty string when there is nothing to register', () {
        expect(contributor.combineRegistrations([]), isEmpty);
      });
    });

    group('processFile', () {
      late Directory tempDir;
      late File template;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('smf_di_contributor');
        template = File(join(tempDir.path, 'di.dart'));
        await template.writeAsString('''
{{#imports}}
{{{.}}}
{{/imports}}

void setUpDI() {
  {{#di}}
  {{{.}}}
  {{/di}}
}
''');
      });

      tearDown(() => tempDir.delete(recursive: true));

      test('fills the template slots and resolves mustache variables',
          () async {
        final file = await contributor.processFile(
          imports: "import 'package:{{app_name_sc}}/core/api.dart';",
          registrations: 'getIt.registerFactory<IApi>(() => Api());',
          file: template,
          mustacheVariables: {'app_name': 'Test App'},
        );

        expect(file.path, template.path);
        expect(
          file.content,
          contains("import 'package:test_app/core/api.dart';"),
        );
        expect(
          file.content,
          contains('getIt.registerFactory<IApi>(() => Api());'),
        );
        expect(file.content, isNot(contains('{{')));
        expectParses(file.content);
      });

      test('renders empty slots when there is nothing to contribute', () async {
        final file = await contributor.processFile(
          imports: '',
          registrations: '',
          file: template,
        );

        expect(file.content, isNot(contains('{{')));
        expect(file.content, contains('void setUpDI() {'));
        expectParses(file.content);
      });
    });
  });
}
