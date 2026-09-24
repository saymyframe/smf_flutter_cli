import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/file_writer.dart';
import 'package:smf_flutter_cli/generators/dsl_generator.dart';
import 'package:smf_flutter_cli/prompts/prompt.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';
import '../helpers/test_modules.dart';

class _RecordingStrategy implements FileWriteStrategy {
  final List<GeneratedFile> written = [];

  @override
  Future<void> write(GeneratedFile file) async => written.add(file);
}

DiDependencyGroup _diGroup(String type) => DiDependencyGroup(
      diDependencies: [
        DiDependency(
          abstractType: type,
          implementation: '${type}Impl',
          bindingType: DiBindingType.singleton,
        ),
      ],
      scope: DiScope.core,
      imports: const [],
    );

RouteGroup _routes(List<BaseRoute> routes, {String? initialRoute}) =>
    RouteGroup(routes: routes, initialRoute: initialRoute);

NestedRoute _nested(String shellId, String childPath) => NestedRoute(
      shellLink: RouteShellLink(shellId),
      children: [Route(path: childPath)],
    );

void main() {
  group('DslGenerator', () {
    late MockLogger logger;
    late _RecordingStrategy recorder;

    setUp(() {
      logger = MockLogger();
      recorder = _RecordingStrategy();
    });

    DslGenerator buildGenerator({String? initialRoute}) => DslGenerator(
          CompositeWriteStrategy([recorder]),
          cliContext: CliContext(
            name: 'demo',
            selectedModules: const [],
            outputDirectory: '/out',
            logger: logger,
            strictMode: StrictMode.lenient,
            moduleResolver: const ModuleDependencyResolver(),
            initialRoute: initialRoute,
          ),
        );

    test('passes DI and route groups of all modules to DSL generators',
        () async {
      final plainRoutes = _routes([const Route(path: '/plain')]);
      final dslRoutes = _routes([const Route(path: '/dsl')]);
      final plainDi = _diGroup('Plain');
      final dslDi = _diGroup('Dsl');
      final dslModule = DslTestModule('dsl', di: [dslDi], routes: dslRoutes);
      final coreVars = <String, dynamic>{'app_name': 'demo'};

      await buildGenerator(initialRoute: '/home').generate(
        [
          TestModule('plain', di: [plainDi], routes: plainRoutes),
          dslModule,
        ],
        logger,
        coreVars,
        '/project',
      );

      final context = dslModule.receivedContexts.single;
      expect(context.projectRootPath, '/project');
      expect(context.mustacheVariables, same(coreVars));
      expect(context.logger, same(logger));
      expect(context.diGroups, [plainDi, dslDi]);
      expect(context.routeGroups, [plainRoutes, dslRoutes]);
      expect(context.initialRoute, '/home');
      expect(context.shellDeclarations, isEmpty);
    });

    test('invokes every DSL-aware module with the same context', () async {
      final first = DslTestModule('first');
      final second = DslTestModule('second');

      await buildGenerator().generate(
        [first, TestModule('plain'), second],
        logger,
        <String, dynamic>{},
        '/project',
      );

      expect(first.receivedContexts, hasLength(1));
      expect(second.receivedContexts, hasLength(1));
      expect(
        first.receivedContexts.single,
        same(second.receivedContexts.single),
      );
    });

    test('writes every generated file through the strategy in order', () async {
      const routerFile = GeneratedFile('/project/lib/router.dart', 'router');
      const diFile = GeneratedFile('/project/lib/di.dart', 'di');
      const eventsFile = GeneratedFile('/project/lib/events.dart', 'events');

      await buildGenerator().generate(
        [
          DslTestModule('a', onGenerate: (_) => [routerFile, diFile]),
          DslTestModule('b', onGenerate: (_) => [eventsFile]),
        ],
        logger,
        <String, dynamic>{},
        '/project',
      );

      expect(recorder.written, [routerFile, diFile, eventsFile]);
    });

    test('writes nothing when no module is DSL-aware', () async {
      await buildGenerator().generate(
        [
          TestModule('plain', routes: _routes([const Route(path: '/a')])),
        ],
        logger,
        <String, dynamic>{},
        '/project',
      );

      expect(recorder.written, isEmpty);
    });

    test('falls back to /noModules when no initial route was chosen', () async {
      final dslModule = DslTestModule('dsl');

      await buildGenerator().generate(
        [dslModule],
        logger,
        <String, dynamic>{},
        '/project',
      );

      expect(dslModule.receivedContexts.single.initialRoute, '/noModules');
    });

    test('resolves each shell referenced by nested routes once', () async {
      final dslModule = DslTestModule(
        'dsl',
        routes: _routes([_nested('main-tabs', '/feed')]),
      );

      await buildGenerator().generate(
        [
          TestModule('other', routes: _routes([_nested('main-tabs', '/me')])),
          dslModule,
        ],
        logger,
        <String, dynamic>{},
        '/project',
      );

      final shells = dslModule.receivedContexts.single.shellDeclarations;
      expect(shells, [same(ShellRegistry.resolve('main-tabs'))]);
    });

    test('throws for a nested route pointing to an unknown shell', () async {
      final dslModule = DslTestModule(
        'dsl',
        routes: _routes([_nested('no-such-shell', '/feed')]),
      );

      await expectLater(
        buildGenerator().generate(
          [dslModule],
          logger,
          <String, dynamic>{},
          '/project',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('no-such-shell'),
          ),
        ),
      );
      expect(dslModule.receivedContexts, isEmpty);
    });
  });
}
