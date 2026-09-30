@TestOn('vm')
library;

import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/bundles/firebase_crashlytics_bundle.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_firebase_crashlytics/src/crashlytics_phase.dart';
import 'package:smf_firebase_crashlytics/src/readme.dart';
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

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

/// The registrations of the DI role in the app of [result], as the provider
/// of the role gets them to render.
List<RoleData<DiRegistration>> _registrationsOf(ContractResult result) =>
    diRole.graphOf(diRole.hookInput(result.hook!)).registrations;

/// Whether the pipeline put code of the crash reporting, of this module or
/// of the template of its role, into [file], whose imports it added to the
/// file.
bool _holdsCodeOfCrashReporting(RenderedFile file) => file.addedImports.any(
      (added) => const [
        ModuleOrigin(FirebaseCrashlyticsModule.id),
        RoleTemplateOrigin(crashReportingRole),
      ].contains(added.contributor),
    );

/// Checks that [app] is [without] but for the files of the crash reporting,
/// the dependency on firebase_crashlytics, the files that hold code of the
/// crash reporting, such as the start-up, the section of the module in the
/// README, after those of [without], and the files that the modules
/// [changedBy] generate.
void _expectTheAppWithout(
  RenderedApp app,
  RenderedApp without, {
  Set<ModuleId> changedBy = const {},
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
        path == AppEntryRole.readmeFile ||
        _holdsCodeOfCrashReporting(app.files[path]!)) {
      continue;
    }
    if (file.owner case ModuleOrigin(:final module)
        when changedBy.contains(module)) {
      continue;
    }
    expect(app.files[path]!.bytes, file.bytes, reason: path);
    expect(app.files[path]!.owner, file.owner, reason: path);
  }
  expect(
    _pubspecWithoutCrashlytics(app),
    _yamlOf(without.files['pubspec.yaml']!.text),
  );
  final readme = app.files[AppEntryRole.readmeFile]!;
  expect(readme.owner, without.files[AppEntryRole.readmeFile]!.owner);
  expect(
    readme.text,
    '${without.files[AppEntryRole.readmeFile]!.text}'
    '\n'
    '## Crashlytics\n'
    '\n'
    '$readmeSection',
  );
}

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
        for (final collected
            in result.app!.socketOrders[phase]?.contributions ??
                const <Collected>[])
          [
            '${collected.origin}:',
            (collected.contribution as SocketContribution).fragment!.code,
          ].join(' '),
    ];

/// The factories of the implementations that the reporter of the app in
/// [app] forwards to, in the order of the list of the reporters of the
/// template of the role, which creates each on its own with
/// `_createAlone(name, factory)`; the code of any other element.
List<String> _reportersOf(RenderedApp app) {
  final unit = parseString(
    content: app.files[CrashReportingRole.file]!.text,
  ).unit;
  final reporters = unit.declarations
      .whereType<TopLevelVariableDeclaration>()
      .expand((declaration) => declaration.variables.variables)
      .singleWhere((variable) => variable.name.lexeme == '_crashReporters');
  final list = reporters.initializer! as ListLiteral;
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
        'contributes its brick, firebase_crashlytics, its implementation of '
        'the reporter, created without waiting, the fix of the build phase '
        'for Crashlytics and its section of the README, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(5));
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
      expect(contributions[3], same(crashlyticsPhaseFix));
      final readme = contributions[4] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, 'Crashlytics');
      expect(readme.entryValue, readmeSection);
    });

    test(
        'continues the step of firebase_core that runs flutterfire configure, '
        'on macOS, with Ruby that points the phase for Crashlytics of '
        'flutterfire at the upload script in the build directory of the app',
        () {
      final fix = module
          .contribute(ContractHarness.defaultContext)
          .whereType<PostGenStep>()
          .single;

      expect(fix.followUpOf, FirebaseCoreModule.configureStep);
      expect(fix.tool.executable, 'ruby');
      expect(fix.tool.prefixArgs, isEmpty);
      expect(fix.arguments, hasLength(3));
      expect(fix.arguments.first, '-e');
      expect(
        fix.arguments[1],
        allOf(
          contains(
            r'"$BUILD_DIR/SourcePackages/checkouts/firebase-ios-sdk/'
            'Crashlytics/run"',
          ),
          contains(
            r'"$SRCROOT/../build/ios/SourcePackages/checkouts/'
            'firebase-ios-sdk/Crashlytics/run"',
          ),
        ),
      );
      expect(fix.arguments.last, AppEntryRole.xcodeProjectFile);
      expect(
        fix.description,
        'Fixing the Crashlytics phase of flutterfire for flutter build ipa',
      );
      // It changes a file of the app, so it runs without asking or the
      // terminal, and the app is complete without it.
      expect(fix.interactive, isFalse);
      expect(fix.external, isFalse);
      expect(fix.skippable, isTrue);
      // flutterfire adds the phase only on macOS, and elsewhere there is
      // nothing to fix; the step that it continues needs the Ruby of the
      // Mac.
      expect(fix.hosts, {HostOperatingSystem.macos});
      expect(fix.needs, isEmpty);
      expect(fix.when, isEmpty);
      expect(fix.id, isNull);
      // The README of the app gives it as the pipeline prints it, in single
      // quotes, which the program has none of.
      expect(fix.arguments[1], isNot(contains("'")));
      expect(
        crashlyticsPhaseFixCommand,
        "ruby -e '${fix.arguments[1]}' ${fix.arguments[2]}",
      );
    });

    test(
        'tells in the README of the app how to fix the phase once the app is '
        'configured again on macOS', () {
      expect(readmeHeading, 'Crashlytics');
      expect(
        readmeSection,
        allOf(
          contains('```bash\n$crashlyticsPhaseFixCommand\n```\n'),
          contains('`flutter build ipa` needs one more change on macOS'),
          contains('flutterfire_cli 1.4.1 or a later 1.x'),
        ),
      );
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

    test(
        'runs the fix of the phase in the apps of the module right after '
        'flutterfire configure of firebase_core, which it continues', () {
      final apps = [
        for (final result in results)
          if (result.resolution!.modules
              .any((module) => module.id == FirebaseCrashlyticsModule.id))
            result,
      ];

      expect(apps, hasLength(2));
      for (final result in apps) {
        final steps = [
          for (final collected in result.validation!.postGenOrder.contributions)
            (
              '${collected.origin}',
              collected.contribution as PostGenStep,
            ),
        ];
        expect(
          [for (final (origin, step) in steps) (origin, step.id)],
          [
            ('firebase_core', FirebaseCoreModule.configureStep),
            ('firebase_crashlytics', null),
          ],
          reason: '${result.contractCase}',
        );
        expect(steps.last.$2, same(crashlyticsPhaseFix));
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
    late ContractResult result;
    late ContractResult resultWithout;
    late RenderedApp withCrashlytics;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [FirebaseCrashlyticsModule.id]);
      withCrashlytics = result.app!;
      resultWithout = await _resultOf(const [FirebaseCoreModule.id]);
      without = resultWithout.app!;
    });

    test(
        'is the app of Firebase but for the reporter, its implementation, '
        'firebase_crashlytics and the start of the crash reporting', () {
      // Its native files, the Gradle files and the Xcode project among
      // them, are those of Firebase: the module sets up nothing of the
      // platforms. Its README tells of Crashlytics after Firebase.
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
      expect(_startUpOf(result), [
        'firebase_core: $_initializeFirebase',
        'role:crash_reporting: installCrashReporting();',
      ]);
      expect(_startUpOf(resultWithout), [
        'firebase_core: $_initializeFirebase',
      ]);
      // The pipeline adds the import of the role to the file of the app
      // entry with the phase, whichever module provides the app entry.
      final entry = ModuleOrigin(
        result.resolution!.providersOf(appEntryRole).single.id,
      );
      expect(
        [
          for (final file in withCrashlytics.files.values)
            if (file.owner == entry)
              for (final added in file.addedImports)
                if (added.contributor ==
                    const RoleTemplateOrigin(crashReportingRole))
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
        'impl0.createCrashlyticsCrashReporter',
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
      // Nothing to await: the reporter is created without waiting, by the
      // function of the role that creates each implementation on its own.
      final unit = parseString(content: file.text).unit;
      expect(
        unit.declarations
            .whereType<FunctionDeclaration>()
            .map((function) => function.name.lexeme),
        ['createCrashReporter', 'installCrashReporting', '_createAlone'],
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
        changedBy: _providersOf(result, diRole),
      );
    });

    test('registers the reporter in the container, which creates it', () {
      // The contract harness, which found no errors in the app, checks that
      // the provider of the role creates it with its factory.
      final registrations = [
        for (final data in _registrationsOf(result))
          if (data.origin == const RoleTemplateOrigin(crashReportingRole))
            data.value,
      ];
      expect(registrations, hasLength(1));
      final registration = registrations.single;
      expect(registration.type.name, 'CrashReporter');
      expect(registration.create.name, 'createCrashReporter');
      expect(registration.create.deps, isEmpty);
      expect(registration.lifetime, DiLifetime.lazySingleton);
    });

    test(
        'installs the crash reporting between the start of Firebase and the '
        'registration of the services', () {
      expect(_startUpOf(result), [
        'firebase_core: $_initializeFirebase',
        'role:crash_reporting: installCrashReporting();',
        'role:di: await registerDependencies();',
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
            'impl0.createCrashlyticsCrashReporter',
            'impl1.createOtherCrashReporter',
          ],
        ),
        (
          const [_OtherReporterModule.id, FirebaseCrashlyticsModule.id],
          [
            'impl0.createOtherCrashReporter',
            'impl1.createCrashlyticsCrashReporter',
          ],
        ),
      ]) {
        final result = await _resultOf(modules, registry: registry);

        expect(_reportersOf(result.app!), reporters, reason: '$modules');
        expect(
          _startUpOf(result),
          [
            'firebase_core: $_initializeFirebase',
            'role:crash_reporting: installCrashReporting();',
          ],
          reason: '$modules',
        );
      }
    });
  });
}
