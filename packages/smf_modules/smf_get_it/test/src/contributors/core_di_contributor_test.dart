import 'dart:io';

import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/core_di_contributor.dart';
import 'package:smf_get_it/src/contributors/get_it_code_generator.dart';
import 'package:test/test.dart';

import '../../helpers/dart_code.dart';
import '../../helpers/project.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late CoreDiContributor contributor;

  String coreDiPath() => join(projectRoot, 'lib', 'core', 'di', 'core_di.dart');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smf_core_di');
    projectRoot = await renderGetItBrick(tempDir);
    contributor = CoreDiContributor(
      projectRoot: projectRoot,
      codeGenerator: const GetItCodeGenerator(),
    );
  });

  tearDown(() => tempDir.delete(recursive: true));

  group('CoreDiContributor', () {
    test('renders all core groups into lib/core/di/core_di.dart', () async {
      final files = await contributor.contribute(
        [
          DiDependencyGroup(
            scope: DiScope.core,
            imports: [
              Import.core(ImportAnchor.coreService, 'analytics/analytics.dart'),
            ],
            diDependencies: [
              const DiDependency(
                abstractType: 'IAnalyticsService',
                implementation: 'AnalyticsService()',
                bindingType: DiBindingType.singleton,
              ),
            ],
          ),
          DiDependencyGroup(
            scope: DiScope.core,
            imports: [
              Import.direct("import 'package:event_bus/event_bus.dart';"),
            ],
            diDependencies: [
              const DiDependency(
                abstractType: 'EventBus',
                implementation: 'EventBus()',
                bindingType: DiBindingType.factory,
              ),
            ],
          ),
        ],
        mustacheVariables: {'app_name': appName},
      );

      final file = files.single;
      expect(file.path, coreDiPath());
      expect(
        file.content,
        contains("import 'package:test_app/core/typedef.dart';"),
      );
      expect(
        file.content,
        contains(
          "import 'package:test_app/core/services/analytics/analytics.dart';",
        ),
      );
      expect(
        file.content,
        contains("import 'package:event_bus/event_bus.dart';"),
      );
      expect(
        file.content,
        contains(
          'getIt.registerLazySingleton<IAnalyticsService>'
          '(() => AnalyticsService());',
        ),
      );
      expect(
        file.content,
        contains('getIt.registerFactory<EventBus>(() => EventBus());'),
      );
      expect(file.content, isNot(contains('{{')));
      expectParses(file.content);
    });

    test('renders an empty setUpCoreDI when there are no core groups',
        () async {
      final files = await contributor.contribute(
        [],
        mustacheVariables: {'app_name': appName},
      );

      final file = files.single;
      expect(file.path, coreDiPath());
      expect(file.content, contains('void setUpCoreDI() {'));
      expect(file.content, isNot(contains('getIt.')));
      expect(file.content, isNot(contains('{{')));
      expectParses(file.content);
    });
  });
}
