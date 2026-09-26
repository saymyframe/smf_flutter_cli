@TestOn('vm')
library;

import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:mason/mason.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/bundles/firebase_crashlytics_bundle.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: flutter_core, which creates the app,
/// firebase_core, which this module depends on, this module, and get_it, a
/// DI container, which registers the reporter in the apps that have it.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  FirebaseCoreModule(),
  FirebaseCrashlyticsModule(),
  GetItModule(),
];

/// The path of the file of the module.
const _implementation =
    'lib/core/crash_reporting/crashlytics_crash_reporter.dart';

/// The statement of firebase_core that initializes Firebase in
/// `bootstrap()`.
const _initializeFirebase = 'await Firebase.initializeApp(options: '
    'DefaultFirebaseOptions.currentPlatform);';

/// The text of the file of [_OtherReporterModule]: a reporter that reports
/// nowhere.
const _otherReporter = '''
import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

CrashReporter createOtherCrashReporter() => const OtherCrashReporter();

final class OtherCrashReporter implements CrashReporter {
  const OtherCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {}

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}
''';

/// Another provider of the crash reporting role, which does not use
/// Firebase, as a reporter to another service would not.
final class _OtherReporterModule extends SmfModule {
  const _OtherReporterModule();

  static const id = ModuleId('other_reporter');

  static const _file = ImportRef.app(
    'core/crash_reporting/other_crash_reporter.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Crash reports to another service',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(crashReportingRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          MasonBundle(
            name: 'other_reporter',
            description: 'Crash reports to another service',
            version: '0.1.0',
            files: [
              MasonBundledFile(
                'lib/core/crash_reporting/other_crash_reporter.dart',
                base64.encode(utf8.encode(_otherReporter)),
                'text',
              ),
            ],
          ),
        ),
        crashReportingRole.data(
          const RoleImplementation(
            type: TypeRef('OtherCrashReporter', import: _file),
            create: FactoryRef('createOtherCrashReporter', import: _file),
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

/// The pubspec of [app] without the dependency on firebase_crashlytics.
Map<String, Object?> _pubspecWithoutCrashlytics(RenderedApp app) {
  final pubspec = _yamlOf(app.files['pubspec.yaml']!.text);
  final dependencies = {
    ...pubspec['dependencies']! as Map<String, Object?>,
  }..remove('firebase_crashlytics');
  return {...pubspec, 'dependencies': dependencies};
}

/// Checks that [app] is [without] but for the files of the crash reporting,
/// the dependency on firebase_crashlytics, `bootstrap()` and the files at
/// [changed].
void _expectTheAppWithout(
  RenderedApp app,
  RenderedApp without, {
  Set<String> changed = const {},
}) {
  expect(
    app.files.keys.toSet(),
    {...without.files.keys, CrashReportingRole.file, _implementation},
  );
  expect(
    app.files[CrashReportingRole.file]!.owner,
    const RoleTemplateOrigin(crashReportingRole),
  );
  expect(
    app.files[_implementation]!.owner,
    const ModuleOrigin(FirebaseCrashlyticsModule.id),
  );
  for (final MapEntry(key: path, value: file) in without.files.entries) {
    if (path == 'pubspec.yaml' ||
        path == AppEntryRole.bootstrapFile ||
        changed.contains(path)) {
      continue;
    }
    expect(app.files[path]!.bytes, file.bytes, reason: path);
    expect(app.files[path]!.owner, file.owner, reason: path);
  }
  expect(
    _pubspecWithoutCrashlytics(app),
    _yamlOf(without.files['pubspec.yaml']!.text),
  );
}

/// The statements of `bootstrap()` in [app], as written.
List<String> _bootstrapOf(RenderedApp app) {
  final unit = parseString(
    content: app.files[AppEntryRole.bootstrapFile]!.text,
  ).unit;
  final bootstrap = unit.declarations
      .whereType<FunctionDeclaration>()
      .singleWhere((function) => function.name.lexeme == 'bootstrap');
  final body = bootstrap.functionExpression.body as BlockFunctionBody;
  return [for (final statement in body.block.statements) '$statement'];
}

/// The factories that the reporter of the app in [app] forwards to, as
/// written in the list of the reporters of the template of the role.
List<String> _reportersOf(RenderedApp app) {
  final unit = parseString(
    content: app.files[CrashReportingRole.file]!.text,
  ).unit;
  final reporters = unit.declarations
      .whereType<TopLevelVariableDeclaration>()
      .expand((declaration) => declaration.variables.variables)
      .singleWhere((variable) => variable.name.lexeme == '_crashReporters');
  final list = reporters.initializer! as ListLiteral;
  return [for (final element in list.elements) '$element'];
}

/// The methods of the class [name] in [unit], by name.
Map<String, MethodDeclaration> _methodsOf(CompilationUnit unit, String name) {
  final declaration = unit.declarations
      .whereType<ClassDeclaration>()
      .singleWhere((declaration) => declaration.name.lexeme == name);
  return {
    for (final member in declaration.members)
      if (member is MethodDeclaration) member.name.lexeme: member,
  };
}

/// The one invocation that the method [method] returns: the expression of
/// its body.
MethodInvocation _callOf(MethodDeclaration method) =>
    (method.body as ExpressionFunctionBody).expression as MethodInvocation;

/// The named arguments of [call], as written, by name.
Map<String, String> _namedOf(MethodInvocation call) => {
      for (final argument in call.argumentList.arguments)
        if (argument is NamedExpression)
          argument.name.label.name: '${argument.expression}',
    };

/// The positional arguments of [call], as written.
List<String> _positionalOf(MethodInvocation call) => [
      for (final argument in call.argumentList.arguments)
        if (argument is! NamedExpression) '$argument',
    ];

/// Collects the names of the methods and functions that a unit invokes.
final class _Invocations extends RecursiveAstVisitor<void> {
  final List<String> names = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    names.add(node.methodName.name);
    super.visitMethodInvocation(node);
  }
}

void main() {
  const module = FirebaseCrashlyticsModule();

  group('FirebaseCrashlyticsModule', () {
    test(
        'is infrastructure that provides the crash reporting and depends on '
        'firebase_core', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('firebase_crashlytics'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {crashReportingRole});
      expect(descriptor.dependsOn, {FirebaseCoreModule.id});
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, firebase_crashlytics and its implementation of '
        'the reporter, created without waiting, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(3));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(firebaseCrashlyticsBundle));
      expect(brick.bundle.name, 'firebase_crashlytics');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [_implementation],
      );
      final dependency = contributions[1] as PubspecDependency;
      expect(dependency.package, 'firebase_crashlytics');
      expect(dependency.constraint, '^5.4.0');
      expect(dependency.dev, isFalse);
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, crashReportingRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'CrashlyticsCrashReporter');
      expect(implementation.create!.name, 'createCrashlyticsCrashReporter');
      expect(implementation.create!.deps, isEmpty);
      expect(
        implementation.type.import,
        const ImportRef.app(
          'core/crash_reporting/crashlytics_crash_reporter.dart',
        ),
      );
      expect(implementation.create!.import, implementation.type.import);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the apps of the crash reporting with a DI container and '
        'without', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core',
        'firebase_core',
        'firebase_crashlytics with di',
        'firebase_crashlytics',
        'get_it',
      ]);
      // firebase_core comes with the module, as the module depends on it.
      for (final result in results.skip(2).take(2)) {
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

  group('an app without a DI container', () {
    late RenderedApp withCrashlytics;
    late RenderedApp without;

    setUpAll(() async {
      withCrashlytics =
          (await _resultOf(const [FirebaseCrashlyticsModule.id])).app!;
      without = (await _resultOf(const [FirebaseCoreModule.id])).app!;
    });

    test(
        'is the app of Firebase but for the reporter, its implementation, '
        'firebase_crashlytics and the start of the crash reporting', () {
      // Its native files, the Gradle files and the Xcode project among
      // them, and its README are those of Firebase: the module sets up
      // nothing of the platforms.
      _expectTheAppWithout(withCrashlytics, without);
      expect(
        _yamlOf(withCrashlytics.files['pubspec.yaml']!.text)['dependencies'],
        {
          'firebase_core': '^4.15.0',
          'firebase_crashlytics': '^5.4.0',
          'flutter': {'sdk': 'flutter'},
        },
      );
    });

    test(
        'installs the crash reporting in bootstrap() once Firebase is '
        'initialized', () {
      // The template of the role comes after its providers and the modules
      // they depend on: firebase_core, whose Firebase app Crashlytics uses.
      expect(_bootstrapOf(withCrashlytics), [
        _initializeFirebase,
        'installCrashReporting();',
      ]);
      expect(_bootstrapOf(without), [_initializeFirebase]);
      expect(
        [
          for (final added in withCrashlytics
              .files[AppEntryRole.bootstrapFile]!.addedImports)
            if (added.contributor ==
                const RoleTemplateOrigin(
                  crashReportingRole,
                ))
              added.import.uri,
        ],
        ['package:contract_app/core/crash_reporting/crash_reporter.dart'],
      );
    });

    test(
        'forwards the reports of the app to the implementation of '
        'Crashlytics, created on first use', () {
      final file = withCrashlytics.files[CrashReportingRole.file]!;

      expect(_reportersOf(withCrashlytics), [
        'impl0.createCrashlyticsCrashReporter()',
      ]);
      expect(
        [
          for (final added in file.addedImports)
            (added.import.uri, added.import.prefix, '${added.contributor}'),
        ],
        [
          (
            'package:contract_app/core/crash_reporting/'
                'crashlytics_crash_reporter.dart',
            'impl0',
            'role:crash_reporting',
          ),
        ],
      );
      // Nothing to await: the reporter is created without waiting.
      final unit = parseString(content: file.text).unit;
      expect(
        unit.declarations
            .whereType<FunctionDeclaration>()
            .map((function) => function.name.lexeme),
        ['createCrashReporter', 'installCrashReporting'],
      );
    });

    group('the implementation', () {
      late CompilationUnit unit;
      late Map<String, MethodDeclaration> methods;

      setUpAll(() {
        unit = parseString(
          content: withCrashlytics.files[_implementation]!.text,
        ).unit;
        methods = _methodsOf(unit, 'CrashlyticsCrashReporter');
      });

      test('is the reporter on the Crashlytics of the Firebase app', () {
        final declaration =
            unit.declarations.whereType<ClassDeclaration>().single;
        expect(
          '${declaration.implementsClause!.interfaces.single}',
          'CrashReporter',
        );
        expect(methods.keys.toSet(), {
          'recordError',
          'recordFlutterError',
          'log',
          'setUserId',
        });
        final factory =
            unit.declarations.whereType<FunctionDeclaration>().single;
        expect(factory.name.lexeme, 'createCrashlyticsCrashReporter');
        final body = factory.functionExpression.body as ExpressionFunctionBody;
        expect(
          '${body.expression}',
          'CrashlyticsCrashReporter(FirebaseCrashlytics.instance)',
        );
      });

      test(
          'reports an error without printing it, since the handlers of the '
          'role leave it in the console in debug mode', () {
        final call = _callOf(methods['recordError']!);

        expect('${call.target}', '_crashlytics');
        expect(call.methodName.name, 'recordError');
        expect(_positionalOf(call), ['error', 'stackTrace']);
        expect(_namedOf(call), {
          'reason': 'reason',
          'printDetails': 'false',
          'fatal': 'fatal',
        });
      });

      test(
          'reports an error of Flutter as Crashlytics does, without '
          'presenting it again', () {
        final call = _callOf(methods['recordFlutterError']!);

        // What recordFlutterError of firebase_crashlytics 5.4 reports, after
        // it calls FlutterError.presentError.
        expect('${call.target}', '_crashlytics');
        expect(call.methodName.name, 'recordError');
        expect(_positionalOf(call), [
          'details.exceptionAsString()',
          'details.stack',
        ]);
        expect(_namedOf(call), {
          'reason': 'details.context?.toStringDeep(minLevel: '
              'DiagnosticLevel.info).trim()',
          'information': 'details.informationCollector?.call() ?? const []',
          'printDetails': 'false',
          'fatal': 'fatal',
        });
        final invocations = _Invocations();
        unit.accept(invocations);
        expect(
          invocations.names,
          isNot(
            anyOf(
              contains('presentError'),
              contains('recordFlutterError'),
              contains('recordFlutterFatalError'),
            ),
          ),
        );
      });

      test('adds to the log and clears the user id with an empty one', () {
        final log = _callOf(methods['log']!);
        expect('${log.target}.${log.methodName}', '_crashlytics.log');
        expect(_positionalOf(log), ['message']);

        final user = _callOf(methods['setUserId']!);
        expect(
          '${user.target}.${user.methodName}',
          '_crashlytics.setUserIdentifier',
        );
        expect(_positionalOf(user), ["userId ?? ''"]);
      });
    });
  });

  group('an app with a DI container', () {
    late ContractResult result;
    late RenderedApp withCrashlytics;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(
        const [FirebaseCrashlyticsModule.id, GetItModule.id],
      );
      withCrashlytics = result.app!;
      without = (await _resultOf(
        const [FirebaseCoreModule.id, GetItModule.id],
      ))
          .app!;
    });

    test(
        'is the app of Firebase and the container but for the crash '
        'reporting and its registration', () {
      _expectTheAppWithout(
        withCrashlytics,
        without,
        changed: const {DiRole.dependenciesFile},
      );
    });

    test('registers the reporter in the container, which creates it', () {
      final registrations = [
        for (final data in result.collection!.roleData)
          if (identical(data.role, diRole) &&
              data.origin == const RoleTemplateOrigin(crashReportingRole))
            data.value as DiRegistration,
      ];
      expect(registrations, hasLength(1));
      final registration = registrations.single;
      expect(registration.type.name, 'CrashReporter');
      expect(registration.create.name, 'createCrashReporter');
      expect(registration.create.deps, isEmpty);
      expect(registration.lifetime, DiLifetime.lazySingleton);

      final container = withCrashlytics.files[DiRole.dependenciesFile]!;
      final calls = DartFileIndexer.index(container.path, container.text)
          .invocations
          .where((call) => call.name == 'createCrashReporter');
      expect(calls, hasLength(1));
      expect(
        calls.single.enclosingDeclaration,
        DiRole.registerDependencies.name,
      );
    });

    test(
        'installs the crash reporting between the start of Firebase and the '
        'registration of the services', () {
      expect(_bootstrapOf(withCrashlytics), [
        _initializeFirebase,
        'installCrashReporting();',
        'await registerDependencies();',
      ]);
    });
  });

  group('an app with another crash reporter', () {
    const registry = [..._modules, _OtherReporterModule()];

    test(
        'forwards the reports to both, in the order of the modules, and '
        'installs the crash reporting once Firebase is initialized', () async {
      for (final (modules, reporters) in [
        (
          const [FirebaseCrashlyticsModule.id, _OtherReporterModule.id],
          [
            'impl0.createCrashlyticsCrashReporter()',
            'impl1.createOtherCrashReporter()',
          ],
        ),
        (
          const [_OtherReporterModule.id, FirebaseCrashlyticsModule.id],
          [
            'impl0.createOtherCrashReporter()',
            'impl1.createCrashlyticsCrashReporter()',
          ],
        ),
      ]) {
        final app = (await _resultOf(modules, registry: registry)).app!;

        expect(_reportersOf(app), reporters, reason: '$modules');
        expect(
          _bootstrapOf(app),
          [_initializeFirebase, 'installCrashReporting();'],
          reason: '$modules',
        );
      }
    });
  });
}
