import 'dart:io';

import 'package:mason/mason.dart' hide GeneratedFile;
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/smf_get_it_module.dart';
import 'package:test/test.dart';

import '../helpers/dart_code.dart';
import '../helpers/project.dart';

const _authTemplate = 'lib/features/auth/di/auth_di.dart';

/// The DI declared by the firebase_analytics module.
final _analyticsGroup = DiDependencyGroup(
  diDependencies: [
    const DiDependency(
      abstractType: 'IAnalyticsService',
      implementation: 'FirebaseAnalyticsService(FirebaseAnalytics.instance)',
      bindingType: DiBindingType.singleton,
    ),
  ],
  scope: DiScope.core,
  imports: [
    const Import.core(
      ImportAnchor.coreService,
      'analytics/firebase/firebase_analytics_service.dart',
    ),
    const Import.core(
        ImportAnchor.coreService, 'analytics/i_analytics_service.dart'),
    const Import.direct(
      "import 'package:firebase_analytics/firebase_analytics.dart';",
    ),
  ],
);

/// The DI declared by the event_bus module.
final _eventBusGroup = DiDependencyGroup(
  diDependencies: [
    const DiDependency(
      abstractType: 'ICommunicationService',
      implementation: 'EventBusService(EventBus())',
      bindingType: DiBindingType.singleton,
    ),
  ],
  scope: DiScope.core,
  imports: [
    const Import.core(
      ImportAnchor.coreService,
      'communication/event_bus/event_bus_service.dart',
    ),
    const Import.core(
      ImportAnchor.coreService,
      'communication/i_communication_service.dart',
    ),
    const Import.direct("import 'package:event_bus/event_bus.dart';"),
  ],
);

void main() {
  late Directory tempDir;
  late String projectRoot;

  String coreDiPath() => join(projectRoot, 'lib', 'core', 'di', 'core_di.dart');

  Future<List<GeneratedFile>> generate(List<DiDependencyGroup> diGroups) {
    return SmfGetItModule().generateFromDsl(
      DslContext(
        projectRootPath: projectRoot,
        mustacheVariables: {'app_name': appName},
        logger: Logger(),
        initialRoute: '/home',
        diGroups: diGroups,
      ),
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smf_di_dsl');
    projectRoot = await renderGetItBrick(tempDir);
  });

  tearDown(() => tempDir.delete(recursive: true));

  group('DiDslGenerator', () {
    test('renders core_di.dart even when no module declares DI', () async {
      final files = await generate([]);

      final coreDi = files.single;
      expect(coreDi.path, coreDiPath());
      expect(coreDi.content, contains('void setUpCoreDI() {'));
      expect(coreDi.content, isNot(contains('{{')));
      expectParses(coreDi.content);
    });

    test('registers the DI of all modules in core_di.dart', () async {
      final files = await generate([_analyticsGroup, _eventBusGroup]);

      final content = files.single.content;
      for (final import in [
        "import 'package:test_app/core/typedef.dart';",
        "import 'package:test_app/core/services/analytics/firebase/"
            "firebase_analytics_service.dart';",
        "import 'package:test_app/core/services/analytics/"
            "i_analytics_service.dart';",
        "import 'package:firebase_analytics/firebase_analytics.dart';",
        "import 'package:test_app/core/services/communication/event_bus/"
            "event_bus_service.dart';",
        "import 'package:event_bus/event_bus.dart';",
      ]) {
        expect(content, contains(import));
      }
      expect(
        content,
        contains(
          'getIt.registerLazySingleton<IAnalyticsService>'
          '(() => FirebaseAnalyticsService(FirebaseAnalytics.instance));',
        ),
      );
      expect(
        content,
        contains(
          'getIt.registerLazySingleton<ICommunicationService>'
          '(() => EventBusService(EventBus()));',
        ),
      );
      expect(content, isNot(contains('{{')));
      expectParses(content);
    });

    test('registers dependencies by DiDependency.order across modules',
        () async {
      final files = await generate([
        DiDependencyGroup(
          scope: DiScope.core,
          imports: const [],
          diDependencies: [
            const DiDependency(
              abstractType: 'IAuthRepository',
              implementation: 'AuthRepository(getIt<IApiClient>())',
              bindingType: DiBindingType.singleton,
              order: 1,
            ),
          ],
        ),
        DiDependencyGroup(
          scope: DiScope.core,
          imports: const [],
          diDependencies: [
            const DiDependency(
              abstractType: 'IApiClient',
              implementation: 'ApiClient()',
              bindingType: DiBindingType.singleton,
              order: 0,
            ),
          ],
        ),
      ]);

      final content = files.single.content;
      expect(
        content.indexOf('<IApiClient>'),
        lessThan(content.indexOf('<IAuthRepository>')),
      );
    });

    test('writes core and module groups to their own files', () async {
      await writeModuleDiTemplate(
        projectRoot,
        _authTemplate,
        setUpFunction: 'setUpAuthDI',
      );

      final files = await generate([
        DiDependencyGroup(
          scope: DiScope.module,
          pathToDiTemplate: _authTemplate,
          imports: [const Import.features('auth/auth_repository.dart')],
          diDependencies: [
            const DiDependency(
              abstractType: 'IAuthRepository',
              implementation: 'AuthRepository()',
              bindingType: DiBindingType.factory,
            ),
          ],
        ),
        _eventBusGroup,
      ]);

      expect(files.map((f) => f.path), [
        coreDiPath(),
        join(projectRoot, _authTemplate),
      ]);

      final coreDi = files[0].content;
      expect(coreDi, contains('<ICommunicationService>'));
      expect(coreDi, isNot(contains('AuthRepository')));

      final authDi = files[1].content;
      expect(
        authDi,
        contains(
          'getIt.registerFactory<IAuthRepository>(() => AuthRepository());',
        ),
      );
      expect(
        authDi,
        contains(
          "import 'package:test_app/features/auth/auth_repository.dart';",
        ),
      );
      expect(authDi, isNot(contains('ICommunicationService')));

      for (final file in files) {
        expectParses(file.content);
      }
    });
  });
}
