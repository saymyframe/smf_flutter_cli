@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_sentry/bundles/sentry_bundle.dart';
import 'package:smf_sentry/smf_sentry.dart';
import 'package:smf_sentry/src/agents.dart';
import 'package:smf_sentry/src/readme.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, dart_define, a provider of the env role, which it requires, and
/// get_it, a DI container, which registers the reporter in the apps that have
/// it.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  DartDefineModule(),
  GetItModule(),
  SentryModule(),
];

/// The owner of the file of the module.
const _sentry = ModuleOrigin(SentryModule.id);

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _resultOf(List<ModuleId> modules) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The inline code of [markdown]: what stands between two backticks,
/// outside its blocks of code.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(
        markdown.replaceAll(RegExp(r'```[\s\S]*?```'), ''),
      ))
        match[1]!,
    };

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

/// The function [name] of [unit].
FunctionDeclaration _functionOf(CompilationUnit unit, String name) =>
    unit.declarations.whereType<FunctionDeclaration>().singleWhere(
          (function) => function.name.lexeme == name,
        );

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

/// Collects the nodes of a kind that a unit has.
final class _Nodes<T extends AstNode> extends GeneralizingAstVisitor<void> {
  final List<T> found = [];

  @override
  void visitNode(AstNode node) {
    if (node is T) found.add(node);
    super.visitNode(node);
  }
}

/// The nodes of the type [T] in [node].
List<T> _nodesIn<T extends AstNode>(AstNode node) {
  final nodes = _Nodes<T>();
  node.accept(nodes);
  return nodes.found;
}

/// The types of the mechanisms that [node] creates, as written. A unit that
/// is parsed and not resolved has the call of a constructor without `new` as
/// an invocation of a method.
List<String> _mechanismsIn(AstNode node) => [
      for (final call in _nodesIn<MethodInvocation>(node))
        if (call.target == null && call.methodName.name == 'Mechanism')
          for (final argument in call.argumentList.arguments)
            if (argument is NamedArgument && argument.name.lexeme == 'type')
              '${argument.argumentExpression}',
    ];

void main() {
  const module = SentryModule();

  group('SentryModule', () {
    test(
        'is infrastructure that provides the crash reporting and requires the '
        'env role, for its DSN', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('sentry'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {crashReportingRole});
      expect(descriptor.requires, {envRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
      expect(descriptor.selectedByDefault, isFalse);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick with the variables of its key and of the '
        'texts of its hint, sentry_flutter, its implementation of the '
        'reporter, which starts asynchronously, its key, its step by hand, its '
        'section of the README and its note for coding agents, and nothing '
        'else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(7));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(sentryBundle));
      expect(brick.bundle.name, 'sentry');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [reporterFile],
      );
      expect(brick.vars.keys, [
        'env_sentry_dsn',
        'default_flavor',
        'values_heading',
        'readme_heading',
      ]);
      final dsn = brick.vars['env_sentry_dsn']! as RoleVar;
      expect((dsn.role, dsn.absent), (envRole, 'null'));
      expect(brick.vars['default_flavor'], AppEntryRole.defaultFlavor.name);
      expect(brick.vars['values_heading'], EnvRole.readmeHeading);
      expect(brick.vars['readme_heading'], readmeHeading);
      final plugin = contributions[1] as PubspecDependency;
      expect(
        (plugin.package, plugin.constraint, plugin.dev),
        ('sentry_flutter', '^10.4.0', false),
      );
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, crashReportingRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isTrue);
      expect(implementation.type.name, 'SentryCrashReporter');
      expect(implementation.init!.name, 'initSentryCrashReporter');
      expect(implementation.init!.deps, isEmpty);
      expect(implementation.init!.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', reporterFile);
      final key = contributions[3] as RoleData<Object>;
      expect((key.role, key.value), (envRole, SentryModule.dsnKey));
      expect(contributions[4], SentryModule.dsnStep);
      final readme = contributions[5] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect((readme.entryKey, readme.entryValue), ('Sentry', readmeSection));
      final note = contributions[6] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, crashReportingRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      for (final contribution in contributions) {
        expect(contribution.when, isEmpty, reason: '$contribution');
      }
    });

    test(
        'has the key of the DSN of the Sentry project, which the env role '
        'takes, and its step by hand under an id of its own', () {
      const key = SentryModule.dsnKey;

      expect(
        '${key.name} ${key.getter}: ${key.description}',
        'SENTRY_DSN sentryDsn: The DSN of your Sentry project, which the crash '
            'reports go to',
      );
      expect(key.problems(), isEmpty);
      expect(
        (SentryModule.dsnStep.id.wire, SentryModule.dsnStep.title),
        (
          'sentry.dsn',
          'Create a Flutter project in Sentry and copy its DSN into .env',
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
        'builds the apps of the module with a DI container and without, each '
        'with the provider of the env role', () async {
      expect(
        [
          for (final result in results)
            if (result.contractCase.requested.contains(SentryModule.id))
              result.contractCase.name,
        ],
        ['sentry with di', 'sentry'],
      );
      for (final result in results) {
        if (!result.contractCase.requested.contains(SentryModule.id)) continue;
        expect(
          result.resolution!.modules.map((module) => module.id),
          contains(DartDefineModule.id),
          reason: '${result.contractCase}',
        );
      }
      expect(
        await ContractHarness(ModuleRegistry(_modules)).uncheckedProviders(),
        isEmpty,
      );
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

    test('lists the step by hand of the module in each app of the module', () {
      for (final result in results) {
        if (!result.contractCase.requested.contains(SentryModule.id)) continue;
        expect(
          [
            for (final planned in result.manualSteps)
              if (planned.contributors.contains(_sentry)) planned.step,
          ],
          [SentryModule.dsnStep],
          reason: '${result.contractCase}',
        );
      }
    });
  });

  group('an app with the module', () {
    late ContractResult result;
    late RenderedApp app;
    late CompilationUnit unit;

    setUpAll(() async {
      result = await _resultOf(const [SentryModule.id]);
      app = result.app!;
      unit = parseString(content: app.files[reporterFile]!.text).unit;
    });

    test(
        'has the reporter of the module, the only file of the app that '
        'imports sentry_flutter, which is in its pubspec', () {
      final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;

      expect(
        [
          for (final file in app.files.values)
            if (file.owner == _sentry) file.path,
        ],
        [reporterFile],
      );
      expect(
        (pubspec['dependencies'] as YamlMap)['sentry_flutter'],
        '^10.4.0',
      );
      expect(
        [
          for (final file in app.files.values)
            if (file.path.endsWith('.dart') &&
                file.text.contains('package:sentry_flutter/'))
              file.path,
        ],
        [reporterFile],
      );
      // Only the library that sentry_flutter exports, not one of its src/.
      expect(
        [
          for (final import in unit.directives.whereType<ImportDirective>())
            if (import.uri.stringValue!.startsWith('package:sentry_flutter/'))
              import.uri.stringValue,
        ],
        ['package:sentry_flutter/sentry_flutter.dart'],
      );
    });

    test(
        'awaits the start of Sentry in bootstrap() before it installs the '
        'handlers of the crash reporting', () {
      expect(
        [
          for (final code in _startUpOf(result))
            if (code.startsWith('role:crash_reporting:')) code,
        ],
        [
          [
            'role:crash_reporting: await initCrashReporting();',
            'installCrashReporting();',
          ].join('\n'),
        ],
      );
      final reporter = app.files[CrashReportingRole.file]!.text;
      expect(
        reporter,
        contains("_startAlone('initSentryCrashReporter', "
            'impl0.initSentryCrashReporter),'),
      );
    });

    test(
        'reads the DSN of .env through AppEnv, and throws without one a '
        'StateError that names the key and the sections of the README', () {
      final start = _functionOf(unit, 'initSentryCrashReporter');
      final dsn = _nodesIn<VariableDeclaration>(start).first;

      expect(
        '${dsn.name.lexeme} = ${dsn.initializer}',
        'dsn = AppEnv.sentryDsn',
      );
      final missing = _nodesIn<IfStatement>(start).first;
      expect('${missing.expression}', 'dsn == null');
      final thrown = _nodesIn<ThrowExpression>(missing.thenStatement).single;
      final error = thrown.expression as MethodInvocation;
      expect(error.methodName.name, 'StateError');
      final text = error.argumentList.arguments.single as StringLiteral;
      expect(
        text.stringValue,
        allOf(
          startsWith('SENTRY_DSN has no value in this build'),
          contains('the section "${EnvRole.readmeHeading}" of its README'),
          contains('The section "$readmeHeading" tells more.'),
        ),
      );
    });

    test(
        'starts Sentry with the environment of the flavor, without its log, '
        'its default PII, its screenshots and its print breadcrumbs, and '
        'calls the hook of the tests last', () {
      final start = _functionOf(unit, 'initSentryCrashReporter');
      final init = _nodesIn<MethodInvocation>(start).firstWhere(
        (call) => '${call.target}.${call.methodName}' == 'SentryFlutter.init',
      );
      final assignments = [
        for (final assignment in _nodesIn<AssignmentExpression>(init))
          '$assignment',
      ];

      expect(assignments, [
        'dsn = dsn',
        "environment = appFlavor ?? 'dev'",
        'debug = false',
        'sendDefaultPii = false',
        'attachScreenshot = false',
        'attachViewHierarchy = false',
        'enablePrintBreadcrumbs = false',
      ]);
      final calls = [
        for (final call in _nodesIn<MethodInvocation>(init)) '$call',
      ];
      expect(calls.last, 'configureSentryForTests?.call(options)');
    });

    test(
        'removes the integration of Sentry that takes '
        'PlatformDispatcher.instance.onError by its type, which a build with '
        '--obfuscate keeps, and puts back the FlutterError.onError that it '
        'found, whatever the start does', () {
      final start = _functionOf(unit, 'initSentryCrashReporter');
      final source = '$start';

      expect(source, contains('whereType<OnErrorIntegration>()'));
      expect(source, contains('options.removeIntegration(integration)'));
      // A name of a type, which --obfuscate changes, matches nothing.
      expect(source, isNot(contains('runtimeType')));
      final kept = _nodesIn<VariableDeclaration>(start)
          .singleWhere((variable) => variable.name.lexeme == 'flutterErrors');
      expect('${kept.initializer}', 'FlutterError.onError');
      final attempt = _nodesIn<TryStatement>(start).single;
      expect(
        _nodesIn<MethodInvocation>(attempt.body)
            .map((call) => '${call.target}.${call.methodName}'),
        contains('SentryFlutter.init'),
      );
      expect(
        '${attempt.finallyBlock}',
        '{FlutterError.onError = flutterErrors;}',
      );
      expect(attempt.catchClauses, isEmpty);
      // The variable is read before the try, so the handler is the one that
      // the start found.
      expect(kept.offset, lessThan(attempt.offset));
    });

    test(
        'reports each kind of call to Sentry with a mechanism of its own, '
        'fatal as unhandled, and prints nothing', () {
      final methods = _methodsOf(unit, 'SentryCrashReporter');

      expect(methods.keys.toSet(), {
        'recordError',
        'recordFlutterError',
        'log',
        'setUserId',
      });
      expect(_mechanismsIn(methods['recordError']!), [
        "'CrashReporter.recordError'",
      ]);
      expect(_mechanismsIn(methods['recordFlutterError']!), [
        "'CrashReporter.recordFlutterError'",
      ]);
      for (final name in ['recordError', 'recordFlutterError']) {
        expect('${methods[name]}', contains('handled: !fatal'), reason: name);
        expect(
          '${methods[name]}',
          contains('fatal ? SentryLevel.fatal : SentryLevel.error'),
          reason: name,
        );
      }
      expect('${methods['log']}', contains('Sentry.addBreadcrumb('));
      expect('${methods['setUserId']}', contains('SentryUser(id: userId)'));
      final file = app.files[reporterFile]!.text;
      for (final printing in ['print(', 'debugPrint(', 'presentError']) {
        expect(file, isNot(contains(printing)), reason: printing);
      }
    });

    group('the section of the module in the README of the app', () {
      test('is in the README, which has the section of the values in .env', () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;

        expect(readme, contains('\n## $readmeHeading\n\n$readmeSection'));
        expect(readme, contains('\n## ${EnvRole.readmeHeading}\n'));
        expect(readme, contains('\n## ${AppEntryRole.setupHeading}\n'));
      });

      test(
          'tells of the DSN, the projects of development and of the release, '
          'the environment, the debug builds and the line that keeps them out, '
          'what reaches Sentry with the sessions, the native crashes next to '
          'another crash reporter, the quota, the symbols and the privacy '
          'policy', () {
        expect(
          readmeSection,
          allOf([
            contains('Keep a second project for development'),
            contains('the environment `prod` of your CI'),
            contains('give the key of the DSN a rate limit'),
            contains('A debug build sends its events too.'),
            contains("if (kDebugMode) throw StateError('Sentry reports "
                "nothing from a debug build.');"),
            contains('An error that comes before Sentry has started in '
                '`bootstrap()` is not reported'),
            contains('a session, from which Sentry counts the users'),
            contains('Next to another crash reporter'),
            contains('monthly quota of errors'),
            contains('sentry-cli debug-files upload --org <org> --project '
                '<project> build/ios/archive/Runner.xcarchive/dSYMs'),
            contains('id("io.sentry.android.gradle") version "6.27.0"'),
            contains('autoUploadProguardMapping.set(providers.'
                'environmentVariable("SENTRY_AUTH_TOKEN").isPresent)'),
            contains('telemetry.set(false)'),
            contains('autoInstallation { enabled.set(false) }'),
            contains('tracingInstrumentation { enabled.set(false) }'),
            contains('--save-obfuscation-map=build/app/obfuscation.map.json'),
            contains('dart_symbol_map_path: build/app/obfuscation.map.json'),
            contains('dart run sentry_dart_plugin'),
            contains('For the privacy policy of the app, which the App Store '
                'and Google Play ask for'),
            contains('Prevent Storing of IP Addresses'),
          ]),
        );
        expect(
          _codeOf(readmeSection),
          containsAll([
            reporterFile,
            SentryModule.dsnKey.name,
            EnvRole.dotEnvFile,
            'initSentryCrashReporter()',
            'recordError()',
            'log()',
            'setUserId()',
            'SENTRY_AUTH_TOKEN',
          ]),
        );
        // It names no other crash reporter, which only its own module knows.
        expect(readmeSection.toLowerCase(), isNot(contains('crashlytics')));
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the crash reporting of the guide, after what '
          'the role says', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);

        expect(
          [
            for (final (origin, heading, note) in notes)
              if (origin == _sentry) (heading, note),
          ],
          [(crashReportingRole.description, AgentNote(agentNote))],
        );
        expect(agentNote, startsWith('With `sentry_flutter`:\n'));
        final guide = app.files[AppEntryRole.agentsFile]!.text;
        expect(guide, contains('\n${agentNote.trim()}\n'));
        expect(
          guide.indexOf(agentNote.trim()),
          greaterThan(
            guide.indexOf('\n## ${crashReportingRole.description}\n'),
          ),
        );
      });

      test('names the file of the module and what it declares and calls', () {
        final index = DartFileIndexer.index(
          reporterFile,
          app.files[reporterFile]!.text,
        );

        expect(
          _codeOf(agentNote),
          containsAll([
            reporterFile,
            'initSentryCrashReporter()',
            SentryModule.dsnKey.name,
            EnvRole.dotEnvFile,
            'bootstrap()',
            'CrashReporter',
            'Sentry.captureException',
            'SentryFlutter.init',
            'OnErrorIntegration',
            'FlutterError.onError',
            'appFlavor',
            'configureSentryForTests',
            'beforeSend',
            'transport',
          ]),
        );
        for (final name in [
          'initSentryCrashReporter',
          'SentryCrashReporter',
          'configureSentryForTests',
        ]) {
          expect(index.declaration(name), isNotNull, reason: name);
        }
        for (final used in [
          'Sentry.captureException',
          'SentryFlutter.init',
          'OnErrorIntegration',
          'FlutterError.onError',
          'appFlavor',
        ]) {
          expect(app.files[reporterFile]!.text, contains(used), reason: used);
        }
      });
    });

    test('has a README that leads to the page of the module', () {
      expect(
        File('README.md').readAsStringSync(),
        contains('(https://doc.saymyframe.com/modules/sentry)'),
      );
    });
  });
}
