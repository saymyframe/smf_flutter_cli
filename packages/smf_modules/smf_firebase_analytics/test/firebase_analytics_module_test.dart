@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/bundles/firebase_analytics_bundle.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_analytics/src/agents.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
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

/// The meta-data of the manifest of Android with which Firebase Analytics
/// logs a screen view of its own for each activity, which the one activity
/// of Flutter would make the screen of every screen of the app.
const _androidScreenReporting =
    'google_analytics_automatic_screen_reporting_enabled';

/// The key of `Info.plist` with which Firebase Analytics logs a screen view
/// of its own for each view controller, which the one view controller of
/// Flutter would make the screen of every screen of the app.
const _iosScreenReporting = 'FirebaseAutomaticScreenReportingEnabled';

/// The native files in which the module turns off the screen views that
/// Firebase Analytics logs itself.
const Set<String> _screenReportingFiles = {
  AppEntryRole.androidManifestFile,
  AppEntryRole.infoPlistFile,
};

/// The native file [path] of an app with [text] without the lines with which
/// the module turns off the screen views that Firebase Analytics logs
/// itself: the line of the meta-data in the manifest of Android, and the
/// lines of the key and of its value in `Info.plist`.
String _withoutScreenReporting(String path, String text) {
  final lines = text.split('\n');
  final manifest = path == AppEntryRole.androidManifestFile;
  final at = lines.indexWhere(
    (line) => line.contains(
      manifest
          ? 'android:name="$_androidScreenReporting"'
          : '<key>$_iosScreenReporting</key>',
    ),
  );
  expect(at, isNot(-1), reason: path);
  lines.removeRange(at, manifest ? at + 1 : at + 2);
  return lines.join('\n');
}

/// The statement of firebase_core that initializes Firebase in
/// `bootstrap()`.
const _initializeFirebase = 'await Firebase.initializeApp(options: firebaseOptionsOfFlavor);';

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

/// The owners of the code of the analytics: the template of the role and
/// this module.
final Set<ContributionOrigin> _analytics = {
  const RoleTemplateOrigin(analyticsRole),
  const ModuleOrigin(FirebaseAnalyticsModule.id),
};

/// Checks that [app] is [without] but for the files of the analytics, the
/// dependency on firebase_analytics, the section of the analytics in the
/// guide for coding agents, the step by hand of the module, which opens the
/// README and adds the note of the app entry on the steps by hand to the
/// guide, and the files that the modules [changedBy] generate; its
/// `bootstrap()` included, since the service starts without waiting. With
/// [screenReportingOff], the manifest of Android and `Info.plist` also turn
/// off the screen views that Firebase Analytics logs itself.
void _expectTheAppWithout(
  RenderedApp app,
  RenderedApp without, {
  Set<ModuleId> changedBy = const {},
  bool screenReportingOff = false,
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
    if (const {'pubspec.yaml', AppEntryRole.readmeFile, AppEntryRole.agentsFile}
        .contains(path)) {
      continue;
    }
    if (file.owner case ModuleOrigin(:final module)
        when changedBy.contains(module)) {
      continue;
    }
    if (screenReportingOff && _screenReportingFiles.contains(path)) {
      expect(
        _withoutScreenReporting(path, app.files[path]!.text),
        file.text,
        reason: path,
      );
      expect(app.files[path]!.owner, file.owner, reason: path);
      continue;
    }
    expect(app.files[path]!.bytes, file.bytes, reason: path);
    expect(app.files[path]!.owner, file.owner, reason: path);
  }
  expect(
    _pubspecWithoutAnalytics(app),
    _yamlOf(without.files['pubspec.yaml']!.text),
  );
  // The README is that of the app without the analytics, opened by the
  // section of the steps by hand, which lists the step of the module alone.
  final readme = app.files[AppEntryRole.readmeFile]!.text;
  final setup = RegExp(
    '## ${AppEntryRole.setupHeading}\n[\\s\\S]*?\n(?=## )',
  ).firstMatch(readme)!;
  expect(
    readme.replaceRange(setup.start, setup.end, ''),
    without.files[AppEntryRole.readmeFile]!.text,
  );
  expect(
    [
      for (final step
          in RegExp(r'^\d+\. (.+)$', multiLine: true).allMatches(setup[0]!))
        step[1],
    ],
    [FirebaseAnalyticsModule.googleAnalyticsStep.title],
  );
  // The guide has the notes of the app without the analytics, the note of
  // the app entry on the steps by hand under the heading of that role, and
  // the notes of the analytics under the heading of the role.
  final notes = app.entriesOf(AppEntryRole.agentSections);
  final withoutNotes = without.entriesOf(AppEntryRole.agentSections);
  final others = [
    for (final note in notes)
      if (!_analytics.contains(note.$1)) note,
  ];
  final added = [
    for (final note in others)
      if (!withoutNotes.contains(note)) note,
  ];
  expect(
    [
      for (final (origin, heading, note) in added)
        (origin, heading, note.isOfRole),
    ],
    [(const RoleTemplateOrigin(appEntryRole), appEntryRole.description, true)],
  );
  expect(others.where((note) => !added.contains(note)), withoutNotes);
  expect(
    [
      for (final (origin, heading, note) in notes)
        if (_analytics.contains(origin)) (origin, heading, note.isOfRole),
    ],
    // The template of a role contributes after its providers; the guide
    // shows what the role says first.
    [
      for (final _ in _notesOfModule(app))
        (
          const ModuleOrigin(FirebaseAnalyticsModule.id),
          analyticsRole.description,
          false,
        ),
      (
        const RoleTemplateOrigin(analyticsRole),
        analyticsRole.description,
        true,
      ),
    ],
  );
  // The note of the screen views is in the apps with a router, which have
  // the listener that it names.
  expect(_notesOfModule(app), [
    if (app.files.containsKey(RouterRole.appRouterFile))
      AgentNote(screenViewsAgentNote),
  ]);
}

/// The notes of this module in the guide for coding agents of [app], in the
/// order of the guide.
List<AgentNote> _notesOfModule(RenderedApp app) => [
      for (final (origin, _, note) in app.entriesOf(AppEntryRole.agentSections))
        if (origin == const ModuleOrigin(FirebaseAnalyticsModule.id)) note,
    ];

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
        'service, created without waiting, the step by hand of Google '
        'Analytics, a listener of the screen for a router with the screen '
        'views of Firebase itself turned off, and its note for coding agents, '
        'and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(8));
      // Of the listener of the screen, which only an app with a router has.
      final note = contributions.last as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, analyticsRole.description);
      expect(note.entryValue, AgentNote(screenViewsAgentNote));
      expect(note.when, {routerRole});
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

      // In every app of the module.
      final step = contributions[3] as ManualStep;
      expect(step, same(FirebaseAnalyticsModule.googleAnalyticsStep));
      expect(step.when, isEmpty);
      expect(
        step.id,
        const ManualStepId(FirebaseAnalyticsModule.id, 'google_analytics'),
      );
      expect(step.id.wire, 'firebase_analytics.google_analytics');
      expect(
        step.title,
        'Turn on Google Analytics in the Firebase project, unless it is on '
        'already',
      );

      // The router tells the listener, a function of the file of the module,
      // about the screen the user sees; only an app with a router gets it.
      // The module gives the navigators no observer, which would log the
      // pages that enter their stacks.
      final listener = contributions[4] as SocketContribution;
      expect(listener.socket, RouterRole.screenListeners);
      expect(listener.when, {routerRole});
      expect(listener.fragment!.code, _listener);
      expect(listener.fragment!.imports, const [
        ImportRef.app(
          'core/analytics/firebase_analytics_service.dart',
          show: ['logFirebaseScreenView'],
        ),
      ]);

      // With the listener, Firebase Analytics logs no screen view of its
      // own, which would name each screen after the one activity of Flutter
      // on Android and its one view controller on iOS.
      final android = contributions[5] as SocketContribution;
      expect(android.socket, AppEntryRole.androidManifestApplicationMeta);
      expect(android.entryKey, _androidScreenReporting);
      expect(android.entryValue, const AndroidMetaData.value('false'));
      expect(android.when, {routerRole});
      final ios = contributions[6] as SocketContribution;
      expect(ios.socket, AppEntryRole.infoPlist);
      expect(ios.entryKey, _iosScreenReporting);
      expect(ios.entryValue, const PlistBoolean(false));
      expect(ios.when, {routerRole});
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
      // nothing of the platforms. Firebase Analytics logs its own screen
      // views there, as nothing else logs them.
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
        'lists the step by hand of Google Analytics, of the module, in the '
        'section of the steps by hand that opens the README', () {
      final planned = result.manualSteps.single;
      expect(planned.step, same(FirebaseAnalyticsModule.googleAnalyticsStep));
      expect(
        planned.contributors,
        [const ModuleOrigin(FirebaseAnalyticsModule.id)],
      );
      final readme = withAnalytics.files[AppEntryRole.readmeFile]!.text;
      expect(
        RegExp(r'^## (.+)$', multiLine: true).firstMatch(readme)?[1],
        AppEntryRole.setupHeading,
      );
      expect(
        readme,
        contains(
          '\n1. ${FirebaseAnalyticsModule.googleAnalyticsStep.title}\n',
        ),
      );
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

    test(
        'tells coding agents which events of Firebase Analytics a sign-in '
        'and a sign-up are, as its service logs them', () {
      final index = DartFileIndexer.index(
        _implementation,
        withAnalytics.files[_implementation]!.text,
      );
      final role = DartFileIndexer.index(
        AnalyticsRole.file,
        withAnalytics.files[AnalyticsRole.file]!.text,
      );

      // The two calls of the service of the role, which the service of the
      // module passes on to the calls of Firebase Analytics for its
      // standard events.
      for (final service in [
        role.declaration('AnalyticsService')!,
        index.declaration('FirebaseAnalyticsService')!,
      ]) {
        expect(
          service.members.map((member) => member.name),
          containsAll(['logSignIn', 'logSignUp']),
          reason: service.name,
        );
      }
      expect(index.invocationsOf('logLogin').single.target, '_analytics');
      expect(index.invocationsOf('logSignUp').single.target, '_analytics');
      // Without a router, the module has nothing to tell coding agents:
      // the guide says nothing of screen views.
      expect(_notesOfModule(withAnalytics), isEmpty);
      expect(
        withAnalytics.files[AppEntryRole.agentsFile]!.text,
        isNot(contains('Screen views')),
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
        screenReportingOff: true,
      );
      _expectTheRouterWithout(result, resultWithout);
      expect(
        _contributionsTo(resultWithout, RouterRole.screenListeners),
        isEmpty,
      );
    });

    test(
        'turns off the screen views that Firebase Analytics logs itself, one '
        'for each activity on Android and each view controller on iOS, so '
        'that the listener alone logs the screens', () {
      final application = XmlDocument.parse(
        withAnalytics.files[AppEntryRole.androidManifestFile]!.text,
      ).rootElement.getElement('application')!;
      expect(
        [
          for (final element in application.findElements('meta-data'))
            if (element.getAttribute('android:name') == _androidScreenReporting)
              (
                element.getAttribute('android:value'),
                element.getAttribute('android:resource'),
              ),
        ],
        [('false', null)],
      );

      final entries = XmlDocument.parse(
        withAnalytics.files[AppEntryRole.infoPlistFile]!.text,
      ).rootElement.getElement('dict')!.childElements.toList();
      final keys = [
        for (final (index, element) in entries.indexed)
          if (element.name.local == 'key' &&
              element.innerText == _iosScreenReporting)
            index,
      ];
      expect(keys, hasLength(1));
      expect(entries[keys.single + 1].name.local, 'false');
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

    test(
        'tells coding agents that the listener of its file logs the screen '
        'views', () {
      expect(_notesOfModule(withAnalytics), [AgentNote(screenViewsAgentNote)]);
      expect(
        withAnalytics.files[AppEntryRole.agentsFile]!.text,
        contains('\n\n${screenViewsAgentNote.trim()}\n'),
      );
      expect(
        screenViewsAgentNote,
        startsWith('With `firebase_analytics`:\n'),
      );
      // The listener that the note names: the function of the file of the
      // module that the router gets, as the tests above show.
      expect(
        DartFileIndexer.index(
          _implementation,
          withAnalytics.files[_implementation]!.text,
        ).declaration(_listener)?.kind,
        DeclarationKind.function,
      );
      expect(
        screenViewsAgentNote,
        contains('the router calls `$_listener()` with each screen'),
      );
      // The two native files that turn off the screen views of Firebase
      // itself, as the test above shows.
      expect(
        screenViewsAgentNote,
        contains(
          '`${AppEntryRole.androidManifestFile}` and '
          '`${AppEntryRole.infoPlistFile}` turn off the screen views that '
          'Firebase Analytics logs itself',
        ),
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
        screenReportingOff: true,
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
