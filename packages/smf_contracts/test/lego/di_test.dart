import 'package:smf_contracts/lego.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

const _file = ImportRef.app('core/services.dart');

TypeRef _type(String name) => TypeRef(name, import: _file);

ServiceRef _service(String name, {String? instanceName}) =>
    ServiceRef(_type(name), instanceName: instanceName);

DiRegistration _registration(
  String name, {
  DiLifetime lifetime = DiLifetime.lazySingleton,
  List<ServiceRef> deps = const [],
  List<TypeRef> params = const [],
  bool isAsync = false,
  List<ServiceRef> dependsOn = const [],
  FunctionRef? dispose,
  String? instanceName,
}) =>
    DiRegistration(
      type: _type(name),
      create: FactoryRef('create$name', import: _file, deps: deps),
      lifetime: lifetime,
      params: params,
      isAsync: isAsync,
      dependsOn: dependsOn,
      dispose: dispose,
      instanceName: instanceName,
    );

List<RoleData<Object>> _data(List<DiRegistration> registrations) => [
      for (final (index, registration) in registrations.indexed)
        dataOf(diRole, registration, module: 'module_$index'),
    ];

DiGraph _graph(List<DiRegistration> registrations) =>
    diRole.graphOf(inputOf(diRole, data: _data(registrations)));

final class _Container extends DiProvider {
  const _Container(this.capabilities);

  @override
  final Set<DiCapability> capabilities;
}

void main() {
  group('DiRegistration', () {
    test('registers a lazy singleton by default, keyed by type and name', () {
      final registration = _registration('A', instanceName: 'main');

      expect(registration.lifetime, DiLifetime.lazySingleton);
      expect(registration.key, _service('A', instanceName: 'main'));
      expect(registration.problems(), isEmpty);
      expect('$registration', 'registration of A "main"');
    });

    test('rejects features that its lifetime does not allow', () {
      expect(
        _registration(
          'A',
          params: [const TypeRef('int'), const TypeRef('int')],
          lifetime: DiLifetime.factory,
        ).problems(),
        isEmpty,
      );
      final problems = [
        ..._registration('B', params: [const TypeRef('int')]).problems(),
        ..._registration(
          'C',
          lifetime: DiLifetime.factory,
          params: const [TypeRef('int'), TypeRef('int'), TypeRef('int')],
        ).problems(),
        ..._registration('D', isAsync: true).problems(),
        ..._registration('E', dependsOn: [_service('A')]).problems(),
        ..._registration(
          'F',
          lifetime: DiLifetime.factory,
          dispose: const FunctionRef('disposeF', import: _file),
        ).problems(),
        ..._registration('G', instanceName: '').problems(),
      ];

      expect(problems, [
        contains('which only a factory can'),
        contains('takes 3 parameters'),
        contains('which only a singleton can be'),
        contains('which only a singleton can do'),
        contains('does not keep to dispose of'),
        contains('empty instance name'),
      ]);
    });

    test('reports the problems of its references', () {
      expect(
        const DiRegistration(
          type: TypeRef('List<int>'),
          create: FactoryRef('create', import: ImportRef('lib/x.dart')),
          dispose: FunctionRef('_dispose', import: _file),
        ).problems(),
        hasLength(3),
      );
    });
  });

  group('DiGraph.issues', () {
    test('accepts a valid graph', () {
      final graph = _graph([
        _registration('A'),
        _registration('B', deps: [_service('A')]),
      ]);

      expect(graph.issues, isEmpty);
      expect(graph.registrationOf(_service('B'))?.type, _type('B'));
      expect(graph.registrationOf(_service('C')), isNull);
    });

    test('names the contributor of every problem', () {
      final issues = _graph([
        _registration('A'),
        _registration('A', isAsync: true),
      ]).issues;

      expect(issues, hasLength(2));
      expect(issues.first.message, contains('only a singleton'));
      expect(issues.last.message, contains('A is registered twice'));
      expect(issues.last.message, contains('module_0'));
      expect(
        issues.map((issue) => issue.origin),
        everyElement(const ModuleOrigin(ModuleId('module_1'))),
      );
    });

    test('rejects services that nobody registers', () {
      final issues = _graph([
        _registration(
          'A',
          lifetime: DiLifetime.singleton,
          deps: [_service('B', instanceName: 'x')],
          dependsOn: [_service('C')],
        ),
      ]).issues;

      expect(issues, [
        isA<SmfIssue>().having(
          (issue) => issue.message,
          'message',
          contains('needs B "x", which no module registers'),
        ),
        isA<SmfIssue>().having(
          (issue) => issue.message,
          'message',
          contains('needs C, which no module registers'),
        ),
      ]);
    });

    test('rejects cycles', () {
      final issues = _graph([
        _registration('A', deps: [_service('B')]),
        _registration('B', deps: [_service('C')]),
        _registration('C', deps: [_service('A')]),
        _registration('D', deps: [_service('D')]),
      ]).issues;

      expect(
        issues.map((issue) => issue.message),
        [
          'The services A -> B -> C -> A need each other in a cycle.',
          'The services D -> D need each other in a cycle.',
        ],
      );
    });

    test('rejects waiting for a service that is ready once registered', () {
      final issues = _graph([
        _registration('A', lifetime: DiLifetime.singleton),
        _registration('B', lifetime: DiLifetime.singleton, isAsync: true),
        _registration(
          'C',
          lifetime: DiLifetime.singleton,
          dependsOn: [_service('A'), _service('B')],
        ),
      ]).issues;

      expect(issues.single.message, contains('waits for A, which is not'));
      expect(issues.single.origin, const ModuleOrigin(ModuleId('module_2')));
    });
  });

  group('DiGraph.ordered', () {
    test('registers every service after the services it needs', () {
      final ordered = _graph([
        _registration('C', deps: [_service('B')]),
        _registration('A'),
        _registration('B', deps: [_service('A')]),
        _registration('D', lifetime: DiLifetime.singleton, isAsync: true),
        _registration(
          'E',
          lifetime: DiLifetime.singleton,
          dependsOn: [_service('D')],
        ),
        _registration('A'),
      ]).ordered;

      expect([for (final r in ordered) r.type.name], ['A', 'B', 'C', 'D', 'E']);
    });

    test('keeps the services of a cycle', () {
      final ordered = _graph([
        _registration('A', deps: [_service('B')]),
        _registration('B', deps: [_service('A')]),
      ]).ordered;

      expect([for (final r in ordered) r.type.name], ['B', 'A']);
    });
  });

  group('DiGraph.dependsOnOf', () {
    final graph = _graph([
      _registration('Async', lifetime: DiLifetime.singleton, isAsync: true),
      _registration('Eager', lifetime: DiLifetime.singleton),
      _registration('Lazy', deps: [_service('Async')]),
      _registration(
        'Factory',
        lifetime: DiLifetime.factory,
        deps: [
          _service('Lazy'),
        ],
      ),
      _registration(
        'Direct',
        lifetime: DiLifetime.singleton,
        deps: [_service('Async'), _service('Eager')],
      ),
      _registration(
        'Through',
        lifetime: DiLifetime.singleton,
        deps: [_service('Factory')],
      ),
      _registration(
        'Waits',
        lifetime: DiLifetime.singleton,
        deps: [_service('Through')],
        dependsOn: [_service('Direct')],
      ),
      _registration(
        'Plain',
        lifetime: DiLifetime.singleton,
        deps: [
          _service('Eager'),
        ],
      ),
    ]);

    DiRegistration registration(String name) =>
        graph.registrationOf(_service(name))!;

    test('makes a singleton wait for the asynchronous services it takes', () {
      expect(graph.dependsOnOf(registration('Direct')), {_service('Async')});
      expect(graph.isAwaitable(registration('Direct')), isTrue);
    });

    test('follows lazy singletons and factories to asynchronous services', () {
      expect(graph.dependsOnOf(registration('Through')), {_service('Async')});
    });

    test('adds the services a singleton waits for explicitly', () {
      expect(graph.dependsOnOf(registration('Waits')), {
        _service('Direct'),
        _service('Through'),
      });
    });

    test('lets lazy singletons, factories and ready singletons not wait', () {
      for (final name in ['Lazy', 'Factory', 'Eager', 'Plain', 'Async']) {
        expect(graph.dependsOnOf(registration(name)), isEmpty, reason: name);
      }
      expect(graph.isAwaitable(registration('Async')), isTrue);
      expect(graph.isAwaitable(registration('Lazy')), isFalse);
      expect(graph.isAwaitable(registration('Plain')), isFalse);
    });

    test('knows whether the container must wait until it is ready', () {
      expect(graph.needsAllReady, isTrue);
      expect(_graph([_registration('A')]).needsAllReady, isFalse);
    });

    test('terminates on a cycle', () {
      final cyclic = _graph([
        _registration(
          'A',
          lifetime: DiLifetime.singleton,
          deps: [
            _service('B'),
          ],
        ),
        _registration('B', deps: [_service('A')]),
      ]);

      expect(
        cyclic.dependsOnOf(cyclic.registrationOf(_service('A'))!),
        isEmpty,
      );
    });
  });

  group('DiGraph.capabilitiesOf', () {
    test('lists what the container needs beyond the basics', () {
      final graph = _graph([
        _registration('Basic', deps: [_service('Async')]),
        _registration('Async', lifetime: DiLifetime.singleton, isAsync: true),
        _registration(
          'All',
          lifetime: DiLifetime.singleton,
          deps: [_service('Async')],
          dispose: const FunctionRef('disposeAll', import: _file),
        ),
        _registration(
          'Params',
          lifetime: DiLifetime.factory,
          params: [const TypeRef('int')],
          deps: [_service('Basic', instanceName: 'x')],
        ),
        _registration('Basic', instanceName: 'x'),
      ]);

      Set<DiCapability> of(String name, [String? instanceName]) =>
          graph.capabilitiesOf(
            graph.registrationOf(_service(name, instanceName: instanceName))!,
          );

      expect(of('Basic'), isEmpty);
      expect(of('Async'), {DiCapability.asyncInit});
      expect(of('All'), {DiCapability.dependsOn, DiCapability.dispose});
      expect(of('Params'), {
        DiCapability.factoryWithParams,
        DiCapability.instanceName,
      });
      expect(of('Basic', 'x'), {DiCapability.instanceName});
    });
  });

  group('DiProvider', () {
    final input = inputOf(
      diRole,
      data: _data([
        _registration('A', lifetime: DiLifetime.singleton, isAsync: true),
        _registration(
          'B',
          lifetime: DiLifetime.singleton,
          deps: [
            _service('A'),
          ],
        ),
      ]),
    );

    test('is a provider of the DI role', () {
      expect(const _Container({}).role, same(diRole));
    });

    test('accepts registrations that its container supports', () {
      expect(
        const _Container({DiCapability.asyncInit, DiCapability.dependsOn})
            .validate(input),
        isEmpty,
      );
    });

    test('rejects registrations that need what its container lacks', () {
      final issues = const _Container({}).validate(input);

      expect(issues, hasLength(2));
      expect(issues.first.message, contains('needs asyncInit'));
      expect(issues.first.origin, const ModuleOrigin(ModuleId('module_0')));
      expect(issues.last.message, contains('needs dependsOn'));
      expect(issues.last.origin, const ModuleOrigin(ModuleId('module_1')));
    });
  });

  group('the DI template', () {
    final template = diRole.template;

    test('contributes its brick and registers the dependencies at start', () {
      final contributions = template.contribute(testContext);
      final start = contributions.whereType<SocketContribution>().single;

      expect(contributions.whereType<BrickContribution>(), hasLength(1));
      expect(start.socket, AppEntryRole.bootstrapDi);
      expect(start.fragment!.code, 'await registerDependencies();');
      expect(start.fragment!.imports, [
        const ImportRef.app('core/di/dependencies.dart'),
      ]);
    });

    test('validates the graph of the registrations', () {
      expect(
        template.validate(
          inputOf(diRole, data: _data([_registration('A', isAsync: true)])),
        ),
        hasLength(1),
      );
    });

    test('generates the service locator', () async {
      final rendered = await renderTemplate(diRole);
      final code = rendered.files[DiRole.serviceLocatorFile]!;

      expectParses(code);
      expect(code, contains('abstract interface class ServiceLocator'));
      expect(
        code,
        contains(
          'final ServiceLocator serviceLocator = createServiceLocator();',
        ),
      );
      expect(
        code,
        contains('T resolve<T extends Object>({String? instanceName})'),
      );
      expect(rendered.elsewhere.single.socket, AppEntryRole.bootstrapDi);
    });
  });

  group('the structural rule di.resolve_in_composition_files', () {
    const composition = 'lib/features/home/home_composition.dart';
    const screen = 'lib/features/home/home_screen.dart';
    const infrastructure = 'lib/core/auth/auth.dart';

    List<SmfIssue> check(
      Map<String, DartFileIndex> files, {
      Set<Role> homeRequires = const {},
    }) =>
        diRole.checkStructure(
          StructuralRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {diRole},
              context: testContext,
            ),
            files: files,
            owners: {
              composition: const ModuleOrigin(ModuleId('home')),
              screen: const ModuleOrigin(
                ModuleId('home'),
                variant: ModuleId('bloc'),
              ),
              infrastructure: const ModuleOrigin(ModuleId('auth')),
              'lib/core/auth/other.dart': const ModuleOrigin(ModuleId('auth')),
              DiRole.serviceLocatorFile: const RoleTemplateOrigin(diRole),
            },
            modules: [
              ModuleDescriptor(
                id: const ModuleId('home'),
                description: 'Home',
                kind: ModuleKinds.feature,
                requires: homeRequires,
              ),
              const ModuleDescriptor(
                id: ModuleId('auth'),
                description: 'Auth',
                kind: ModuleKinds.infrastructure,
              ),
            ],
          ),
        );

    DartFileIndex resolving(String path) => DartFileIndex(
          path: path,
          invocations: const [
            IndexedInvocation('resolve', typeArguments: ['AuthService']),
          ],
        );

    test('lets the composition file of a feature that requires DI resolve', () {
      expect(
        check(
          {
            composition: resolving(composition),
            DiRole.serviceLocatorFile: resolving(DiRole.serviceLocatorFile),
            screen: const DartFileIndex(
              path: screen,
              invocations: [IndexedInvocation('resolve', target: 'uri')],
            ),
          },
          homeRequires: {diRole},
        ),
        isEmpty,
      );
    });

    test('rejects resolving in a feature that only uses DI', () {
      final issue = check({composition: resolving(composition)}).single;

      expect(issue.message, contains('must require the DI role'));
      expect(issue.origin, const ModuleOrigin(ModuleId('home')));
    });

    test('rejects resolving anywhere else', () {
      final issues = check(
        {
          screen: const DartFileIndex(
            path: screen,
            references: [IndexedReference('resolveWith')],
          ),
          infrastructure: const DartFileIndex(
            path: infrastructure,
            memberAccesses: [IndexedMemberAccess('serviceLocator', 'resolve')],
          ),
          'lib/core/auth/other.dart': const DartFileIndex(
            path: 'lib/core/auth/other.dart',
            references: [IndexedReference('serviceLocator')],
          ),
        },
        homeRequires: {diRole},
      );

      expect(issues, hasLength(3));
      expect(issues.first.message, contains('only $composition may'));
      expect(
        issues.last.message,
        contains('only the composition file of a feature may'),
      );
      expect(issues[1].path, infrastructure);
      expect(issues.last.path, 'lib/core/auth/other.dart');
    });
  });
}
