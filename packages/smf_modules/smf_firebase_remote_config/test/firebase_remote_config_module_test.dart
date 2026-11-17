@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_remote_config/bundles/firebase_remote_config_bundle.dart';
import 'package:smf_firebase_remote_config/smf_firebase_remote_config.dart';
import 'package:smf_firebase_remote_config/src/agents.dart';
import 'package:smf_firebase_remote_config/src/readme.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// A module of the tests that reads a parameter of remote config, as a
/// feature of an app does, so that the app has a parameter.
final class _ReaderModule extends SmfModule {
  const _ReaderModule();

  static const id = ModuleId('config_reader');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A parameter of remote config (test)',
        kind: ModuleKinds.infrastructure,
        requires: {remoteConfigRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        remoteConfigRole.data(
          const RemoteConfigKey.text(
            'config_reader_greeting',
            defaultValue: 'Hello',
            description: 'The greeting of the test',
          ),
        ),
      ];
}

/// The library of firebase_remote_config that the service imports.
const _plugin = 'package:firebase_remote_config/firebase_remote_config.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module and firebase_core, which it depends on.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  FirebaseCoreModule(),
  FirebaseRemoteConfigModule(),
];

/// The owners of the code of remote config: this module and the template
/// of its role.
final Set<ContributionOrigin> _remoteConfig = {
  const ModuleOrigin(FirebaseRemoteConfigModule.id),
  const RoleTemplateOrigin(remoteConfigRole),
};

/// What the contract harness finds for the app of [modules] among the
/// modules of the tests and [more], which has no errors and is rendered.
Future<ContractResult> _resultOf(
  List<ModuleId> modules, {
  List<SmfModule> more = const [],
}) async {
  final result = await ContractHarness(
    ModuleRegistry([..._modules, ...more]),
  ).check(ContractCase(modules.join(', '), requested: modules));
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

/// The parsed file at [path] of [app].
CompilationUnit _unitOf(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

/// The members of the class [name] in [unit] that the class declares with
/// the signature of a member of an interface, each with that signature: a
/// method or a getter, and a field, which implements a getter.
Map<String, String> _membersOf(CompilationUnit unit, String name) {
  final declaration =
      unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (declaration) => declaration.namePart.typeName.lexeme == name,
          );
  return {
    for (final member in declaration.body.members)
      if (member is MethodDeclaration && !member.name.lexeme.startsWith('_'))
        member.name.lexeme: '${member.returnType} '
            '${member.propertyKeyword == null ? '' : 'get '}'
            '${member.parameters ?? ''}'
      else if (member is FieldDeclaration)
        for (final variable in member.fields.variables)
          if (!variable.name.lexeme.startsWith('_'))
            variable.name.lexeme: '${member.fields.type} get ',
  };
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
/// phases of start-up in the app of [result], phase after phase, each as
/// its contributor and its code: what `bootstrap()` runs, whichever module
/// provides the app entry.
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

/// Runs the service of the module on the stand-in for
/// firebase_remote_config, and sends back what reached the platform for each
/// call and what each call ended with, the values of the service, and the
/// updates that it told of.
///
/// It imports the file of the module and the file of the role with
/// `RemoteConfigService`, which need nothing but the stand-ins.
const _script = r'''
import 'dart:async';
import 'dart:isolate';

import 'package:contract_app/core/remote_config/firebase_remote_config_service.dart';
import 'package:contract_app/core/remote_config/remote_config_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Lets the events of the streams reach their listeners.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// What reached the platform while [action] ran, and what it ended with.
Future<List<Object?>> step(Future<Object?> Function() action) async {
  firebaseCalls.clear();
  Object? outcome;
  try {
    outcome = await action();
  } on Object catch (error) {
    outcome = 'threw $error';
  }
  return [...firebaseCalls, if (outcome != null) '= $outcome'];
}

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};

  late RemoteConfigService service;
  result['create'] = await step(() async {
    service = createFirebaseRemoteConfigService();
    await settle();
    return null;
  });
  result['implementation'] = '${service.runtimeType}';
  result['open'] = await step(
    () => service.open(
      {
        'shop_greeting': 'Hello',
        'shop_enabled': true,
        'shop_limit': 3,
        'shop_ratio': 0.5,
      },
      fetchInterval: const Duration(hours: 12),
      fetchTimeout: const Duration(seconds: 10),
    ),
  );
  result['values after the start'] = service.values;

  project = {'shop_greeting': 'Hi', 'other_parameter': 'of the project'};
  result['fetch'] = await step(service.fetch);
  result['values after the fetch'] = service.values;
  result['activate'] = await step(service.activate);
  result['values after the activation'] = service.values;
  result['activate again'] = await step(service.activate);

  failNext['fetch'] = FirebaseException(
    plugin: 'firebase_remote_config',
    code: 'internal',
    message: 'Failed to get installations token.',
  );
  result['fetch that fails'] = await step(service.fetch);
  failNext['activate'] = StateError('The platform broke.');
  result['activate that fails'] = await step(service.activate);
  result['values after the failures'] = service.values;

  result['live updates'] = service.liveUpdates;
  final updates = service.updates;
  result['broadcast'] = updates.isBroadcast;
  final heard = <String>[];
  firebaseCalls.clear();
  final first = updates.listen((_) => heard.add('first'));
  final second = service.updates.listen((_) => heard.add('second'));
  await settle();
  result['listening'] = [...firebaseCalls];
  project = {...project, 'shop_limit': '5'};
  platformUpdates({'shop_limit'});
  platformUpdates({'shop_limit'});
  await settle();
  result['updates'] = heard;
  result['values before the activation of the update'] = service.values;
  result['activate the update'] = await step(service.activate);
  result['values after the activation of the update'] = service.values;
  firebaseCalls.clear();
  await first.cancel();
  await second.cancel();
  result['cancelling'] = [...firebaseCalls];

  port.send(result);
}
''';

void main() {
  const module = FirebaseRemoteConfigModule();

  group('FirebaseRemoteConfigModule', () {
    test(
        'is infrastructure that provides the remote config role, and depends '
        'on firebase_core', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('firebase_remote_config'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {remoteConfigRole});
      expect(descriptor.dependsOn, {FirebaseCoreModule.id});
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.effectiveUses, isEmpty);
      expect(descriptor.variants, isNull);
      expect(descriptor.selectedByDefault, isFalse);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
      expect(
        ModuleRegistry.problemsOf([..._modules, const _ReaderModule()]),
        isEmpty,
      );
    });

    test(
        'contributes its brick, firebase_remote_config 6.7, its '
        'implementation of the service, created with the app, its section of '
        'the README and its note for coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(5));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(firebaseRemoteConfigBundle));
      expect(brick.bundle.name, 'firebase_remote_config');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [serviceFile],
      );
      expect(brick.vars, isEmpty);
      final plugin = contributions[1] as PubspecDependency;
      // firebase_remote_config 6.7 is the last version on firebase_core 4,
      // which the Firebase modules share.
      expect(
        (plugin.package, plugin.constraint, plugin.dev),
        ('firebase_remote_config', '^6.7.1', false),
      );
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, remoteConfigRole);
      final implementation = data.value as RemoteConfigImplementation;
      expect(implementation.type.name, 'FirebaseRemoteConfigService');
      expect(implementation.create.name, 'createFirebaseRemoteConfigService');
      expect(implementation.create.deps, isEmpty);
      expect(
        implementation.type.import,
        const ImportRef.app(
          'core/remote_config/firebase_remote_config_service.dart',
        ),
      );
      expect(implementation.create.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', serviceFile);
      final readme = contributions[3] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, readmeHeading);
      expect(readme.entryValue, readmeSection);
      final note = contributions[4] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, remoteConfigRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      for (final contribution in contributions) {
        expect(contribution.when, isEmpty, reason: '$contribution');
      }
    });

    test(
        'has the step by hand in which the developer creates the parameters '
        'of the app in Firebase', () {
      const step = FirebaseRemoteConfigModule.parametersStep;

      expect(
        step.id,
        const ManualStepId(FirebaseRemoteConfigModule.id, 'parameters'),
      );
      expect(step.id.wire, 'firebase_remote_config.parameters');
      expect(
        step.title,
        'Create the parameters of the app in Firebase Remote Config',
      );
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds one app of the module', () async {
      expect(
        [
          for (final result in results)
            if (result.contractCase.requested
                .contains(FirebaseRemoteConfigModule.id))
              result.contractCase.name,
        ],
        ['firebase_remote_config'],
      );
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

    test('renders the service, which type-checks with firebase_remote_config',
        () async {
      final result = results.singleWhere(
        (result) => result.contractCase.requested
            .contains(FirebaseRemoteConfigModule.id),
      );
      expect(
        [
          for (final file in result.app!.files.values)
            if (file.owner == const ModuleOrigin(FirebaseRemoteConfigModule.id))
              file.path,
        ],
        [serviceFile],
      );
      final app = DartApp.write(result.app!);
      try {
        expect(
          await app.analysisProblems(
            {const ModuleOrigin(FirebaseRemoteConfigModule.id)},
          ),
          isEmpty,
        );
      } finally {
        app.delete();
      }
    });
  });

  group('an app with the module', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [FirebaseRemoteConfigModule.id]);
      app = result.app!;
      without = (await _resultOf(const [FirebaseCoreModule.id])).app!;
    });

    test(
        'is the app of Firebase but for the files of the remote config role, '
        'the service, firebase_remote_config, the start of remote config, '
        'and the sections of remote config in the README and in the guide '
        'for coding agents', () {
      expect(app.files.keys.toSet(), {
        ...without.files.keys,
        ...remoteConfigRole.interface.files,
        serviceFile,
      });
      expect(
        app.files[serviceFile]!.owner,
        const ModuleOrigin(FirebaseRemoteConfigModule.id),
      );
      final changed = <String>[];
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        expect(app.files[path]!.owner, file.owner, reason: path);
        if (app.files[path]!.text != file.text) changed.add(path);
      }
      // The provider of the app entry renders the start-up, which now starts
      // remote config, into a file of its own, whichever module it is.
      final entries = {
        for (final module in result.resolution!.providersOf(appEntryRole))
          ModuleOrigin(module.id),
      };
      final startUp = [
        for (final path in changed)
          if (entries.contains(app.files[path]!.owner) &&
              app.files[path]!.addedImports.any(
                (added) =>
                    added.contributor ==
                    const RoleTemplateOrigin(remoteConfigRole),
              ))
            path,
      ];
      expect(startUp, hasLength(1));
      expect(
        changed.toSet().difference(startUp.toSet()),
        {'pubspec.yaml', AppEntryRole.readmeFile, AppEntryRole.agentsFile},
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['dependencies'],
        {
          ...(_yamlOf(without.files['pubspec.yaml']!.text)['dependencies']!
              as Map<String, Object?>),
          'firebase_remote_config': '^6.7.1',
        },
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['environment'],
        _yamlOf(without.files['pubspec.yaml']!.text)['environment'],
      );
    });

    test(
        'starts remote config in bootstrap() once Firebase started, with the '
        'service created without waiting', () {
      expect(_startUpOf(result), [
        equals(
          'firebase_core: await Firebase.initializeApp(options: '
          'firebaseOptionsOfFlavor);',
        ),
        'role:remote_config: await initRemoteConfig();',
      ]);
      final init = _unitOf(app, RemoteConfigRole.controllerFile)
          .declarations
          .whereType<FunctionDeclaration>()
          .singleWhere(
            (function) => function.name.lexeme == 'initRemoteConfig',
          );
      final body = init.functionExpression.body as BlockFunctionBody;
      expect(
        [for (final statement in body.block.statements) '$statement'],
        [
          '_remoteConfigService = impl0.createFirebaseRemoteConfigService();',
          'await appRemoteConfig.start(_remoteConfigService);',
        ],
      );
    });

    test(
        'lists no step by hand while the app has no parameter, and the step '
        'of the parameters once a module gives the role one, first in the '
        'README', () async {
      final withParameter = await _resultOf(
        const [FirebaseRemoteConfigModule.id, _ReaderModule.id],
        more: const [_ReaderModule()],
      );

      expect(result.manualSteps, isEmpty);
      expect(
        app.files[AppEntryRole.readmeFile]!.text,
        isNot(contains('\n## ${AppEntryRole.setupHeading}\n')),
      );
      final [parameters] = withParameter.manualSteps;
      expect(parameters.step, same(FirebaseRemoteConfigModule.parametersStep));
      expect(
        parameters.contributors,
        [const ModuleOrigin(FirebaseRemoteConfigModule.id)],
      );
      final readme = withParameter.app!.files[AppEntryRole.readmeFile]!.text;
      expect(
        RegExp(r'^## (.+)$', multiLine: true).firstMatch(readme)?[1],
        AppEntryRole.setupHeading,
      );
      expect(
        readme,
        contains('\n1. ${FirebaseRemoteConfigModule.parametersStep.title}\n'),
      );
    });

    group('the implementation', () {
      late CompilationUnit unit;

      setUpAll(() => unit = _unitOf(app, serviceFile));

      test(
          'is the service of the role on FirebaseRemoteConfig, which '
          'createFirebaseRemoteConfigService() creates', () {
        final declaration =
            unit.declarations.whereType<ClassDeclaration>().singleWhere(
                  (declaration) =>
                      declaration.namePart.typeName.lexeme ==
                      'FirebaseRemoteConfigService',
                );
        expect(
          '${declaration.implementsClause!.interfaces.single}',
          'RemoteConfigService',
        );
        final create = unit.declarations
            .whereType<FunctionDeclaration>()
            .singleWhere(
              (function) =>
                  function.name.lexeme == 'createFirebaseRemoteConfigService',
            );
        expect('${create.returnType}', 'RemoteConfigService');
        expect(create.functionExpression.parameters!.parameters, isEmpty);
        expect(
          [
            for (final directive
                in unit.directives.whereType<ImportDirective>())
              '$directive',
          ],
          [
            "import '$_plugin';",
            "import 'remote_config_service.dart';",
          ],
        );
      });

      test(
          'implements every member of the service with the signature of the '
          'interface', () {
        final interface = _membersOf(
          _unitOf(app, RemoteConfigRole.serviceFile),
          'RemoteConfigService',
        );

        expect(interface, hasLength(6));
        expect(_membersOf(unit, 'FirebaseRemoteConfigService'), interface);
      });
    });

    group('the service', () {
      late Map<Object?, Object?> sent;

      setUpAll(() async {
        final dartApp = DartApp.write(app);
        try {
          sent = (await dartApp.run(_script))! as Map<Object?, Object?>;
        } finally {
          dartApp.delete();
        }
      });

      test('is created without a call of the platform', () {
        expect(sent['implementation'], 'FirebaseRemoteConfigService');
        expect(sent['create'], isEmpty);
      });

      test(
          'opens with what the device kept, then gives Firebase the timeout '
          'and the interval of a fetch and the defaults of the app, of their '
          'types', () {
        expect(sent['open'], [
          'ensureInitialized()',
          equals(
            'setConfigSettings(fetch timeout 0:00:10.000000, minimum fetch '
            'interval 12:00:00.000000)',
          ),
          equals(
            'setDefaults(shop_greeting: Hello (String), shop_enabled: true '
            '(bool), shop_limit: 3 (int), shop_ratio: 0.5 (double))',
          ),
        ]);
      });

      test(
          'has the active values that the project gave, as texts, and never '
          'a default of the app', () {
        expect(sent['values after the start'], isEmpty);
        expect(sent['fetch'], ['fetch()']);
        expect(
          sent['values after the fetch'],
          isEmpty,
          reason: 'A fetch keeps the values until an activation.',
        );
        expect(sent['activate'], ['activate()', '= true']);
        expect(sent['values after the activation'], {
          'shop_greeting': 'Hi',
          'other_parameter': 'of the project',
        });
        expect(sent['activate again'], ['activate()', '= false']);
      });

      test('passes the errors of Firebase on as they are', () {
        expect(sent['fetch that fails'], [
          'fetch()',
          equals(
            '= threw [firebase_remote_config/internal] Failed to get '
            'installations token.',
          ),
        ]);
        expect(sent['activate that fails'], [
          'activate()',
          '= threw Bad state: The platform broke.',
        ]);
        expect(sent['values after the failures'], {
          'shop_greeting': 'Hi',
          'other_parameter': 'of the project',
        });
      });

      test(
          'tells of each real-time update of Firebase on a broadcast stream, '
          'which listens to Firebase while something listens to it, and the '
          'values change only once they are activated', () {
        expect(sent['live updates'], isTrue);
        expect(sent['broadcast'], isTrue);
        expect(sent['listening'], ['listen to updates']);
        expect(sent['updates'], ['first', 'second', 'first', 'second']);
        expect(sent['values before the activation of the update'], {
          'shop_greeting': 'Hi',
          'other_parameter': 'of the project',
        });
        expect(sent['activate the update'], ['activate()', '= true']);
        expect(sent['values after the activation of the update'], {
          'shop_greeting': 'Hi',
          'other_parameter': 'of the project',
          'shop_limit': '5',
        });
        expect(sent['cancelling'], ['cancel updates']);
      });
    });

    group('the section of the module in the README of the app', () {
      test('refers to the section of the remote config role', () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;

        expect(readme, contains('\n## $readmeHeading\n\n$readmeSection'));
        expect(
          readme,
          contains('\n## ${RemoteConfigRole.readmeHeading}\n'),
        );
        expect(
          readmeSection,
          contains('(see the section ${RemoteConfigRole.readmeHeading}, '),
        );
      });

      test(
          'tells where the parameters go, for the project of each flavor, '
          'and that the steps by hand list it', () {
        expect(
          readmeSection,
          allOf(
            contains('Firebase console of the project of each flavor'),
            contains('open Remote Config, add the parameter with the name, '
                'the type and the default'),
            contains('publish the changes'),
            contains('a condition of the platform'),
            contains('The section ${AppEntryRole.setupHeading} lists this '
                'among the steps that you do by hand once the app has a '
                'parameter.'),
          ),
        );
      });

      test(
          'names the two APIs of Google that the app needs, and the '
          'restrictions of the API keys of a project', () {
        expect(
          _codeOf(readmeSection),
          containsAll([
            'firebaseremoteconfig.googleapis.com',
            'firebaseremoteconfigrealtime.googleapis.com',
          ]),
        );
        expect(
          readmeSection,
          allOf(
            contains('Firebase Remote Config API'),
            contains('Firebase Remote Config Realtime API'),
            contains('answers 403 while it is disabled'),
            contains('API restrictions'),
            contains('APIs & Services, Credentials'),
            contains('each key must allow both APIs'),
          ),
        );
      });

      test(
          'tells how often the app fetches, and what fetches cost on the '
          'Spark and on the Blaze plan', () {
        expect(
          readmeSection,
          allOf(
            contains('A release build fetches at most every 12 hours'),
            contains('100,000 fetches a day for free'),
            contains('on the Spark plan is throttled'),
            contains('on the Blaze plan is billed'),
            contains('($pricingPage)'),
            contains('An app without parameters fetches nothing.'),
          ),
        );
      });

      test(
          'tells that each fetch sends the installation ID, and that the '
          'stores ask for a privacy policy that names Firebase Remote Config',
          () {
        expect(
          readmeSection,
          allOf(
            contains('Each fetch sends the Firebase installation ID'),
            contains('App Privacy details of App Store Connect'),
            contains('Data safety form of Google Play'),
            contains('link to the privacy policy of the app'),
            contains('name Firebase Remote Config there'),
          ),
        );
        expect(_codeOf(readmeSection), contains(serviceFile));
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of remote config of the guide, after what the '
          'role says', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);

        expect(
          {
            for (final (origin, heading, note) in notes)
              if (_remoteConfig.contains(origin))
                (origin, heading, note.isOfRole),
          },
          {
            (
              const ModuleOrigin(FirebaseRemoteConfigModule.id),
              remoteConfigRole.description,
              false,
            ),
            (
              const RoleTemplateOrigin(remoteConfigRole),
              remoteConfigRole.description,
              true,
            ),
          },
        );
        expect(agentNote, startsWith('With `firebase_remote_config`:\n'));
        final guide = app.files[AppEntryRole.agentsFile]!.text;
        expect(guide, contains('\n${agentNote.trim()}\n'));
        expect(
          guide.indexOf(agentNote.trim()),
          greaterThan(
            guide.indexOf('\n## ${remoteConfigRole.description}\n'),
          ),
        );
      });

      test(
          'names the file of the module, the only one of the app that '
          'imports the package, and what that file declares and calls', () {
        final service = DartFileIndexer.index(
          serviceFile,
          app.files[serviceFile]!.text,
        );

        expect(
          _codeOf(agentNote),
          containsAll([
            serviceFile,
            'FirebaseRemoteConfigService',
            'RemoteConfigService',
            'FirebaseRemoteConfig',
            'appRemoteConfig',
            'RemoteValues.defaults',
            'values',
            'source',
            'ValueSource.valueRemote',
            'getAll()',
            'updates',
            'onConfigUpdated',
            'activate()',
            'fetch()',
            'fetchAndActivate()',
            'bootstrap()',
            'setMockMessageHandler',
            equals(
              'dev.flutter.pigeon.firebase_remote_config_platform_interface.'
              'FirebaseRemoteConfigHostApi.<method>',
            ),
            'plugins.flutter.io/firebase_remote_config_updated',
            'appRemoteConfig.start()',
          ]),
        );
        expect(
          [
            for (final file in app.files.values)
              if (file.path.endsWith('.dart') &&
                  file.text.contains('package:firebase_remote_config/'))
                file.path,
          ],
          [serviceFile],
        );
        for (final name in [
          'FirebaseRemoteConfigService',
          'createFirebaseRemoteConfigService',
        ]) {
          expect(service.declaration(name), isNotNull, reason: name);
        }
        for (final call in [
          'getAll()',
          'ValueSource.valueRemote',
          'onConfigUpdated',
          '.activate()',
          '.fetch()',
        ]) {
          expect(app.files[serviceFile]!.text, contains(call), reason: call);
        }
        expect(
          app.files[serviceFile]!.text,
          isNot(contains('fetchAndActivate')),
        );
      });
    });

    test('has a README that leads to the page of the module', () {
      final readme = File('README.md').readAsStringSync();

      expect(
        readme,
        contains('(https://doc.saymyframe.com/modules/firebase-remote-config)'),
      );
    });
  });
}
