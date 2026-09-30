@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/bundles/firebase_analytics_bundle.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/navigation.dart';

/// The modules of the tests: flutter_core, which creates the app,
/// firebase_core, which this module depends on, this module, get_it, a DI
/// container, which registers the service in the apps that have it, and
/// go_router, a router, which tells the listener of the module about the
/// screen the user sees in the apps that have it.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  FirebaseCoreModule(),
  FirebaseAnalyticsModule(),
  GetItModule(),
  GoRouterModule(),
];

/// The modules of the apps with a main navigation: those of [_modules], two
/// features whose routes are destinations of the main navigation, one whose
/// route is not, and a layout.
const List<SmfModule> _navigation = [
  ..._modules,
  TestFeature('inbox'),
  TestFeature('search'),
  TestFeature('about', destination: false),
  TestLayout(),
];

/// The path of the file of the module.
const _implementation = 'lib/core/analytics/firebase_analytics_service.dart';

/// The listener of the screen the user sees that the module gives the
/// router: a function of the file of the module.
const _listener = 'logFirebaseScreenView';

/// The function [_listener] as the analyzer prints its declaration.
final String _expectedListener = parseString(
  content: r'''
void logFirebaseScreenView(String? route, String location) {
  final name = route ?? (Uri.parse(location).path == '/' ? '/' : null);
  if (name == null) return;
  FirebaseAnalytics.instance.logScreenView(screenName: name).catchError(
    (Object error) => debugPrint('Firebase Analytics: $error'),
    test: (error) => error is PlatformException,
  );
}
''',
).unit.declarations.single.toSource();

/// The imports of the file of the module that only [_listener] needs.
const _listenerImports = [
  "import 'package:flutter/foundation.dart' show debugPrint;",
  "import 'package:flutter/services.dart' show PlatformException;",
];

/// The statement of firebase_core that initializes Firebase in
/// `bootstrap()`.
const _initializeFirebase = 'await Firebase.initializeApp(options: '
    'DefaultFirebaseOptions.currentPlatform);';

/// The text of the file of [_OtherAnalyticsModule]: a service that records
/// nothing.
const _otherService = '''
import 'analytics_service.dart';

AnalyticsService createOtherAnalyticsService() => const OtherAnalyticsService();

final class OtherAnalyticsService implements AnalyticsService {
  const OtherAnalyticsService();

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {}

  @override
  Future<void> logSignIn({String? method, Map<String, Object>? parameters}) async {}

  @override
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}
''';

/// Another provider of the analytics role, which does not use Firebase, as
/// a service of another vendor would not, and gives the router no listener.
final class _OtherAnalyticsModule extends SmfModule {
  const _OtherAnalyticsModule();

  static const id = ModuleId('other_analytics');

  static const _file = ImportRef.app('core/analytics/other_service.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Analytics of another service',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(analyticsRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundleOf('other_analytics', {
            'lib/core/analytics/other_service.dart': _otherService,
          }),
        ),
        analyticsRole.data(
          const RoleImplementation(
            type: TypeRef('OtherAnalyticsService', import: _file),
            create: FactoryRef('createOtherAnalyticsService', import: _file),
          ),
        ),
      ];
}

/// What the contract harness finds for the app of [modules] of [registry],
/// which has no errors and is rendered.
Future<ContractResult> _resultOf(
  List<ModuleId> modules, {
  List<SmfModule> registry = _modules,
}) async {
  final result = await ContractHarness(ModuleRegistry(registry)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The pubspec [text] as plain maps and lists.
Map<String, Object?> _yamlOf(String text) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(text))! as Map<String, Object?>;
}

/// The pubspec of [app] without the dependency on firebase_analytics.
Map<String, Object?> _pubspecWithoutAnalytics(RenderedApp app) {
  final pubspec = _yamlOf(app.files['pubspec.yaml']!.text);
  final dependencies = {
    ...pubspec['dependencies']! as Map<String, Object?>,
  }..remove('firebase_analytics');
  return {...pubspec, 'dependencies': dependencies};
}

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

/// The registrations of the DI role in the app of [result], as the provider
/// of the role gets them to render.
List<RoleData<DiRegistration>> _registrationsOf(ContractResult result) =>
    diRole.graphOf(diRole.hookInput(result.hook!)).registrations;

/// Checks that [app] is [without] but for the files of the analytics, the
/// dependency on firebase_analytics and the files that the modules
/// [changedBy] generate; its `bootstrap()` included, since the service
/// starts without waiting.
void _expectTheAppWithout(
  RenderedApp app,
  RenderedApp without, {
  Set<ModuleId> changedBy = const {},
}) {
  expect(
    app.files.keys.toSet(),
    {...without.files.keys, AnalyticsRole.file, _implementation},
  );
  expect(
    app.files[AnalyticsRole.file]!.owner,
    const RoleTemplateOrigin(analyticsRole),
  );
  expect(
    app.files[_implementation]!.owner,
    const ModuleOrigin(FirebaseAnalyticsModule.id),
  );
  for (final MapEntry(key: path, value: file) in without.files.entries) {
    if (path == 'pubspec.yaml') continue;
    if (file.owner case ModuleOrigin(:final module)
        when changedBy.contains(module)) {
      continue;
    }
    expect(app.files[path]!.bytes, file.bytes, reason: path);
    expect(app.files[path]!.owner, file.owner, reason: path);
  }
  expect(
    _pubspecWithoutAnalytics(app),
    _yamlOf(without.files['pubspec.yaml']!.text),
  );
}

/// The contributions to [socket] in the app of [result], those of the
/// render hooks of the roles included, in the order they were rendered,
/// each as its contributor and its code: what the provider of the role of
/// the socket renders, whichever module it is.
List<String> _contributionsTo(ContractResult result, SocketRef socket) => [
      for (final collected in result.app!.socketOrders[socket]?.contributions ??
          const <Collected>[])
        _described(collected),
    ];

/// The contribution [collected] to a socket as its contributor and its code.
String _described(Collected collected) {
  final contribution = collected.contribution as SocketContribution;
  return '${collected.origin}: ${contribution.fragment!.code}';
}

/// The listener of the screen of this module among [_contributionsTo] the
/// listeners of the router.
const String _listenerOfModule = 'firebase_analytics: $_listener';

/// Checks that the router of the app of [result] gets what it gets in the
/// app of [without], but for the listener of the screen of this module: the
/// same contributions to every socket of the router role, and the listener
/// after those of the other modules.
void _expectTheRouterWithout(ContractResult result, ContractResult without) {
  Map<SocketRef, List<String>> routerSocketsOf(ContractResult result) => {
        for (final socket in result.app!.socketOrders.keys)
          if (identical(socket.role, routerRole))
            socket: _contributionsTo(result, socket),
      };
  final expected = routerSocketsOf(without);
  expected[RouterRole.screenListeners] = [
    ...?expected[RouterRole.screenListeners],
    _listenerOfModule,
  ];

  expect(routerSocketsOf(result), expected);
}

/// The parsed file at [path] of [app].
CompilationUnit _unitOf(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

/// The code that the modules and the templates of the roles put into the
/// phases of start-up in the app of [result], phase after phase, each as its
/// contributor and its code: what `bootstrap()` runs, into which the
/// provider of the app entry renders the phases, whichever module it is.
List<String> _startUpOf(ContractResult result) => [
      for (final phase in const [
        AppEntryRole.bootstrapEarly,
        AppEntryRole.bootstrapPlatform,
        AppEntryRole.bootstrapDi,
        AppEntryRole.bootstrapLate,
      ])
        ..._contributionsTo(result, phase),
    ];

/// The factories of the implementations that the analytics service of the
/// app in [app] forwards to, in the order of the list of the services of
/// the template of the role, which creates each on its own with
/// `_createAlone(name, factory)`; the code of any other element.
List<String> _servicesOf(RenderedApp app) {
  final services = _unitOf(app, AnalyticsRole.file)
      .declarations
      .whereType<TopLevelVariableDeclaration>()
      .expand((declaration) => declaration.variables.variables)
      .singleWhere((variable) => variable.name.lexeme == '_analyticsServices');
  final list = services.initializer! as ListLiteral;
  return [
    for (final element in list.elements)
      if (element
          case NullAwareElement(
            value: MethodInvocation(
              methodName: SimpleIdentifier(name: '_createAlone'),
              :final argumentList,
            ),
          ))
        '${argumentList.arguments.last}'
      else
        '$element',
  ];
}

/// The methods of the class [name] in [unit], by name.
Map<String, MethodDeclaration> _methodsOf(CompilationUnit unit, String name) {
  final declaration =
      unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (declaration) => declaration.namePart.typeName.lexeme == name,
          );
  return {
    for (final member in declaration.body.members)
      if (member is MethodDeclaration) member.name.lexeme: member,
  };
}

/// The imports that the pipeline adds for the fragments of this module to
/// the files of [app], each as the owner of its file and the import.
List<String> _importsOfModuleIn(RenderedApp app) => [
      for (final file in app.files.values)
        for (final added in file.addedImports)
          if (added.contributor ==
              const ModuleOrigin(FirebaseAnalyticsModule.id))
            [
              '${file.owner}:',
              added.import.uri,
              'as ${added.import.prefix}',
              'show ${added.import.show.join(', ')}',
            ].join(' '),
    ];

void main() {
  const module = FirebaseAnalyticsModule();

  group('FirebaseAnalyticsModule', () {
    test(
        'is infrastructure that provides the analytics, uses the DI container '
        'and the router of its role, and depends on firebase_core', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('firebase_analytics'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {analyticsRole});
      expect(descriptor.dependsOn, {FirebaseCoreModule.id});
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.effectiveRequires, isEmpty);
      expect(descriptor.effectiveUses, {diRole, routerRole});
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
      expect(ModuleRegistry.problemsOf(_navigation), isEmpty);
    });

    test(
        'contributes its brick, firebase_analytics, its implementation of the '
        'service, created without waiting, and a listener of the screen for '
        'a router, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(4));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(firebaseAnalyticsBundle));
      expect(brick.bundle.name, 'firebase_analytics');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [_implementation],
      );
      expect(brick.when, isEmpty);

      final dependency = contributions[1] as PubspecDependency;
      expect(dependency.package, 'firebase_analytics');
      expect(dependency.constraint, '^12.6.0');
      expect(dependency.dev, isFalse);

      final data = contributions[2] as RoleData<Object>;
      expect(data.role, analyticsRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'FirebaseAnalyticsService');
      expect(implementation.create!.name, 'createFirebaseAnalyticsService');
      expect(implementation.create!.deps, isEmpty);
      expect(
        implementation.type.import,
        const ImportRef.app('core/analytics/firebase_analytics_service.dart'),
      );
      expect(implementation.create!.import, implementation.type.import);

      // The router tells the listener, a function of the file of the module,
      // about the screen the user sees; only an app with a router gets it.
      // The module gives the navigators no observer, which would log the
      // pages that enter their stacks.
      final listener = contributions[3] as SocketContribution;
      expect(listener.socket, RouterRole.screenListeners);
      expect(listener.when, {routerRole});
      expect(listener.fragment!.code, _listener);
      expect(listener.fragment!.imports, const [
        ImportRef.app(
          'core/analytics/firebase_analytics_service.dart',
          show: ['logFirebaseScreenView'],
        ),
      ]);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the apps of the analytics with and without a DI container and '
        'a router', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'firebase_core',
        'firebase_analytics with di, router',
        'firebase_analytics with di',
        'firebase_analytics with router',
        'firebase_analytics',
        'get_it',
      ]);
      // firebase_core comes with the module, as the module depends on it.
      for (final result in results.skip(3).take(4)) {
        expect(
          result.resolution!.modules.map((module) => module.id),
          contains(FirebaseCoreModule.id),
          reason: '${result.contractCase}',
        );
      }
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });
  });

  group('an app without a router or a DI container', () {
    late ContractResult result;
    late RenderedApp withAnalytics;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [FirebaseAnalyticsModule.id]);
      withAnalytics = result.app!;
      without = (await _resultOf(const [FirebaseCoreModule.id])).app!;
    });

    test(
        'is the app of Firebase but for the service, its implementation and '
        'firebase_analytics', () {
      // Its native files, the Gradle files and the Xcode project among
      // them, and its README are those of Firebase: the module sets up
      // nothing of the platforms.
      _expectTheAppWithout(withAnalytics, without);
      expect(
        _yamlOf(withAnalytics.files['pubspec.yaml']!.text)['dependencies'],
        {
          'firebase_analytics': '^12.6.0',
          'firebase_core': '^4.15.0',
          'flutter': {'sdk': 'flutter'},
        },
      );
    });

    test('starts nothing in bootstrap(), as the service needs no waiting', () {
      expect(_startUpOf(result), ['firebase_core: $_initializeFirebase']);
    });

    test(
        'forwards the calls of the app to the implementation of Firebase '
        'Analytics, created on first use', () {
      final file = withAnalytics.files[AnalyticsRole.file]!;

      expect(_servicesOf(withAnalytics), [
        'impl0.createFirebaseAnalyticsService',
      ]);
      expect(
        [
          for (final added in file.addedImports)
            (added.import.uri, added.import.prefix, '${added.contributor}'),
        ],
        [
          (
            'package:contract_app/core/analytics/'
                'firebase_analytics_service.dart',
            'impl0',
            'role:analytics',
          ),
        ],
      );
      // Nothing to await: the service is created without waiting, by the
      // function of the role that creates each implementation on its own.
      expect(
        _unitOf(withAnalytics, AnalyticsRole.file)
            .declarations
            .whereType<FunctionDeclaration>()
            .map((function) => function.name.lexeme),
        ['createAnalyticsService', '_createAlone'],
      );
    });

    test('logs no screen view, as it has no router to tell it the screen', () {
      for (final file in withAnalytics.files.values) {
        if (!file.isText) continue;
        expect(
          file.text,
          allOf(
            isNot(contains('logScreenView')),
            isNot(contains('logFirebaseScreenView')),
            isNot(contains('FirebaseAnalyticsObserver')),
          ),
          reason: file.path,
        );
      }
      // Nor does its file import what the listener would need.
      expect(
        [
          for (final directive in _unitOf(withAnalytics, _implementation)
              .directives
              .whereType<ImportDirective>())
            '$directive',
        ],
        [
          "import 'package:firebase_analytics/firebase_analytics.dart';",
          "import 'analytics_service.dart';",
        ],
      );
    });

    group('the implementation', () {
      late CompilationUnit unit;
      late Map<String, MethodDeclaration> methods;

      setUpAll(() {
        unit = _unitOf(withAnalytics, _implementation);
        methods = _methodsOf(unit, 'FirebaseAnalyticsService');
      });

      test('is the service on the Firebase Analytics of the Firebase app', () {
        final declaration =
            unit.declarations.whereType<ClassDeclaration>().single;
        expect(
          '${declaration.implementsClause!.interfaces.single}',
          'AnalyticsService',
        );
        final factory =
            unit.declarations.whereType<FunctionDeclaration>().single;
        expect(factory.name.lexeme, 'createFirebaseAnalyticsService');
        expect('${factory.returnType}', 'AnalyticsService');
        expect(factory.functionExpression.parameters!.parameters, isEmpty);
        final body = factory.functionExpression.body as ExpressionFunctionBody;
        expect(
          '${body.expression}',
          'FirebaseAnalyticsService(FirebaseAnalytics.instance)',
        );
      });

      test(
          'implements every method of the service with the parameters of the '
          'interface', () {
        final interface = _methodsOf(
          _unitOf(withAnalytics, AnalyticsRole.file),
          'AnalyticsService',
        );

        expect(methods.keys.toSet(), interface.keys.toSet());
        for (final MapEntry(key: name, value: method) in methods.entries) {
          expect(
            '${method.returnType} ${method.parameters}',
            '${interface[name]!.returnType} ${interface[name]!.parameters}',
            reason: name,
          );
        }
      });

      test(
          'forwards each call to Firebase Analytics, a sign-in and a sign-up '
          'as its standard events with their parameters', () {
        String callOf(String method) =>
            '${(methods[method]!.body as ExpressionFunctionBody).expression}';

        expect(
          callOf('logEvent'),
          '_analytics.logEvent(name: name, parameters: parameters)',
        );
        expect(
          callOf('logSignIn'),
          '_analytics.logLogin(loginMethod: method, parameters: parameters)',
        );
        expect(
          callOf('logSignUp'),
          '_analytics.logSignUp(signUpMethod: method, parameters: parameters)',
        );
        expect(
          callOf('setAnalyticsCollectionEnabled'),
          '_analytics.setAnalyticsCollectionEnabled(enabled)',
        );
        expect(callOf('setUserId'), '_analytics.setUserId(id: userId)');
        expect(
          callOf('setUserProperty'),
          '_analytics.setUserProperty(name: name, value: value)',
        );
      });
    });
  });

  group('an app with a DI container', () {
    late ContractResult result;
    late RenderedApp withAnalytics;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(
        const [FirebaseAnalyticsModule.id, GetItModule.id],
      );
      withAnalytics = result.app!;
      without = (await _resultOf(
        const [FirebaseCoreModule.id, GetItModule.id],
      ))
          .app!;
    });

    test(
        'is the app of Firebase and the container but for the analytics and '
        'its registration', () {
      _expectTheAppWithout(
        withAnalytics,
        without,
        changedBy: _providersOf(result, diRole),
      );
      expect(_startUpOf(result), [
        'firebase_core: $_initializeFirebase',
        'role:di: await registerDependencies();',
      ]);
    });

    test('registers the service in the container, which creates it', () {
      // The contract harness, which found no errors in the app, checks that
      // the provider of the role creates it with its factory.
      final registrations = [
        for (final data in _registrationsOf(result))
          if (data.origin == const RoleTemplateOrigin(analyticsRole))
            data.value,
      ];
      expect(registrations, hasLength(1));
      final registration = registrations.single;
      expect(registration.type.name, 'AnalyticsService');
      expect(registration.create.name, 'createAnalyticsService');
      expect(registration.create.deps, isEmpty);
      expect(registration.lifetime, DiLifetime.lazySingleton);
    });
  });

  group('an app with a router', () {
    late ContractResult result;
    late ContractResult resultWithout;
    late RenderedApp withAnalytics;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(
        const [FirebaseAnalyticsModule.id, GoRouterModule.id],
      );
      withAnalytics = result.app!;
      resultWithout = await _resultOf(
        const [FirebaseCoreModule.id, GoRouterModule.id],
      );
      without = resultWithout.app!;
    });

    test(
        'is the app of Firebase and the router but for the analytics and the '
        'listener of the screen', () {
      _expectTheAppWithout(
        withAnalytics,
        without,
        changedBy: _providersOf(result, routerRole),
      );
      _expectTheRouterWithout(result, resultWithout);
      expect(
        _contributionsTo(resultWithout, RouterRole.screenListeners),
        isEmpty,
      );
    });

    test(
        'gives the router a listener that logs each screen the user sees with '
        'Firebase Analytics, and its navigator no observer', () {
      expect(
        _contributionsTo(result, RouterRole.screenListeners),
        [_listenerOfModule],
      );
      expect(_contributionsTo(result, RouterRole.observers), isEmpty);
      // Only the name of the listener, so that no name of the file of the
      // module meets another in the file of the router that renders it,
      // whichever module provides the router.
      final router = _providersOf(result, routerRole).single;
      expect(_importsOfModuleIn(withAnalytics), [
        [
          '$router:',
          'package:contract_app/core/analytics/firebase_analytics_service.dart',
          'as null show logFirebaseScreenView',
        ].join(' '),
      ]);
    });

    test(
        'logs a screen view with the name of the route of the screen, or / '
        'for the fallback start screen, but not the error screen of the '
        'router, and prints an error of the platform', () {
      final unit = _unitOf(withAnalytics, _implementation);
      final listener = unit.declarations
          .whereType<FunctionDeclaration>()
          .singleWhere((function) => function.name.lexeme == _listener);

      expect(listener.toSource(), _expectedListener);
      // The file has the imports that the listener needs only in an app
      // with a router.
      expect(
        [
          for (final directive in unit.directives.whereType<ImportDirective>())
            '$directive',
        ],
        [
          "import 'package:firebase_analytics/firebase_analytics.dart';",
          ..._listenerImports,
          "import 'analytics_service.dart';",
        ],
      );
    });

    test('has the file of the module of an app without a router otherwise',
        () async {
      final withoutRouter = _unitOf(
        (await _resultOf(const [FirebaseAnalyticsModule.id])).app!,
        _implementation,
      );
      final unit = _unitOf(withAnalytics, _implementation);

      expect(
        [
          for (final declaration in unit.declarations)
            if (declaration is! FunctionDeclaration ||
                declaration.name.lexeme != _listener)
              declaration.toSource(),
        ],
        [
          for (final declaration in withoutRouter.declarations)
            declaration.toSource(),
        ],
      );
      expect(
        [
          for (final directive in unit.directives)
            if (!_listenerImports.contains('$directive')) '$directive',
        ],
        [for (final directive in withoutRouter.directives) '$directive'],
      );
    });
  });

  group('an app with a main navigation', () {
    late ContractResult result;
    late ContractResult resultWithout;

    setUpAll(() async {
      Future<ContractResult> appWith(ModuleId module) => _resultOf(
            [
              module,
              const ModuleId('inbox'),
              const ModuleId('search'),
              const ModuleId('about'),
              TestLayout.id,
            ],
            registry: _navigation,
          );
      result = await appWith(FirebaseAnalyticsModule.id);
      resultWithout = await appWith(FirebaseCoreModule.id);
    });

    test(
        'is the app of Firebase and the main navigation but for the analytics '
        'and the listener of the screen', () {
      _expectTheAppWithout(
        result.app!,
        resultWithout.app!,
        changedBy: _providersOf(result, routerRole),
      );
      _expectTheRouterWithout(result, resultWithout);
    });

    test(
        'gives the router one listener of the screen for the whole app, the '
        'branches of the main navigation included, and no navigator an '
        'observer', () {
      // A router tells the listeners about the screens of every branch of
      // the main navigation too, which the tests of each router and those
      // of the layout role in the apps of the matrix check.
      expect(
        _contributionsTo(result, RouterRole.screenListeners),
        [_listenerOfModule],
      );
      expect(_contributionsTo(result, RouterRole.observers), isEmpty);
      expect(
        [
          for (final route
              in layoutRole.destinationsIn(layoutRole.hookInput(result.hook!)))
            route.fullPath,
        ],
        ['/inbox', '/search'],
      );
    });
  });

  group('an app with another analytics service', () {
    const registry = [..._modules, _OtherAnalyticsModule()];

    test(
        'forwards the calls to both, in the order of the modules, and gives '
        'the router the listener of Firebase Analytics alone', () async {
      for (final (modules, services) in [
        (
          const [
            FirebaseAnalyticsModule.id,
            _OtherAnalyticsModule.id,
            GoRouterModule.id,
          ],
          [
            'impl0.createFirebaseAnalyticsService',
            'impl1.createOtherAnalyticsService',
          ],
        ),
        (
          const [
            _OtherAnalyticsModule.id,
            FirebaseAnalyticsModule.id,
            GoRouterModule.id,
          ],
          [
            'impl0.createOtherAnalyticsService',
            'impl1.createFirebaseAnalyticsService',
          ],
        ),
      ]) {
        final result = await _resultOf(modules, registry: registry);
        final app = result.app!;

        expect(_servicesOf(app), services, reason: '$modules');
        expect(
          _contributionsTo(result, RouterRole.screenListeners),
          [_listenerOfModule],
          reason: '$modules',
        );
        expect(
          _startUpOf(result),
          ['firebase_core: $_initializeFirebase'],
          reason: '$modules',
        );
      }
    });
  });
}
