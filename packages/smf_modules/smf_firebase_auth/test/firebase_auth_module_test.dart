@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/bundles/firebase_auth_bundle.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_auth/src/agents.dart';
import 'package:smf_firebase_auth/src/readme.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// The modules of the tests: flutter_core, which creates the app,
/// go_router, a provider of the router role, which the auth role uses,
/// firebase_core, which this module depends on, this module, and gen_l10n,
/// a provider of the localization role, which this module uses, with
/// shared_preferences, a provider of the preferences role, which that role
/// requires.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  FirebaseCoreModule(),
  FirebaseAuthModule(),
  SharedPreferencesModule(),
  GenL10nModule(),
];

/// The path of the file of the module.
const _implementation = 'lib/core/auth/firebase_auth_service.dart';

/// The statement of firebase_core that initializes Firebase in
/// `bootstrap()`.
const _initializeFirebase = 'await Firebase.initializeApp(options: '
    'DefaultFirebaseOptions.currentPlatform);';

/// The owners of the code of sign-in: this module and the template of its
/// role.
final Set<ContributionOrigin> _auth = {
  const ModuleOrigin(FirebaseAuthModule.id),
  const RoleTemplateOrigin(authRole),
};

/// What the contract harness finds for the app of [modules] with the
/// options [roleOptions] of its roles, which has no errors and is rendered.
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

/// The parsed file at [path] of [app].
CompilationUnit _unitOf(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

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

/// The imports of [unit], as written.
List<String> _importsOf(CompilationUnit unit) => [
      for (final directive in unit.directives.whereType<ImportDirective>())
        '$directive',
    ];

/// The statements of the function that `sendPasswordReset()` of the service
/// in [app] runs, as written.
List<String> _passwordResetOf(RenderedApp app) {
  final method = _methodsOf(
    _unitOf(app, _implementation),
    'FirebaseAuthService',
  )['sendPasswordReset']!;
  final run =
      (method.body as ExpressionFunctionBody).expression as MethodInvocation;
  final function = run.argumentList.arguments.single as FunctionExpression;
  return [
    for (final statement
        in (function.body as BlockFunctionBody).block.statements)
      '$statement',
  ];
}

/// The import of the function with which the root of an app resolves the
/// language of the device, as the file of the service has it in an app
/// with the localization role.
const _widgetsImport = "import 'package:flutter/widgets.dart' "
    'show WidgetsBinding, basicLocaleListResolution;';

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// The codes of Firebase Authentication that the service gives a reason,
/// as the plugin has them, each with its reason of the auth role.
const _reasons = {
  'invalid-credential': 'invalidCredentials',
  'invalid-login-credentials': 'invalidCredentials',
  'wrong-password': 'invalidCredentials',
  'user-not-found': 'invalidCredentials',
  'email-already-in-use': 'emailInUse',
  'credential-already-in-use': 'emailInUse',
  'weak-password': 'weakPassword',
  'password-does-not-meet-requirements': 'weakPassword',
  'invalid-email': 'invalidEmail',
  'missing-email': 'invalidEmail',
  'user-disabled': 'userDisabled',
  'too-many-requests': 'tooManyAttempts',
  'network-request-failed': 'network',
  'requires-recent-login': 'recentSignInRequired',
};

/// The codes with which Firebase answers a call for a user whose session
/// has ended on the server.
const _endedSession = [
  'user-token-expired',
  'invalid-user-token',
  'user-not-found',
  'no-current-user',
];

/// Runs the service of the module on the stand-in for firebase_auth, and
/// sends back what its calls ended with, the user that it had, what
/// reached Firebase and what its listeners heard.
///
/// It imports the file of the module and the file of the role with
/// `AuthService`, which need nothing but the stand-ins.
const _script = r'''
import 'dart:async';
import 'dart:isolate';

import 'package:contract_app/core/auth/auth_service.dart';
import 'package:contract_app/core/auth/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const password = 'secret';

String userOf(AuthUser? user) => user == null
    ? 'nobody'
    : '${user.uid} <${user.email}>${user.isAnonymous ? ', anonymous' : ''}';

Future<String> outcomeOf(Future<void> Function() call) async {
  try {
    await call();
    return 'completed';
  } on AuthFailure catch (failure) {
    final hint = failure.developerHint;
    return hint == null ? failure.reason.name : '${failure.reason.name}: $hint';
  } on Object catch (error) {
    return 'threw $error';
  }
}

/// Lets the events of the streams reach their listeners.
Future<void> settle() => Future<void>.delayed(Duration.zero);

Future<void> main(List<String> arguments, SendPort port) async {
  final codes = arguments;
  final result = <String, Object?>{};
  final service = createFirebaseAuthService();
  result['implementation'] = '${service.runtimeType}';
  result['streams of Firebase'] = [userChangesListeners];

  final heard = <String>[];
  var subscription = service.userChanges.listen(
    (user) => heard.add(userOf(user)),
    onError: (Object error) => heard.add('error: $error'),
  );
  await settle();
  result['streams of Firebase'] = [
    ...result['streams of Firebase']! as List<Object?>,
    userChangesListeners,
  ];
  result['a broadcast stream'] = service.userChanges.isBroadcast;

  // How a call ended, the user of the service then, what reached Firebase,
  // and the users that the listener heard of.
  Future<List<Object?>> step(Future<void> Function() call) async {
    await settle();
    heard.clear();
    firebaseCalls.clear();
    final outcome = await outcomeOf(call);
    await settle();
    return [
      outcome,
      userOf(service.currentUser),
      [...firebaseCalls],
      heard.toSet().toList(),
    ];
  }

  Future<void> signIn() => service.signIn(email: 'a@x.dev', password: password);

  result['calls'] = {
    'signUp': await step(
      () => service.signUp(email: 'a@x.dev', password: password),
    ),
    'signOut': await step(service.signOut),
    'signIn': await step(signIn),
    'sendPasswordReset': await step(() => service.sendPasswordReset('a@x.dev')),
    'signInAnonymously': await step(service.signInAnonymously),
    'linkPassword': await step(
      () => service.linkPassword(email: 'b@x.dev', password: password),
    ),
    'deleteAccount': await step(service.deleteAccount),
    'deleteAccount without a user': await step(service.deleteAccount),
    'linkPassword without a user': await step(
      () => service.linkPassword(email: 'b@x.dev', password: password),
    ),
  };

  await signIn();
  final reasons = <String, Object?>{};
  for (final code in codes) {
    failNext['signInWithEmailAndPassword'] = FirebaseAuthException(code: code);
    reasons[code] = await outcomeOf(signIn);
  }
  result['reasons'] = reasons;
  result['user after the failures'] = userOf(service.currentUser);

  failNext['sendPasswordResetEmail'] =
      FirebaseAuthException(code: 'user-not-found');
  result['reset for an address without an account'] =
      await step(() => service.sendPasswordReset('nobody@x.dev'));
  failNext['sendPasswordResetEmail'] =
      FirebaseAuthException(code: 'invalid-email');
  result['reset for no address'] =
      await outcomeOf(() => service.sendPasswordReset('nobody'));

  final ended = <String, Object?>{};
  for (final code in const [
    'user-token-expired',
    'invalid-user-token',
    'user-not-found',
    'no-current-user',
  ]) {
    await service.signInAnonymously();
    failNext['delete'] = FirebaseAuthException(code: code);
    ended['delete: $code'] = await step(service.deleteAccount);
    await service.signInAnonymously();
    failNext['linkWithCredential'] = FirebaseAuthException(code: code);
    ended['linkWithCredential: $code'] = await step(
      () => service.linkPassword(email: 'b@x.dev', password: password),
    );
  }
  result['ended session'] = ended;

  await signIn();
  failNext['delete'] = FirebaseAuthException(code: 'requires-recent-login');
  result['deletion that needs a recent sign-in'] =
      await step(service.deleteAccount);

  Future<String> failing(String code, [String? message]) {
    failNext['signInWithEmailAndPassword'] =
        FirebaseAuthException(code: code, message: message);
    return outcomeOf(signIn);
  }

  result['not configured'] = [
    await failing('operation-not-allowed', 'The provider is disabled.'),
    await failing('admin-restricted-operation'),
    await failing(
      'unknown',
      'An internal error has occurred. [ CONFIGURATION_NOT_FOUND',
    ),
  ];
  final internal = <String, Object?>{};
  for (final platform in TargetPlatform.values) {
    defaultTargetPlatform = platform;
    internal[platform.name] = await failing('internal-error', 'Internal.');
  }
  defaultTargetPlatform = TargetPlatform.android;
  result['internal error'] = internal;
  result['unknown'] = [
    await failing('app-not-authorized', 'Not authorized.'),
    await failing('unknown', 'Something else.'),
  ];
  failNext['signInWithEmailAndPassword'] = StateError('broken');
  result['no error of Firebase'] = await outcomeOf(signIn);

  await settle();
  heard.clear();
  platformSignsOut();
  await settle();
  result['a sign-out of Firebase'] = [userOf(service.currentUser), [...heard]];
  heard.clear();
  platformFails(StateError('stream'));
  await settle();
  result['an error of the stream of Firebase'] = [...heard];

  await subscription.cancel();
  await settle();
  final withoutListener = userChangesListeners;
  subscription = service.userChanges.listen((_) {});
  await settle();
  result['streams of Firebase'] = [
    ...result['streams of Firebase']! as List<Object?>,
    withoutListener,
    userChangesListeners,
  ];
  await subscription.cancel();

  await signIn();
  result['a service created again'] =
      userOf(createFirebaseAuthService().currentUser);
  port.send(result);
}
''';

void main() {
  const module = FirebaseAuthModule();

  group('FirebaseAuthModule', () {
    test(
        'is infrastructure that provides the auth role, depends on '
        'firebase_core and uses the localization role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('firebase_auth'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {authRole});
      expect(descriptor.dependsOn, {FirebaseCoreModule.id});
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, {localizationRole});
      expect(descriptor.effectiveUses, {...authRole.uses, localizationRole});
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, firebase_auth, its implementation of the '
        'service, created without waiting, its section of the README and '
        'its note for coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(5));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(firebaseAuthBundle));
      expect(brick.bundle.name, 'firebase_auth');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [_implementation],
      );
      expect(brick.when, isEmpty);
      final dependency = contributions[1] as PubspecDependency;
      expect(dependency.package, 'firebase_auth');
      expect(dependency.constraint, '^6.7.0');
      expect(dependency.dev, isFalse);
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, authRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'FirebaseAuthService');
      expect(implementation.create!.name, 'createFirebaseAuthService');
      expect(implementation.create!.deps, isEmpty);
      expect(
        implementation.type.import,
        const ImportRef.app('core/auth/firebase_auth_service.dart'),
      );
      expect(implementation.create!.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', serviceFile);
      expect(serviceFile, _implementation);
      final readme = contributions[3] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, readmeHeading);
      expect(readme.entryValue, readmeSection);
      expect(readme.when, isEmpty);
      final note = contributions[4] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, authRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });

    test(
        'gives its brick the code that asks Firebase for its messages in '
        'the language of the app, for an app with the localization role, '
        'and no code for an app without it', () {
      final brick = module.contribute(ContractHarness.defaultContext).first
          as BrickContribution;

      expect(brick.vars.keys, ['email_language']);
      final language = brick.vars['email_language']! as RoleVar;
      expect(language.role, localizationRole);
      expect(language.absent, '');
      final present = language.present as Fragment;
      expect(
        present.code,
        allOf(
          startsWith('// The message is in the language that the app is in.'),
          contains('await _auth.setLanguageCode('),
          endsWith(');'),
        ),
      );
      // The file of the role with the languages of the app, and the
      // function with which the root of the app resolves the language of
      // the device.
      expect(present.imports, const [
        ImportRef(
          'package:flutter/widgets.dart',
          show: ['WidgetsBinding', 'basicLocaleListResolution'],
        ),
        ImportRef.app('core/l10n/app_locale.dart'),
      ]);
      expect(
        'lib/${present.imports.last.uri}',
        LocalizationRole.appLocaleFile,
      );
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the apps of the module with the localization role, which it '
        'uses, and the router role, which the auth role uses, and without '
        'each, and an app for each other mode of the auth role', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router, localization',
        'flutter_core with router',
        'flutter_core with localization',
        'flutter_core',
        'firebase_core',
        'firebase_auth with localization, router',
        'firebase_auth with localization',
        'firebase_auth with router',
        'firebase_auth',
        'shared_preferences',
        'auth by firebase_auth with router --auth-mode=guest',
        'auth by firebase_auth with router --auth-mode=anonymous',
      ]);
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

    test(
        'renders code of the service that type-checks with firebase_auth, '
        'in the apps with the localization role and in the apps without it',
        () async {
      final withService = [
        for (final result in results)
          if (result.app!.files.containsKey(_implementation)) result,
      ];
      expect(withService, hasLength(6));
      for (final result in withService) {
        final app = DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems(
              {const ModuleOrigin(FirebaseAuthModule.id)},
            ),
            isEmpty,
            reason: '${result.contractCase}',
          );
        } finally {
          app.delete();
        }
      }
    });

    test(
        'renders the same service in every mode of the auth role, in an app '
        'with a router and in one without', () {
      final services = [
        for (final result in results)
          if (result.app!.files[_implementation] case final file?
              when !result.hook!.presentRoles.contains(localizationRole))
            (
              mode: authRole.modeIn(authRole.hookInput(result.hook!)),
              router: result.hook!.presentRoles.contains(routerRole),
              service: file.text,
            ),
      ];

      expect(
        [for (final (:mode, :router, service: _) in services) (mode, router)],
        [
          (AuthMode.required, true),
          (AuthMode.required, false),
          (AuthMode.guest, true),
          (AuthMode.anonymous, true),
        ],
      );
      expect({for (final app in services) app.service}, hasLength(1));
    });
  });

  group('an app with the module', () {
    late ContractResult result;
    late RenderedApp app;
    late ContractResult resultWithout;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [FirebaseAuthModule.id]);
      app = result.app!;
      resultWithout = await _resultOf(const [FirebaseCoreModule.id]);
      without = resultWithout.app!;
    });

    test(
        'is the app of Firebase but for the files of the auth role, the '
        'service, firebase_auth, the start of the session, and the sections '
        'of sign-in in the README and in the guide for coding agents', () {
      expect(app.files.keys.toSet(), {
        ...without.files.keys,
        AuthRole.serviceFile,
        AuthRole.sessionFile,
        AuthRole.guestDataFile,
        _implementation,
      });
      expect(
        app.files[_implementation]!.owner,
        const ModuleOrigin(FirebaseAuthModule.id),
      );
      // Its native files, the manifest of Android, the Gradle files, the
      // Info.plist and the Xcode project among them, are those of the app
      // of Firebase: the module sets up nothing of the platforms.
      final changed = <String>[];
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        expect(app.files[path]!.owner, file.owner, reason: path);
        if (app.files[path]!.text != file.text) changed.add(path);
      }
      expect(
        changed,
        unorderedEquals([
          'pubspec.yaml',
          AppEntryRole.readmeFile,
          AppEntryRole.agentsFile,
          AppEntryRole.bootstrapFile,
        ]),
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['dependencies'],
        {
          'firebase_auth': '^6.7.0',
          'firebase_core': '^4.15.0',
          'flutter': {'sdk': 'flutter'},
        },
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['environment'],
        _yamlOf(without.files['pubspec.yaml']!.text)['environment'],
      );
    });

    test(
        'starts the session of the app in bootstrap() once Firebase is '
        'initialized', () {
      // The template of the role comes after its provider and the module
      // that it depends on: firebase_core, whose Firebase app the service
      // works on.
      expect(_startUpOf(result), [
        'firebase_core: $_initializeFirebase',
        'role:auth: await initAuth();',
      ]);
    });

    test(
        'creates the service of the module in initAuth(), without waiting '
        'for it', () {
      final file = app.files[AuthRole.sessionFile]!;
      final init = _unitOf(app, AuthRole.sessionFile)
          .declarations
          .whereType<FunctionDeclaration>()
          .singleWhere((function) => function.name.lexeme == 'initAuth');
      final body = init.functionExpression.body as BlockFunctionBody;

      expect(
        [for (final statement in body.block.statements) '$statement'],
        [
          '_authService = impl0.createFirebaseAuthService();',
          'await appSession.start(_authService);',
        ],
      );
      expect(
        [
          for (final added in file.addedImports)
            (added.import.uri, added.import.prefix, '${added.contributor}'),
        ],
        [
          (
            'package:contract_app/core/auth/firebase_auth_service.dart',
            'impl0',
            'role:auth',
          ),
        ],
      );
    });

    group('the implementation', () {
      late CompilationUnit unit;

      setUpAll(() => unit = _unitOf(app, _implementation));

      test('is the service of the role on the FirebaseAuth of the app', () {
        final declaration =
            unit.declarations.whereType<ClassDeclaration>().single;
        expect(
          '${declaration.implementsClause!.interfaces.single}',
          'AuthService',
        );
        final factory =
            unit.declarations.whereType<FunctionDeclaration>().single;
        expect(factory.name.lexeme, 'createFirebaseAuthService');
        expect('${factory.returnType}', 'AuthService');
        expect(factory.functionExpression.parameters!.parameters, isEmpty);
        final body = factory.functionExpression.body as ExpressionFunctionBody;
        expect(
          '${body.expression}',
          'FirebaseAuthService(FirebaseAuth.instance)',
        );
        expect(_importsOf(unit), [
          "import 'dart:async';",
          "import 'package:firebase_auth/firebase_auth.dart';",
          "import 'package:flutter/foundation.dart';",
          "import 'auth_service.dart';",
        ]);
      });

      test(
          'implements every member of the service with the signature of the '
          'interface', () {
        String signatureOf(MethodDeclaration method) =>
            '${method.returnType} ${method.propertyKeyword ?? ''} '
            '${method.parameters ?? ''}';
        final interface = _methodsOf(
          _unitOf(app, AuthRole.serviceFile),
          'AuthService',
        );

        expect(
          {
            for (final MapEntry(key: name, value: method)
                in _methodsOf(unit, 'FirebaseAuthService').entries)
              if (!name.startsWith('_')) name: signatureOf(method),
          },
          {
            for (final MapEntry(key: name, value: method) in interface.entries)
              name: signatureOf(method),
          },
        );
        expect(interface.keys, hasLength(9));
      });

      test('asks Firebase for no language before a password reset', () {
        expect(_passwordResetOf(app), [startsWith('try {')]);
      });
    });

    group('the service', () {
      late Map<Object?, Object?> sent;

      setUpAll(() async {
        final dartApp = DartApp.write(app);
        try {
          sent = (await dartApp.run(_script, arguments: [..._reasons.keys]))!
              as Map<Object?, Object?>;
        } finally {
          dartApp.delete();
        }
      });

      test('is created with nobody on a device without a user', () {
        expect(sent['implementation'], 'FirebaseAuthService');
      });

      test(
          'makes the call of Firebase for each of its calls, has the user '
          'of that call when it completes, and tells its listener of that '
          'user', () {
        const account = 'uid of a@x.dev <a@x.dev>';
        const guest = 'guest 1 <null>, anonymous';
        const linked = 'guest 1 <b@x.dev>';
        expect(sent['calls'], {
          'signUp': [
            'completed',
            account,
            ['createUserWithEmailAndPassword(a@x.dev, secret)'],
            [account],
          ],
          'signOut': [
            'completed',
            'nobody',
            ['signOut()'],
            ['nobody'],
          ],
          'signIn': [
            'completed',
            account,
            ['signInWithEmailAndPassword(a@x.dev, secret)'],
            [account],
          ],
          // The user stays, and the app without the localization role sets
          // no language.
          'sendPasswordReset': [
            'completed',
            account,
            ['sendPasswordResetEmail(a@x.dev)'],
            [account],
          ],
          'signInAnonymously': [
            'completed',
            guest,
            ['signInAnonymously()'],
            [guest],
          ],
          // The anonymous user keeps the id.
          'linkPassword': [
            'completed',
            linked,
            ['linkWithCredential(password of b@x.dev: secret)'],
            [linked],
          ],
          // The plugin keeps a deleted user as its current one, so the
          // service signs out.
          'deleteAccount': [
            'completed',
            'nobody',
            ['delete()', 'signOut()'],
            ['nobody'],
          ],
          // Without a user, a call for the user who is signed in fails
          // before it reaches Firebase.
          'deleteAccount without a user': [
            'recentSignInRequired',
            'nobody',
            <Object?>[],
            ['nobody'],
          ],
          'linkPassword without a user': [
            'recentSignInRequired',
            'nobody',
            <Object?>[],
            ['nobody'],
          ],
        });
        expect(sent['a broadcast stream'], isTrue);
      });

      test(
          'gives each code of Firebase its reason of the auth role, and '
          'leaves the user', () {
        expect(sent['reasons'], _reasons);
        expect(sent['user after the failures'], 'uid of a@x.dev <a@x.dev>');
        expect(
          sent['deletion that needs a recent sign-in'],
          [
            'recentSignInRequired',
            'uid of a@x.dev <a@x.dev>',
            ['delete()'],
            ['uid of a@x.dev <a@x.dev>'],
          ],
        );
      });

      test(
          'completes a password reset for an address that Firebase has no '
          'account of', () {
        expect(sent['reset for an address without an account'], [
          'completed',
          'uid of a@x.dev <a@x.dev>',
          ['sendPasswordResetEmail(nobody@x.dev)'],
          ['uid of a@x.dev <a@x.dev>'],
        ]);
        expect(sent['reset for no address'], 'invalidEmail');
      });

      test(
          'signs out a user whose session has ended on the server, and '
          'fails the call for that user with recentSignInRequired', () {
        expect(sent['ended session'], {
          for (final code in _endedSession) ...{
            'delete: $code': [
              'recentSignInRequired',
              'nobody',
              ['delete()', 'signOut()'],
              ['nobody'],
            ],
            'linkWithCredential: $code': [
              'recentSignInRequired',
              'nobody',
              ['linkWithCredential(password of b@x.dev: secret)', 'signOut()'],
              ['nobody'],
            ],
          },
        });
      });

      test(
          'takes a way to sign in that is not enabled in the Firebase '
          'project for notConfigured, with a hint that has the link to the '
          'project', () {
        const link = 'https://console.firebase.google.com/project/'
            'stand-in-project/authentication/providers';
        const enable = 'enable Email/Password, and Anonymous for an app that '
            'signs in anonymous users, under Authentication > Sign-in '
            'method: $link';
        String notEnabled(String answer) =>
            'notConfigured: Sign-in is not enabled in the Firebase project '
            'stand-in-project ($answer). To fix it, $enable';
        expect(sent['not configured'], [
          notEnabled('operation-not-allowed: The provider is disabled.'),
          notEnabled('admin-restricted-operation: null'),
          // As Android tells of a project in which Authentication was
          // never set up.
          notEnabled(
            'unknown: An internal error has occurred. '
            '[ CONFIGURATION_NOT_FOUND',
          ),
        ]);
        // An internal error is what Firebase answers for such a project on
        // iOS and macOS, where the hint says that it may be another error.
        const hedged = 'notConfigured: Firebase reported an internal error '
            '(internal-error: Internal.), which is also what it answers on '
            'iOS and macOS when sign-in is not enabled in the Firebase '
            'project stand-in-project. If that is the cause, $enable';
        const unknown = 'unknown: internal-error: Internal.';
        expect(sent['internal error'], {
          'android': unknown,
          'fuchsia': unknown,
          'iOS': hedged,
          'linux': unknown,
          'macOS': hedged,
          'windows': unknown,
        });
      });

      test('takes any other error for unknown, with the error as the hint', () {
        expect(sent['unknown'], [
          'unknown: app-not-authorized: Not authorized.',
          'unknown: unknown: Something else.',
        ]);
        expect(sent['no error of Firebase'], 'unknown: Bad state: broken');
      });

      test(
          'follows the user of Firebase while it has a listener, and tells '
          'of a sign-out and of an error of that stream', () {
        expect(sent['a sign-out of Firebase'], [
          'nobody',
          ['nobody'],
        ]);
        expect(
          sent['an error of the stream of Firebase'],
          ['error: Bad state: stream'],
        );
        // No stream before the service has a listener, one while it has,
        // none once the listener is gone, and one again with the next.
        expect(sent['streams of Firebase'], [0, 1, 0, 1]);
      });

      test('has the user who is signed in when it is created again', () {
        expect(sent['a service created again'], 'uid of a@x.dev <a@x.dev>');
      });
    });

    group('the section of the module in the README of the app', () {
      test(
          'comes after the section of Firebase, and refers to the section '
          'of the auth role, which the app has too', () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;
        int at(String heading) => readme.indexOf('\n## $heading\n');

        expect(
          readme,
          contains('\n## $readmeHeading\n\n$readmeSection'),
        );
        // The section of firebase_core, which tells how the app gets its
        // Firebase project, comes first.
        expect(at('Firebase'), inExclusiveRange(0, at(readmeHeading)));
        expect(at(AuthRole.readmeHeading), isNonNegative);
        expect(
          readmeSection,
          contains('(see the section ${AuthRole.readmeHeading})'),
        );
      });

      test(
          'tells where the ways to sign in are enabled, which of them the '
          'mode anonymous needs, and what the app does until they are', () {
        expect(
          readmeSection,
          allOf(
            contains('Authentication > Sign-in method'),
            contains('- Email/Password, in every mode of the app;'),
            contains('- Anonymous, when the mode of the app is `anonymous`'),
            contains('fail with the reason `notConfigured`'),
          ),
        );
        expect(_codeOf(readmeSection), contains(_implementation));
        // As the service names them in its hint.
        expect(
          app.files[_implementation]!.text,
          allOf(
            contains('enable Email/Password, and Anonymous'),
            contains('Authentication > Sign-in method'),
          ),
        );
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the authentication of the guide, after what '
          'the role says', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);
        final ofRole = [
          for (final (origin, _, note) in notes)
            if (origin == const RoleTemplateOrigin(authRole)) note.text,
        ].single;

        expect(
          [
            for (final (origin, heading, note) in notes)
              if (_auth.contains(origin)) (origin, heading, note.isOfRole),
          ],
          unorderedEquals([
            (
              const ModuleOrigin(FirebaseAuthModule.id),
              authRole.description,
              false,
            ),
            (const RoleTemplateOrigin(authRole), authRole.description, true),
          ]),
        );
        expect(agentNote, startsWith('With `firebase_auth`:\n'));
        expect(
          app.files[AppEntryRole.agentsFile]!.text,
          contains(
            '\n## ${authRole.description}\n'
            '\n'
            '$ofRole\n'
            '\n'
            '${agentNote.trim()}\n',
          ),
        );
      });

      test(
          'names the file of the module, the only one of the app that '
          'imports the package, and what that file and the role declare', () {
        final code = _codeOf(agentNote);
        final service = DartFileIndexer.index(
          _implementation,
          app.files[_implementation]!.text,
        );
        final role = DartFileIndexer.index(
          AuthRole.serviceFile,
          app.files[AuthRole.serviceFile]!.text,
        );

        expect(
          code,
          containsAll([
            _implementation,
            'FirebaseAuthService',
            'AuthService',
            'FirebaseAuth.instance',
            'appSession',
            'AuthFailureReason',
            '_failureOf()',
            'unknown',
            'notConfigured',
            'developerHint',
            AppEntryRole.readmeFile,
          ]),
        );
        expect(
          [
            for (final file in app.files.values)
              if (file.path.endsWith('.dart') &&
                  file.text.contains('package:firebase_auth/'))
                file.path,
          ],
          [_implementation],
        );
        expect(
          service.declaration('FirebaseAuthService')?.kind,
          DeclarationKind.classType,
        );
        expect(
          [
            for (final access in service.memberAccesses)
              '${access.target}.${access.name}',
          ],
          contains('FirebaseAuth.instance'),
        );
        expect(
          _methodsOf(_unitOf(app, _implementation), 'FirebaseAuthService').keys,
          contains('_failureOf'),
        );
        expect(
          role.declaration('AuthService')?.kind,
          DeclarationKind.classType,
        );
        expect(
          role.declaration('AuthFailureReason')?.kind,
          DeclarationKind.enumType,
        );
        expect(
          app.files[AuthRole.serviceFile]!.text,
          allOf(
            contains('  unknown,'),
            contains('  notConfigured,'),
            contains('final String? developerHint;'),
          ),
        );
        expect(
          app.files[AuthRole.sessionFile]!.text,
          contains('final appSession = AppSessionController('),
        );
        expect(agentNote, contains('the section $readmeHeading of'));
      });
    });

    test('has a README that leads to the page of the module', () {
      final readme = File('README.md').readAsStringSync();

      expect(
        readme,
        contains('(https://doc.saymyframe.com/modules/firebase-auth)'),
      );
    });
  });

  group('an app with the localization role', () {
    late RenderedApp app;

    setUpAll(() async {
      app = (await _resultOf(
        const [FirebaseAuthModule.id, GenL10nModule.id],
      ))
          .app!;
    });

    test(
        'asks Firebase for the message of a password reset in the language '
        'that the app is in, before it asks for the message', () {
      final statements = _passwordResetOf(app);

      expect(statements, hasLength(2));
      // The language that the user chose, or the one that the device
      // prefers among those of the app.
      expect(
        statements.first.replaceAll(RegExp(r'\s+'), ''),
        'await_auth.setLanguageCode((appLocale.value??'
        'basicLocaleListResolution('
        'WidgetsBinding.instance.platformDispatcher.locales,appLocales))'
        '.languageCode);',
      );
      expect(statements.last, startsWith('try {'));
      expect(statements.last, contains('_auth.sendPasswordResetEmail('));
    });

    test(
        'imports the languages of the app, from the file of the '
        'localization role, into the file of the service', () {
      expect(_importsOf(_unitOf(app, _implementation)), [
        "import 'dart:async';",
        "import 'package:contract_app/core/l10n/app_locale.dart';",
        "import 'package:firebase_auth/firebase_auth.dart';",
        "import 'package:flutter/foundation.dart';",
        _widgetsImport,
        "import 'auth_service.dart';",
      ]);
      // What the code of the module reads there.
      final locale = DartFileIndexer.index(
        LocalizationRole.appLocaleFile,
        app.files[LocalizationRole.appLocaleFile]!.text,
      );
      expect(locale.declaration('appLocale'), isNotNull);
      expect(locale.declaration('appLocales'), isNotNull);
    });
  });
}
