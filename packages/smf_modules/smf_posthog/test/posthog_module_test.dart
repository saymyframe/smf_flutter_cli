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
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_posthog/bundles/posthog_bundle.dart';
import 'package:smf_posthog/smf_posthog.dart';
import 'package:smf_posthog/src/agents.dart';
import 'package:smf_posthog/src/readme.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, dart_define, a provider of the env role, which it requires,
/// get_it, a DI container, which registers the service in the apps that
/// have it, and go_router, a router, which tells the listener of the module
/// about the screen the user sees in the apps that have it.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  DartDefineModule(),
  GetItModule(),
  GoRouterModule(),
  PostHogModule(),
];

/// The owner of the file of the module.
const _posthog = ModuleOrigin(PostHogModule.id);

/// The listener of the screen the user sees that the module gives the
/// router: a function of the file of the module.
const _listener = 'logPostHogScreen';

/// What the contract harness finds for the app of [modules], generated with
/// [roleOptions], which has no errors and is rendered.
Future<ContractResult> _resultOf(
  List<ModuleId> modules, {
  Map<String, String?> roleOptions = const {},
}) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(
      modules.join(', '),
      requested: modules,
      roleOptions: roleOptions,
    ),
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

/// The listeners of the screen that the router of the app of [result] calls,
/// each as its contributor and its code.
List<String> _listenersOf(ContractResult result) => [
      for (final collected in result
              .app!.socketOrders[RouterRole.screenListeners]?.contributions ??
          const <Collected>[])
        [
          '${collected.origin}:',
          (collected.contribution as SocketContribution).fragment!.code,
        ].join(' '),
    ];

/// The values of the meta-data [name] of the application in the manifest of
/// Android of [app].
List<String?> _metaDataOf(RenderedApp app, String name) {
  final application = XmlDocument.parse(
    app.files[AppEntryRole.androidManifestFile]!.text,
  ).rootElement.getElement('application')!;
  return [
    for (final element in application.findElements('meta-data'))
      if (element.getAttribute('android:name') == name)
        element.getAttribute('android:value'),
  ];
}

/// The values of the key [name] of `Info.plist` of [app], each as the name
/// of the element of its value.
List<String> _plistValuesOf(RenderedApp app, String name) {
  final entries = XmlDocument.parse(
    app.files[AppEntryRole.infoPlistFile]!.text,
  ).rootElement.getElement('dict')!.childElements.toList();
  return [
    for (final (index, element) in entries.indexed)
      if (element.name.local == 'key' && element.innerText == name)
        entries[index + 1].name.local,
  ];
}

/// The function [name] of [unit].
FunctionDeclaration _functionOf(CompilationUnit unit, String name) =>
    unit.declarations.whereType<FunctionDeclaration>().singleWhere(
          (function) => function.name.lexeme == name,
        );

/// The names of the functions of [unit].
List<String> _functionsOf(CompilationUnit unit) => [
      for (final function in unit.declarations.whereType<FunctionDeclaration>())
        function.name.lexeme,
    ];

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

/// The doc comment of [declaration] as one line of text, without its `///`.
String _docOf(AnnotatedNode declaration) => [
      for (final token in declaration.documentationComment?.tokens ?? const [])
        token.lexeme.replaceFirst(RegExp(r'^///\s?'), ''),
    ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

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

/// The calls of PostHog in [node], as written: `Posthog().<method>`.
List<String> _postHogCallsIn(AstNode node) => [
      for (final call in _nodesIn<MethodInvocation>(node))
        if ('${call.target}' == 'Posthog()') call.methodName.name,
    ];

void main() {
  const module = PostHogModule();

  group('PostHogModule', () {
    test(
        'is infrastructure that provides the analytics and requires the env '
        'role, for its keys', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('posthog'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {analyticsRole});
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
        'contributes its brick with the variables of its keys and of the '
        'texts of its hints, posthog_flutter, its implementation of the '
        'service, which starts asynchronously, its keys, its step by hand, '
        'the listener of the screen and its note in an app with a router, the '
        'native lines that keep PostHog from starting before Dart and from '
        'recording the push messages that the user opens, its section of the '
        'README and its note for coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(13));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(posthogBundle));
      expect(brick.bundle.name, 'posthog');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [serviceFile],
      );
      expect(brick.vars.keys, [
        'env_posthog_project_token',
        'env_posthog_host',
        'default_flavor',
        'values_heading',
        'readme_heading',
      ]);
      for (final key in ['env_posthog_project_token', 'env_posthog_host']) {
        final value = brick.vars[key]! as RoleVar;
        expect((value.role, value.absent), (envRole, 'null'), reason: key);
      }
      expect(brick.vars['default_flavor'], AppEntryRole.defaultFlavor.name);
      expect(brick.vars['values_heading'], EnvRole.readmeHeading);
      expect(brick.vars['readme_heading'], readmeHeading);
      final plugin = contributions[1] as PubspecDependency;
      expect(
        (plugin.package, plugin.constraint, plugin.dev),
        ('posthog_flutter', '^5.61.0', false),
      );
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, analyticsRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isTrue);
      expect(implementation.type.name, 'PostHogAnalyticsService');
      expect(implementation.init!.name, 'initPostHogAnalytics');
      expect(implementation.init!.deps, isEmpty);
      expect(implementation.init!.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', serviceFile);
      final token = contributions[3] as RoleData<Object>;
      expect(
        (token.role, token.value),
        (envRole, PostHogModule.projectTokenKey),
      );
      final host = contributions[4] as RoleData<Object>;
      expect((host.role, host.value), (envRole, PostHogModule.hostKey));
      expect(contributions[5], PostHogModule.projectTokenStep);
      final listener = contributions[6] as SocketContribution;
      expect(listener.socket, RouterRole.screenListeners);
      expect(listener.fragment!.code, _listener);
      expect(listener.when, {routerRole});
      final android = contributions[7] as SocketContribution;
      expect(android.socket, AppEntryRole.androidManifestApplicationMeta);
      expect(
        (android.entryKey, android.entryValue),
        ('com.posthog.posthog.AUTO_INIT', const AndroidMetaData.value('false')),
      );
      final autoInit = contributions[8] as SocketContribution;
      expect(autoInit.socket, AppEntryRole.infoPlist);
      expect(
        (autoInit.entryKey, autoInit.entryValue),
        ('com.posthog.posthog.AUTO_INIT', const PlistBoolean(false)),
      );
      final pushOpened = contributions[9] as SocketContribution;
      expect(pushOpened.socket, AppEntryRole.infoPlist);
      expect(
        (pushOpened.entryKey, pushOpened.entryValue),
        (
          'com.posthog.posthog.CAPTURE_PUSH_NOTIFICATION_OPENED',
          const PlistBoolean(false),
        ),
      );
      final readme = contributions[10] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect((readme.entryKey, readme.entryValue), ('PostHog', readmeSection));
      final note = contributions[11] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, analyticsRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      final screensNote = contributions[12] as SocketContribution;
      expect(screensNote.socket, AppEntryRole.agentSections);
      expect(screensNote.entryKey, analyticsRole.description);
      expect(screensNote.entryValue, AgentNote(screensAgentNote));
      expect(screensNote.when, {routerRole});
      for (final contribution in [
        ...contributions.take(6),
        ...contributions.skip(7).take(5),
      ]) {
        expect(contribution.when, isEmpty, reason: '$contribution');
      }
    });

    test(
        'has the keys of the project token and of the host of the PostHog '
        'project, which the env role takes, its step by hand under an id of '
        'its own, and the property of the flavor', () {
      const token = PostHogModule.projectTokenKey;
      const host = PostHogModule.hostKey;

      expect(
        [(token.name, token.getter), (host.name, host.getter)],
        [
          ('POSTHOG_PROJECT_TOKEN', 'posthogProjectToken'),
          ('POSTHOG_HOST', 'posthogHost'),
        ],
      );
      expect(
        token.description,
        'The project token of your PostHog project, which starts with phc_',
      );
      expect(
        host.description,
        'The host of your PostHog project: empty for US Cloud, '
        'https://eu.i.posthog.com for EU',
      );
      expect(PostHogModule.projectTokenKey.problems(), isEmpty);
      expect(PostHogModule.hostKey.problems(), isEmpty);
      expect(
        (
          PostHogModule.projectTokenStep.id.wire,
          PostHogModule.projectTokenStep.title,
        ),
        (
          'posthog.project_token',
          'Create a PostHog project and copy its token and host into .env',
        ),
      );
      expect(PostHogModule.flavorProperty, 'app_flavor');
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the apps of the module with and without a DI container and a '
        'router, and one that collects nothing before its code chose, each '
        'with the provider of the env role', () async {
      expect(
        [
          for (final result in results)
            if (result.contractCase.requested.contains(PostHogModule.id))
              result.contractCase.name,
        ],
        [
          'posthog with di, router',
          'posthog with di',
          'posthog with router',
          'posthog',
          'analytics by posthog with di, router --analytics-collection=off',
        ],
      );
      for (final result in results) {
        if (!result.contractCase.requested.contains(PostHogModule.id)) continue;
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
        if (!result.contractCase.requested.contains(PostHogModule.id)) continue;
        expect(
          [
            for (final planned in result.manualSteps)
              if (planned.contributors.contains(_posthog)) planned.step,
          ],
          [PostHogModule.projectTokenStep],
          reason: '${result.contractCase}',
        );
      }
    });

    test(
        'keeps PostHog from starting before Dart in every app of the module, '
        'and from recording the push messages that the user opens on iOS', () {
      for (final result in results) {
        if (!result.contractCase.requested.contains(PostHogModule.id)) continue;
        final app = result.app!;
        expect(
          _metaDataOf(app, PostHogModule.autoInitKey),
          ['false'],
          reason: '${result.contractCase}',
        );
        expect(
          _plistValuesOf(app, PostHogModule.autoInitKey),
          ['false'],
          reason: '${result.contractCase}',
        );
        expect(
          _plistValuesOf(app, PostHogModule.pushOpenedKey),
          ['false'],
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
      result = await _resultOf(const [PostHogModule.id]);
      app = result.app!;
      unit = parseString(content: app.files[serviceFile]!.text).unit;
    });

    test(
        'has the service of the module, the only file of the app that imports '
        'posthog_flutter, which is in its pubspec', () {
      final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;

      expect(
        [
          for (final file in app.files.values)
            if (file.owner == _posthog) file.path,
        ],
        [serviceFile],
      );
      expect(
        (pubspec['dependencies'] as YamlMap)['posthog_flutter'],
        '^5.61.0',
      );
      expect(
        [
          for (final file in app.files.values)
            if (file.path.endsWith('.dart') &&
                file.text.contains('package:posthog_flutter/'))
              file.path,
        ],
        [serviceFile],
      );
      // Only the library that posthog_flutter exports, not one of its src/.
      expect(
        [
          for (final import in unit.directives.whereType<ImportDirective>())
            if (import.uri.stringValue!.startsWith('package:posthog_flutter/'))
              import.uri.stringValue,
        ],
        ['package:posthog_flutter/posthog_flutter.dart'],
      );
    });

    test('awaits the start of PostHog in bootstrap()', () {
      expect(
        [
          for (final code in _startUpOf(result))
            if (code.startsWith('role:analytics:')) code,
        ],
        ['role:analytics: await initAnalytics();'],
      );
      expect(
        app.files[AnalyticsRole.file]!.text,
        contains("_startAlone('initPostHogAnalytics', "
            'impl0.initPostHogAnalytics),'),
      );
    });

    test(
        'reads the project token and the host of .env through AppEnv, and '
        'throws without a token, or with a host that is no web address, a '
        'StateError that names the key and the sections of the README', () {
      final start = _functionOf(unit, 'initPostHogAnalytics');
      final variables = _nodesIn<VariableDeclaration>(start);

      expect(
        [
          for (final variable in variables.take(2))
            '${variable.name.lexeme} = ${variable.initializer}',
        ],
        ['token = AppEnv.posthogProjectToken', 'host = AppEnv.posthogHost'],
      );
      final checks = _nodesIn<IfStatement>(start).take(2).toList();
      expect(
        [for (final check in checks) '${check.expression}'],
        ['token == null', 'host != null && !_isWebAddress(host)'],
      );
      final texts = [
        for (final check in checks)
          ((_nodesIn<ThrowExpression>(check.thenStatement).single.expression
                      as MethodInvocation)
                  .argumentList
                  .arguments
                  .single as StringLiteral)
              .stringValue,
      ];
      expect(
        texts[0],
        allOf(
          startsWith('POSTHOG_PROJECT_TOKEN has no value in this build'),
          contains('the section "${EnvRole.readmeHeading}" of its README'),
          contains('The section "$readmeHeading" tells more.'),
        ),
      );
      expect(
        texts[1],
        allOf(
          startsWith('POSTHOG_HOST of this build is no http or https '
              'address'),
          contains('the section "$readmeHeading" of its README'),
        ),
      );
      final isWebAddress = '${_functionOf(unit, '_isWebAddress')}';
      for (final part in [
        "address.scheme == 'http' || address.scheme == 'https'",
        'address.host.isNotEmpty',
      ]) {
        expect(isWebAddress, contains(part), reason: part);
      }
    });

    test(
        'sets PostHog up with the default of collection of the app, person '
        'profiles only for identified users, and no session replay, survey, '
        'preload of feature flags or push messages, and registers the flavor '
        'once PostHog started', () {
      final start = _functionOf(unit, 'initPostHogAnalytics');
      final config = _nodesIn<VariableDeclaration>(start)
          .singleWhere((variable) => variable.name.lexeme == 'config');

      expect(
        '${(config.initializer! as CascadeExpression).target}',
        'PostHogConfig(token)',
      );
      expect(
        [
          for (final assignment in _nodesIn<AssignmentExpression>(
            config.initializer!,
          ))
            '$assignment',
        ],
        [
          'optOut = !analyticsCollectedFromFirstStart',
          'personProfiles = PostHogPersonProfiles.identifiedOnly',
          'sessionReplay = false',
          'surveys = false',
          'preloadFeatureFlags = false',
          'capturePushNotificationSubscriptions = false',
          'capturePushNotificationOpened = false',
        ],
      );
      expect(_postHogCallsIn(start), ['setup', 'isOptOut']);
      expect(
        '$start',
        contains('_collecting = !await Posthog().isOptOut();'),
      );
      expect(
        '${_functionOf(unit, '_registerFlavor')}',
        contains("Posthog().register('app_flavor', appFlavor ?? 'dev')"),
      );
      // The flavor is registered before PostHog counts as started.
      final body = '${start.functionExpression.body}';
      expect(
        body.indexOf('await _registerFlavor();'),
        allOf(
          greaterThan(body.indexOf('await Posthog().setup(config);')),
          lessThan(body.lastIndexOf('_started = true;')),
        ),
      );
    });

    test(
        'records each call of the service in PostHog as its README section '
        'tells, and resets PostHog only while it collects', () {
      final methods = _methodsOf(unit, 'PostHogAnalyticsService');

      expect(methods.keys.toSet(), {
        'logEvent',
        'logSignIn',
        'logSignUp',
        'setAnalyticsCollectionEnabled',
        'setUserId',
        'setUserProperty',
      });
      expect(
        _docOf(
          unit.declarations.whereType<ClassDeclaration>().singleWhere(
                (declaration) =>
                    declaration.namePart.typeName.lexeme ==
                    'PostHogAnalyticsService',
              ),
        ),
        contains('so after each start the app calls `setUserId(id)` for a '
            'user who is signed in: until then, a property waits in memory, '
            'and it is lost if the app closes.'),
        reason: 'PostHog keeps the user of an earlier start, which the '
            'service does not know.',
      );
      expect(_postHogCallsIn(methods['logEvent']!), ['capture']);
      expect('${methods['logSignIn']}', contains("eventName: 'login'"));
      expect('${methods['logSignUp']}', contains("eventName: 'sign_up'"));
      expect(
        _postHogCallsIn(methods['setAnalyticsCollectionEnabled']!),
        ['optOut', 'optIn'],
      );
      // The user goes to PostHog only while it collects; reset() only there.
      expect(_postHogCallsIn(methods['setUserId']!), isEmpty);
      expect(
        '${methods['setUserId']}',
        contains('if (!_collecting) {_userHeld = true; return;}'),
      );
      final sendUser = _functionOf(unit, '_sendUser');
      expect(
        _postHogCallsIn(sendUser),
        ['identify', 'reset', 'optOut', 'optIn'],
      );
      expect(
        '$sendUser',
        contains('if (!analyticsCollectedFromFirstStart && _collecting) {'),
      );
      expect(
        _functionsOf(unit),
        isNot(contains(_listener)),
        reason: 'Only an app with a router has the listener.',
      );
      final file = app.files[serviceFile]!.text;
      for (final printing in ['print(', 'debugPrint(']) {
        expect(file, isNot(contains(printing)), reason: printing);
      }
    });

    test('gives the router no listener in an app without a router', () {
      expect(_listenersOf(result), isEmpty);
    });

    group('the section of the module in the README of the app', () {
      test(
          'is in the README, which has the sections of the values in .env and '
          'of the analytics', () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;

        expect(readme, contains('\n## $readmeHeading\n\n$readmeSection'));
        expect(readme, contains('\n## ${EnvRole.readmeHeading}\n'));
        expect(readme, contains('\n## ${AnalyticsRole.readmeHeading}\n'));
        expect(readme, contains('\n## ${AppEntryRole.setupHeading}\n'));
      });

      test(
          'tells of the keys, the EU host, the flavor and the filter on it, '
          'the screens and the observer, the defaults, the setting of '
          'collection, the user, the versions of the SDKs and how to pin '
          'them, and the privacy policy', () {
        expect(
          readmeSection,
          allOf([
            contains('starts with `phc_`'),
            contains('`https://eu.i.posthog.com` for its EU Cloud'),
            contains('it is no secret'),
            contains('Every event has the property `app_flavor`'),
            contains('filter the insights and the dashboards of PostHog on '
                '`app_flavor` equal to `prod`'),
            contains(r'a `$screen` event under the name of its route'),
            contains('The app has no `PosthogObserver`'),
            contains('`routeFilter: (_) => false`'),
            contains('Surveys, which the app does not show, need '
                '`surveys = true` in the config of `initPostHogAnalytics()`'),
            contains('a person profile only for a user whom the app '
                'identifies'),
            contains('no session replay, no survey, and no request for '
                'feature flags at each start'),
            contains('`com.posthog.posthog.CAPTURE_PUSH_NOTIFICATION_OPENED` '
                'is `false`'),
            contains('`com.posthog.posthog.AUTO_INIT` is `false` in '
                '`android/app/src/main/AndroidManifest.xml` and in '
                '`ios/Runner/Info.plist`'),
            contains('`analyticsCollectedFromFirstStart` alone decides'),
            contains('collects on the devices of iOS whose users declined '
                'before'),
            contains('events that the app logged before '
                '`setAnalyticsCollectionEnabled(false)` may still leave with '
                'the next batch of PostHog'),
            contains('`setUserId(null)` starts a new anonymous user in '
                'PostHog, so call it when the user signs out, not at each '
                'start'),
            contains('after each start, call `setUserId(id)` for a user who '
                'is signed in. Until then, the properties that '
                '`setUserProperty()` sets wait in memory, and they are lost if '
                'the app closes'),
            contains('version { strictly("<version>") }'),
            contains('raise that version whenever `flutter pub upgrade` raises '
                'posthog_flutter'),
            contains('`Package.resolved`'),
            contains('`ios/Podfile.lock`'),
            contains('For the privacy policy of the app, which the App Store '
                'and Google Play ask for'),
            contains('unless `disableGeoIp` is set'),
            contains('PostHog keeps the IP address of the device too, unless '
                'the settings of the project discard client IP data'),
          ]),
        );
        expect(
          _codeOf(readmeSection),
          containsAll([
            serviceFile,
            PostHogModule.projectTokenKey.name,
            PostHogModule.hostKey.name,
            EnvRole.dotEnvFile,
            'logPostHogScreen()',
            'setAnalyticsCollectionEnabled()',
            'setUserId()',
            'setUserProperty()',
          ]),
        );
        // It names no other analytics service, which only its own module
        // knows.
        expect(readmeSection.toLowerCase(), isNot(contains('firebase')));
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the analytics of the guide, after what the '
          'role says, without the note of the screens', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);

        expect(
          [
            for (final (origin, heading, note) in notes)
              if (origin == _posthog) (heading, note),
          ],
          [(analyticsRole.description, AgentNote(agentNote))],
        );
        expect(agentNote, startsWith('With `posthog_flutter`:\n'));
        final guide = app.files[AppEntryRole.agentsFile]!.text;
        expect(guide, contains('\n${agentNote.trim()}\n'));
        expect(
          guide.indexOf(agentNote.trim()),
          greaterThan(guide.indexOf('\n## ${analyticsRole.description}\n')),
        );
      });

      test('names the file of the module and what it declares and calls', () {
        final index = DartFileIndexer.index(
          serviceFile,
          app.files[serviceFile]!.text,
        );

        expect(
          _codeOf(agentNote),
          containsAll([
            serviceFile,
            'initPostHogAnalytics()',
            PostHogModule.projectTokenKey.name,
            PostHogModule.hostKey.name,
            EnvRole.dotEnvFile,
            'bootstrap()',
            PostHogModule.flavorProperty,
            'setUserId(null)',
            'setUserId(id)',
            'setUserProperty()',
            'AnalyticsService',
            'Posthog().optIn()',
            'Posthog().optOut()',
            'Posthog().reset()',
            'reset()',
          ]),
        );
        for (final name in [
          'initPostHogAnalytics',
          'PostHogAnalyticsService',
        ]) {
          expect(index.declaration(name), isNotNull, reason: name);
        }
        for (final used in [
          'Posthog().optIn()',
          'Posthog().optOut()',
          'Posthog().reset()',
          'AnalyticsService',
          "'app_flavor'",
        ]) {
          expect(app.files[serviceFile]!.text, contains(used), reason: used);
        }
      });
    });

    test('has a README that leads to the page of the module', () {
      expect(
        File('README.md').readAsStringSync(),
        contains('(https://doc.saymyframe.com/modules/posthog)'),
      );
    });
  });

  group('an app with the module and a router', () {
    late ContractResult result;
    late RenderedApp app;
    late CompilationUnit unit;

    setUpAll(() async {
      result = await _resultOf(const [PostHogModule.id, GoRouterModule.id]);
      app = result.app!;
      unit = parseString(content: app.files[serviceFile]!.text).unit;
    });

    test('gives the router the listener of the module', () {
      expect(_listenersOf(result), ['posthog: $_listener']);
    });

    test(
        'records a screen only once PostHog started, under the full name of '
        'its route, or `/` for the fallback start screen, and prints an '
        'error of PostHog rather than leaving it to the handlers of the '
        'errors', () {
      final listener = _functionOf(unit, _listener);
      final statements = (listener.functionExpression.body as BlockFunctionBody)
          .block
          .statements;

      expect(
        '${statements.first}',
        'if (!_started) return;',
        reason: 'The router calls the listener whether or not PostHog '
            'started, and PostHog records nothing before it started.',
      );
      expect(
        '${statements[1]}',
        "final name = route ?? (Uri.parse(location).path == '/' ? '/' : "
            'null);',
      );
      expect(_postHogCallsIn(listener), ['screen']);
      expect('$listener', contains(r"debugPrint('PostHog: $error')"));
    });

    test('has the note of the screens after the note of the module', () {
      final notes = app.entriesOf(AppEntryRole.agentSections);

      expect(
        [
          for (final (origin, heading, note) in notes)
            if (origin == _posthog) (heading, note),
        ],
        [
          (analyticsRole.description, AgentNote(agentNote)),
          (analyticsRole.description, AgentNote(screensAgentNote)),
        ],
      );
      expect(
        _codeOf(screensAgentNote),
        containsAll(['logPostHogScreen()', 'PosthogObserver']),
      );
      expect(
        DartFileIndexer.index(serviceFile, app.files[serviceFile]!.text)
            .declaration(_listener),
        isNotNull,
      );
      final guide = app.files[AppEntryRole.agentsFile]!.text;
      expect(
        guide.indexOf(screensAgentNote.trim()),
        greaterThan(guide.indexOf(agentNote.trim())),
      );
    });
  });

  group('an app that collects nothing before its code chose', () {
    const modules = [PostHogModule.id, GetItModule.id, GoRouterModule.id];
    late ContractResult result;
    late RenderedApp off;
    late RenderedApp on;

    setUpAll(() async {
      result = await _resultOf(
        modules,
        roleOptions: const {'analytics-collection': 'off'},
      );
      off = result.app!;
      on = (await _resultOf(modules)).app!;
    });

    test(
        'has the service and the native lines of an app that collects from '
        'its first start: PostHog starts from Dart, so the constant of the '
        'role alone tells it what to do before the code chose', () {
      expect(
        analyticsRole.collectionIn(analyticsRole.hookInput(result.hook!)),
        AnalyticsCollection.off,
      );
      expect(off.files[serviceFile]!.text, on.files[serviceFile]!.text);
      for (final path in const [
        AppEntryRole.androidManifestFile,
        AppEntryRole.infoPlistFile,
      ]) {
        expect(off.files[path]!.text, on.files[path]!.text, reason: path);
      }
      expect(
        off.files[AnalyticsRole.file]!.text,
        contains('const bool analyticsCollectedFromFirstStart = false;'),
      );
    });
  });
}
