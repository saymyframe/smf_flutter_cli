import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
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
  bool isAsync = false,
  List<ServiceRef> dependsOn = const [],
  FunctionRef? dispose,
  String? instanceName,
}) =>
    DiRegistration(
      type: _type(name),
      create: FactoryRef('create$name', import: _file, deps: deps),
      lifetime: lifetime,
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
      final problems = [
        ..._registration('A', isAsync: true).problems(),
        ..._registration('B', dependsOn: [_service('A')]).problems(),
        ..._registration(
          'C',
          lifetime: DiLifetime.factory,
          dispose: const FunctionRef('disposeC', import: _file),
        ).problems(),
        ..._registration('D', instanceName: '').problems(),
      ];

      expect(problems, [
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

    test('knows a type by its file, whatever prefix imports it', () {
      final issues = _graph([
        _registration('A'),
        DiRegistration(
          type: _type('B'),
          create: FactoryRef(
            'createB',
            import: _file,
            deps: [
              ServiceRef(
                TypeRef('A', import: _file.withPrefix('services')),
              ),
            ],
          ),
        ),
      ]).issues;

      expect(issues, isEmpty);
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

      // Two singletons: each asks whether the other waits.
      final singletons = _graph([
        _registration(
          'A',
          lifetime: DiLifetime.singleton,
          deps: [_service('B')],
        ),
        _registration(
          'B',
          lifetime: DiLifetime.singleton,
          deps: [_service('A')],
        ),
      ]);
      for (final name in ['A', 'B']) {
        expect(
          singletons.dependsOnOf(singletons.registrationOf(_service(name))!),
          isEmpty,
          reason: name,
        );
      }
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
          'Factory',
          lifetime: DiLifetime.factory,
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
      expect(of('Factory'), {DiCapability.instanceName});
      expect(of('Basic', 'x'), {DiCapability.instanceName});
    });
  });

  group('DiCapability', () {
    test('has no factories that take values from their callers', () {
      expect(
        [for (final capability in DiCapability.values) capability.name],
        ['asyncInit', 'dependsOn', 'dispose', 'instanceName'],
      );
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

    test('leaves a service that nobody registers to the template', () {
      final missing = inputOf(
        diRole,
        data: _data([
          _registration(
            'A',
            lifetime: DiLifetime.singleton,
            deps: [_service('Missing')],
          ),
        ]),
      );

      expect(const _Container({}).validate(missing), isEmpty);
      expect(
        diRole.template.validate(missing).single.message,
        contains('needs Missing, which no module registers'),
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

    test('resolves services by type and name, with no other values', () async {
      final rendered = await renderTemplate(diRole);
      final unit =
          parseString(content: rendered.files[DiRole.serviceLocatorFile]!).unit;
      final locator = unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere((c) => c.namePart.typeName.lexeme == 'ServiceLocator');

      expect(
        [
          for (final function
              in unit.declarations.whereType<FunctionDeclaration>())
            '${function.name.lexeme}${function.functionExpression.parameters}',
        ],
        ['resolve({String? instanceName})'],
      );
      expect(
        [
          for (final method
              in locator.body.members.whereType<MethodDeclaration>())
            '${method.name.lexeme}${method.parameters}',
        ],
        ['resolve({String? instanceName})'],
      );
    });
  });

  test('CompositionFile is a rule of the DI role with a file per module', () {
    const rule = CompositionFile('lib/widgets/<id>/<id>_composition.dart');

    expect(rule.role, same(diRole));
    expect(
      rule.pathOf(const ModuleId('card')),
      'lib/widgets/card/card_composition.dart',
    );
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

    const locator = IndexedImport(
      'package:my_app/core/di/service_locator.dart',
    );

    DartFileIndex resolving(String path) => DartFileIndex(
          path: path,
          imports: const [locator],
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

      expect(
        issue.message,
        contains('must require the dependency injection role'),
      );
      expect(issue.origin, const ModuleOrigin(ModuleId('home')));
    });

    test('sees resolving through a prefix of the service locator', () {
      final issues = check(
        {
          screen: const DartFileIndex(
            path: screen,
            imports: [
              IndexedImport(
                'package:my_app/core/di/service_locator.dart',
                prefix: 'di',
              ),
            ],
            invocations: [
              IndexedInvocation('resolve', target: 'di'),
              IndexedInvocation('resolve', target: 'di.serviceLocator'),
            ],
          ),
          infrastructure: const DartFileIndex(
            path: infrastructure,
            imports: [
              IndexedImport('../di/service_locator.dart', prefix: 'locator'),
            ],
            memberAccesses: [IndexedMemberAccess('locator', 'serviceLocator')],
          ),
        },
        homeRequires: {diRole},
      );

      expect(issues.map((issue) => issue.path), [screen, infrastructure]);
    });

    test('rejects resolving anywhere else', () {
      final issues = check(
        {
          screen: const DartFileIndex(
            path: screen,
            imports: [locator],
            references: [IndexedReference('resolve')],
          ),
          infrastructure: const DartFileIndex(
            path: infrastructure,
            imports: [IndexedImport('../di/service_locator.dart')],
            invocations: [
              IndexedInvocation('resolve', target: 'serviceLocator'),
            ],
            references: [IndexedReference('serviceLocator')],
          ),
          'lib/core/auth/other.dart': const DartFileIndex(
            path: 'lib/core/auth/other.dart',
            imports: [locator],
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

    test('ignores names that are not of the service locator', () {
      expect(
        check({
          infrastructure: const DartFileIndex(
            path: infrastructure,
            imports: [IndexedImport('package:my_app/core/auth/api.dart')],
            invocations: [
              IndexedInvocation('resolve'),
              IndexedInvocation('resolve', target: 'client'),
            ],
            references: [IndexedReference('serviceLocator')],
          ),
        }),
        isEmpty,
      );
    });

    test('lets the provider of the DI role use its locator', () {
      final issues = diRole.checkStructure(
        const StructuralRuleRequest(
          hook: RoleHookRequest(
            data: [],
            presentRoles: {diRole},
            context: testContext,
          ),
          files: {
            DiRole.dependenciesFile: DartFileIndex(
              path: DiRole.dependenciesFile,
              imports: [IndexedImport('service_locator.dart')],
              references: [IndexedReference('serviceLocator')],
            ),
          },
          owners: {
            DiRole.dependenciesFile: ModuleOrigin(ModuleId('container')),
          },
          modules: [
            ModuleDescriptor(
              id: ModuleId('container'),
              description: 'Container',
              kind: ModuleKinds.infrastructure,
              providers: [_Container({})],
            ),
          ],
        ),
      );

      expect(issues, isEmpty);
    });

    group('for a kind of its own', () {
      const card = ModuleOrigin(ModuleId('card'));
      const cardComposition = 'lib/widgets/card/card_composition.dart';
      const cardWidget = 'lib/widgets/card/card.dart';
      const featureComposition = 'lib/features/card/card_composition.dart';

      List<SmfIssue> checkKind(ModuleKind kind) => diRole.checkStructure(
            StructuralRuleRequest(
              hook: const RoleHookRequest(
                data: [],
                presentRoles: {diRole},
                context: testContext,
              ),
              files: {
                for (final path in [
                  cardComposition,
                  cardWidget,
                  featureComposition,
                ])
                  path: resolving(path),
              },
              owners: const {
                cardComposition: card,
                cardWidget: card,
                featureComposition: card,
              },
              modules: [
                ModuleDescriptor(
                  id: card.module,
                  description: 'Card',
                  kind: kind,
                  requires: const {diRole},
                ),
              ],
            ),
          );

      test('lets a module resolve only in the file its kind names', () {
        const widget = ModuleKind(
          id: 'widget',
          label: 'Widgets',
          roleRules: [
            CompositionFile('lib/widgets/<id>/<id>_composition.dart'),
          ],
        );

        final issues = checkKind(widget);

        expect(
          issues.map((issue) => issue.path),
          [cardWidget, featureComposition],
        );
        expect(
          issues.map((issue) => issue.message),
          everyElement(contains('only $cardComposition may')),
        );
      });

      test('lets a module of a kind without the rule resolve nowhere', () {
        final issues = checkKind(plainKind);

        expect(
          issues.map((issue) => issue.path),
          [cardComposition, cardWidget, featureComposition],
        );
        expect(
          issues.map((issue) => issue.message),
          everyElement(contains('only the composition file of a feature may')),
        );
      });
    });
  });

  group('the structural rule di.factories', () {
    const file = ImportRef.app('core/auth/auth.dart');
    const path = 'lib/core/auth/auth.dart';
    const service = TypeRef('AuthService', import: file);
    const client = TypeRef('Client', import: file);

    List<SmfIssue> check(String source, List<DiRegistration> registrations) =>
        diRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: [
                for (final registration in registrations)
                  dataOf(diRole, registration, module: 'auth'),
              ],
              presentRoles: {diRole},
              context: testContext,
            ),
            files: {path: _index(path, source)},
          ),
        );

    test('accepts factories that take the dependencies', () {
      expect(
        check(
          'AuthService createAuth(Client client, [int? n]) => AuthService();\n'
          'Client createClient() => Client();\n'
          'void close(AuthService service) {}\n',
          const [
            DiRegistration(
              type: client,
              create: FactoryRef('createClient', import: file),
            ),
            DiRegistration(
              type: service,
              create: FactoryRef(
                'createAuth',
                import: file,
                deps: [ServiceRef(client)],
              ),
              lifetime: DiLifetime.factory,
            ),
            DiRegistration(
              type: TypeRef('Session', import: file),
              create: FactoryRef(
                'createSession',
                import: ImportRef('package:auth/auth.dart'),
              ),
              dispose: FunctionRef('close', import: file),
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('rejects missing factories and wrong arities', () {
      final issues = check(
        'AuthService createAuth() => AuthService();\n'
        'void close() {}\n',
        const [
          DiRegistration(
            type: service,
            create: FactoryRef(
              'createAuth',
              import: file,
              deps: [ServiceRef(client)],
            ),
            dispose: FunctionRef('close', import: file),
          ),
          DiRegistration(
            type: client,
            create: FactoryRef('createClient', import: file),
          ),
        ],
      );

      expect(
        [for (final issue in issues) issue.message],
        [
          contains('createAuth() in $path must accept 1 positional'),
          contains('close() in $path must accept 1 positional'),
          contains('does not declare function createClient()'),
        ],
      );
      expect(issues.first.origin, const ModuleOrigin(ModuleId('auth')));
      expect(issues.first.path, path);
    });

    test('tells a factory its dependencies and a dispose function its service',
        () {
      final issues = check(
        'AuthService createAuth() => AuthService();\n'
        'void close() {}\n'
        'void shut(Client client, Client other) {}\n',
        const [
          DiRegistration(
            type: service,
            create: FactoryRef(
              'createAuth',
              import: file,
              deps: [ServiceRef(client)],
            ),
            dispose: FunctionRef('close', import: file),
          ),
          DiRegistration(
            type: client,
            create: FactoryRef('createClient', import: file),
            dispose: FunctionRef('shut', import: file),
          ),
          DiRegistration(
            type: TypeRef('Session', import: file),
            create: FactoryRef(
              'createSession',
              import: ImportRef('package:auth/auth.dart'),
            ),
            dispose: FunctionRef('release', import: file),
          ),
        ],
      );

      expect(
        [for (final issue in issues) issue.message],
        [
          contains('createAuth() in $path must accept 1 positional'),
          contains('close() in $path must accept 1 positional'),
          contains('does not declare function createClient()'),
          contains('shut() in $path must not require more than 1 positional'),
          contains('does not declare function release()'),
        ],
      );
      const ofFactory =
          'The pipeline calls it with the dependencies of the registration.';
      final ofDispose = allOf(
        contains('with the service'),
        isNot(contains('dependencies')),
      );
      expect(
        [for (final issue in issues) issue.hint],
        [ofFactory, ofDispose, ofFactory, ofDispose, ofDispose],
      );
    });
  });

  group('the structural rule di.registrations_rendered', () {
    const auth = ImportRef.app('core/auth/auth.dart');
    const authPath = 'lib/core/auth/auth.dart';
    const session = ImportRef('package:session/session.dart');
    const setupPath = 'lib/core/auth/setup.dart';
    const helpersPath = 'lib/core/di/registrations.dart';
    const container = ModuleOrigin(ModuleId('container'));
    const registrant = ModuleOrigin(ModuleId('auth'));

    const registrations = [
      DiRegistration(
        type: TypeRef('AuthService', import: auth),
        create: FactoryRef('createAuth', import: auth),
      ),
      DiRegistration(
        type: TypeRef('Client', import: auth),
        create: FactoryRef('createClient', import: auth),
        dispose: FunctionRef('closeClient', import: auth),
      ),
      DiRegistration(
        type: TypeRef('Session', import: session),
        create: FactoryRef('createSession', import: session),
      ),
    ];

    /// The file of the module auth with the functions of the
    /// registrations, and another of its files that calls them all, which
    /// renders no registration, since only the provider of the role does.
    final authFiles = {
      authPath: const DartFileIndex(
        path: authPath,
        declarations: [
          IndexedDeclaration(
            name: 'createAuth',
            kind: DeclarationKind.function,
          ),
          IndexedDeclaration(
            name: 'createClient',
            kind: DeclarationKind.function,
          ),
          IndexedDeclaration(
            name: 'closeClient',
            kind: DeclarationKind.function,
            parameters: [
              IndexedParameter(
                'client',
                kind: ParameterKind.requiredPositional,
              ),
            ],
          ),
        ],
      ),
      setupPath: const DartFileIndex(
        path: setupPath,
        imports: [
          IndexedImport('auth.dart'),
          IndexedImport('package:session/session.dart'),
        ],
        invocations: [
          IndexedInvocation('createAuth'),
          IndexedInvocation('createClient'),
          IndexedInvocation('closeClient'),
          IndexedInvocation('createSession'),
        ],
      ),
    };

    /// The issues of the rules of the role in an app where the module auth
    /// registers [registrations] and the module container, the provider of
    /// the role unless [withProvider] is `false`, generates [files].
    List<SmfIssue> check(
      List<DartFileIndex> files, {
      bool withProvider = true,
    }) =>
        diRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: [
                for (final registration in registrations)
                  dataOf(diRole, registration, module: 'auth'),
              ],
              presentRoles: {diRole},
              context: testContext,
            ),
            files: {
              ...authFiles,
              for (final file in files) file.path: file,
            },
            owners: {
              authPath: registrant,
              setupPath: registrant,
              for (final file in files) file.path: container,
            },
            modules: [
              if (withProvider)
                ModuleDescriptor(
                  id: container.module,
                  description: 'Container',
                  kind: ModuleKinds.infrastructure,
                  providers: const [
                    _Container({DiCapability.dispose}),
                  ],
                ),
              const ModuleDescriptor(
                id: ModuleId('auth'),
                description: 'Auth',
                kind: ModuleKinds.infrastructure,
              ),
            ],
          ),
        );

    /// The file of the provider with `registerDependencies()`, which
    /// imports the file of auth and the library of session with the
    /// prefixes `di0` and `di1`, and calls [calls] and reads [accesses]
    /// through them.
    DartFileIndex dependencies({
      List<IndexedInvocation> calls = const [],
      List<IndexedMemberAccess> accesses = const [],
    }) =>
        DartFileIndex(
          path: DiRole.dependenciesFile,
          imports: const [
            IndexedImport('package:my_app/core/auth/auth.dart', prefix: 'di0'),
            IndexedImport('package:session/session.dart', prefix: 'di1'),
          ],
          invocations: calls,
          memberAccesses: accesses,
        );

    /// Another file of the provider, which imports the file of auth by a
    /// relative path and without a prefix, and tears off createClient.
    const helpers = DartFileIndex(
      path: helpersPath,
      imports: [IndexedImport('../auth/auth.dart')],
      references: [IndexedReference('createClient')],
    );

    test('is a structural rule of the role', () {
      expect(
        diRole.structuralRules.map((rule) => rule.id),
        [
          'di.resolve_in_composition_files',
          'di.factories',
          'di.registrations_rendered',
        ],
      );
    });

    test(
        'accepts a provider whose files call or tear off every factory and '
        'dispose function', () {
      expect(
        check([
          dependencies(
            calls: const [
              IndexedInvocation('createAuth', target: 'di0'),
              IndexedInvocation('createSession', target: 'di1'),
            ],
            accesses: const [IndexedMemberAccess('di0', 'closeClient')],
          ),
          helpers,
        ]),
        isEmpty,
      );
    });

    test(
        'reports a registration whose factory no file of the provider '
        'calls or tears off', () {
      final issue = check([
        dependencies(
          calls: const [IndexedInvocation('createAuth', target: 'di0')],
          accesses: const [IndexedMemberAccess('di0', 'closeClient')],
        ),
        helpers,
      ]).single;

      expect(
        issue.message,
        'The provider of the dependency injection role does not render the '
        'registration of Session: none of its files calls or tears off its '
        'factory createSession() of package:session/session.dart.',
      );
      expect(issue.hint, contains('DiRole.graphOf()'));
      expect(issue.origin, registrant);
      expect(issue.path, DiRole.dependenciesFile);
    });

    test('reports a dispose function that no file of the provider uses', () {
      final issue = check([
        dependencies(
          calls: const [
            IndexedInvocation('createAuth', target: 'di0'),
            IndexedInvocation('createSession', target: 'di1'),
          ],
        ),
        helpers,
      ]).single;

      expect(
        issue.message,
        'The provider of the dependency injection role does not render the '
        'registration of Client: none of its files calls or tears off its '
        'dispose function closeClient() of lib/core/auth/auth.dart.',
      );
      expect(issue.origin, registrant);
    });

    test('counts only the functions of the files the registrations name', () {
      final issues = check([
        const DartFileIndex(
          path: DiRole.dependenciesFile,
          imports: [
            IndexedImport('package:my_app/core/other.dart'),
            IndexedImport('package:my_app/core/auth/auth.dart', prefix: 'di0'),
          ],
          invocations: [
            // Of other.dart, which the file imports without a prefix.
            IndexedInvocation('createAuth'),
            // Of an object, not of an import.
            IndexedInvocation('createClient', target: 'client'),
            IndexedInvocation('closeClient', target: 'di0'),
            // Through a prefix that the file does not import.
            IndexedInvocation('createSession', target: 'di1'),
          ],
        ),
      ]);

      expect(
        [for (final issue in issues) issue.message],
        [
          contains('its factory createAuth()'),
          contains('its factory createClient()'),
          contains('its factory createSession()'),
        ],
      );
    });

    test(
        'checks the files of a provider among the modules, and nothing '
        'without one', () {
      expect(check(const []), hasLength(4));
      expect(check(const [], withProvider: false), isEmpty);
    });
  });
}

/// The index of [source] as the harness builds it, by hand: only the
/// top-level functions with their positional parameters.
DartFileIndex _index(String path, String source) {
  final functions = RegExp(r'^\w+ (\w+)\(([^)]*)\)', multiLine: true);
  return DartFileIndex(
    path: path,
    declarations: [
      for (final match in functions.allMatches(source))
        IndexedDeclaration(
          name: match.group(1)!,
          kind: DeclarationKind.function,
          parameters: [
            for (final parameter in _parameters(match.group(2)!)) parameter,
          ],
        ),
    ],
  );
}

List<IndexedParameter> _parameters(String list) {
  final parameters = <IndexedParameter>[];
  var optional = false;
  for (var part in list.split(',')) {
    part = part.trim();
    if (part.isEmpty) continue;
    if (part.startsWith('[')) {
      optional = true;
      part = part.substring(1);
    }
    part = part.replaceAll(']', '').trim();
    parameters.add(
      IndexedParameter(
        part.split(' ').last,
        kind: optional
            ? ParameterKind.optionalPositional
            : ParameterKind.requiredPositional,
      ),
    );
  }
  return parameters;
}
