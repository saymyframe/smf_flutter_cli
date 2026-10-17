@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_apple_sign_in/bundles/apple_sign_in_bundle.dart';
import 'package:smf_apple_sign_in/smf_apple_sign_in.dart';
import 'package:smf_apple_sign_in/src/agents.dart';
import 'package:smf_apple_sign_in/src/readme.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';
import 'support/providers.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, a provider of the auth role of the tests, which the module
/// requires, and gen_l10n, a provider of the localization role, which the
/// module uses, with shared_preferences, which that role requires.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  AppleSignInModule(),
  TestAuthModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
];

/// The module as the owner of its file and of its contributions.
const _module = ModuleOrigin(AppleSignInModule.id);

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

/// The dependencies of the pubspec of [app], as plain values.
Map<String, Object?> _dependenciesOf(RenderedApp app) {
  final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
  return {
    for (final MapEntry(:key, :value)
        in (pubspec['dependencies'] as YamlMap).entries)
      '$key': value is YamlMap ? {...value} : value,
  };
}

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// The ways to sign in of the app of [result], as the auth role gives them
/// to every provider and to the roles that use it.
List<AppSignInMethod> _methodsOf(ContractResult result) =>
    authRole.methodsIn(authRole.hookInput(result.hook!));

/// The items of `appSignInMethods` in [app], each as its arguments by name,
/// and the bodies of the functions of their labels, by name.
({List<Map<String, String>> items, Map<String, String> labels}) _listOf(
  RenderedApp app,
) {
  final unit = parseString(content: app.files[AuthRole.methodsFile]!.text).unit;
  final list = unit.declarations
      .whereType<TopLevelVariableDeclaration>()
      .single
      .variables
      .variables
      .single
      .initializer! as ListLiteral;
  return (
    items: [
      // Without the types resolved, `SignInMethod(...)` is an invocation.
      for (final item in list.elements.cast<MethodInvocation>())
        {
          for (final argument in item.argumentList.arguments)
            if (argument
                case NamedArgument(:final name, :final argumentExpression))
              name.lexeme: argumentExpression.toSource(),
        },
    ],
    labels: {
      for (final function in unit.declarations.whereType<FunctionDeclaration>())
        function.name.lexeme: function.functionExpression.body.toSource(),
    },
  );
}

/// Runs `appleCredential()` of the app of the module without the
/// localization role, with the stand-ins of Flutter and of
/// sign_in_with_apple, once for each of the cases that it scripts, and
/// sends back what each call returned or failed with and the requests that
/// reached Apple.
const _script = r'''
import 'dart:convert';
import 'dart:isolate';

import 'package:contract_app/core/apple_sign_in/apple_sign_in.dart';
import 'package:contract_app/core/auth/app_session.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// A credential of an Apple ID as the platform answers it, with the name
/// of the user only if [withName].
AuthorizationCredentialAppleID answer(int number, {bool withName = true}) =>
    AuthorizationCredentialAppleID(
      userIdentifier: 'apple-user',
      givenName: withName ? 'Given' : null,
      familyName: withName ? 'Family' : null,
      authorizationCode: 'code-$number',
      email: withName ? 'user@privaterelay.appleid.com' : null,
      identityToken: 'token-$number',
      state: null,
    );

/// What a call of appleCredential() ended with: the fields of the
/// credential, null, or the reason and the hint of the failure.
Future<Object?> call() async {
  try {
    final credential = await appleCredential();
    return switch (credential) {
      null => 'null',
      IdTokenCredential() => {
          'type': '${credential.runtimeType}',
          'issuer': credential.issuer,
          'idToken': credential.idToken,
          'rawNonce': credential.rawNonce,
          'authorizationCode': credential.authorizationCode,
          'givenName': credential.givenName,
          'familyName': credential.familyName,
          'toString': '$credential',
        },
    };
  } on AuthFailure catch (failure) {
    return 'failed: ${failure.reason.name}: ${failure.developerHint}';
  } on Object catch (error) {
    return 'threw: $error';
  }
}

/// The requests that reached Apple since the last call of it, each with its
/// scopes and whether its nonce is the SHA-256 hash of [rawNonces] in turn.
List<Object?> requestsSince(List<String?> rawNonces) {
  final requests = [
    for (final (index, request) in appleRequests.indexed)
      {
        'scopes': [for (final scope in request.scopes) scope.name],
        'nonce is the hash of the raw nonce': index < rawNonces.length &&
            rawNonces[index] != null &&
            request.nonce ==
                sha256.convert(utf8.encode(rawNonces[index]!)).toString(),
      },
  ];
  appleRequests.clear();
  return requests;
}

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};
  defaultTargetPlatform = TargetPlatform.iOS;

  appleAnswers
    ..add(answer(1))
    ..add(answer(2, withName: false));
  final first = await call();
  final second = await call();
  String? rawNonceOf(Object? call) =>
      call is Map ? call['rawNonce'] as String? : null;
  result['two sign-ins'] = [first, second];
  result['their requests'] =
      requestsSince([rawNonceOf(first), rawNonceOf(second)]);
  result['their raw nonces differ'] = rawNonceOf(first) != rawNonceOf(second);

  final errors = <String, Object?>{};
  for (final (name, error) in [
    for (final code in AuthorizationErrorCode.values)
      (
        code.name,
        SignInWithAppleAuthorizationException(
          code: code,
          message: 'The operation of ${code.name} failed.',
        ),
      ),
    (
      'not supported',
      const SignInWithAppleNotSupportedException(message: 'Not supported.'),
    ),
    ('another error', StateError('broken')),
    (
      'no identity token',
      const AuthorizationCredentialAppleID(
        userIdentifier: 'apple-user',
        givenName: null,
        familyName: null,
        authorizationCode: 'code',
        email: null,
        identityToken: null,
        state: null,
      ),
    ),
  ]) {
    appleAnswers.add(error);
    errors[name] = await call();
  }
  result['errors'] = errors;
  result['requests of the errors'] = appleRequests.length;
  appleRequests.clear();

  final platforms = <String, Object?>{};
  for (final platform in TargetPlatform.values) {
    if (platform == TargetPlatform.iOS) continue;
    defaultTargetPlatform = platform;
    platforms[platform.name] = [await call(), appleRequests.length];
  }
  result['other platforms'] = platforms;
  port.send(result);
}
''';

void main() {
  const module = AppleSignInModule();

  group('AppleSignInModule', () {
    test(
        'is infrastructure that requires the auth role and uses the '
        'localization role, and depends on no module', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('apple_sign_in'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.requires, {authRole});
      expect(descriptor.uses, {localizationRole});
      expect(descriptor.provides, isEmpty);
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, sign_in_with_apple and crypto, its way to '
        'sign in with its label, the entitlement of Sign in with Apple, its '
        'section of the README and its note for coding agents, and nothing '
        'else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(8));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(appleSignInBundle));
      expect(brick.bundle.name, 'apple_sign_in');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [appleSignInFile],
      );
      expect(brick.vars, {
        'issuer': 'https://appleid.apple.com',
        'readme': 'Sign in with Apple',
      });
      expect(
        [
          for (final dependency in contributions.sublist(1, 3))
            if (dependency case final PubspecDependency dependency)
              (dependency.package, dependency.constraint, dependency.dev),
        ],
        [
          // The first version that builds with AGP 9, and the first that
          // the apps allow: it needs Flutter 3.44 and Dart 3.12.
          ('sign_in_with_apple', '^8.2.0', false),
          ('crypto', '^3.0.7', false),
        ],
      );

      final data = contributions[3] as RoleData<Object>;
      expect(data.role, authRole);
      final method = data.value as SignInMethod;
      expect(method.issuer, 'https://appleid.apple.com');
      expect(method.issuer, AppleSignInModule.issuer);
      expect(method.label, AppleSignInModule.label);
      expect(method.label.name, 'label');
      expect(method.label.en, 'Continue with Apple');
      expect(method.label.translations, {'uk': 'Продовжити з Apple'});
      expect(method.platforms, {AppPlatform.ios});
      expect(method.appStore, AppStoreLogin.privacyFocused);
      expect(method.needs, isEmpty);
      expect(method.revokesOnDeletion, isTrue);
      const file = ImportRef.app('core/apple_sign_in/apple_sign_in.dart');
      expect(
        method.credential,
        const FunctionRef('appleCredential', import: file),
      );
      expect(method.icon, const TypeRef('AppleSignInIcon', import: file));
      expect(method.problems(), isEmpty);

      final texts = contributions[4] as RoleData<Object>;
      expect(texts.role, localizationRole);
      expect((texts.value as TextsData).texts, [AppleSignInModule.label]);

      final entitlement = contributions[5] as SocketContribution;
      expect(entitlement.socket, AppEntryRole.iosEntitlements);
      expect(entitlement.entryKey, 'com.apple.developer.applesignin');
      expect(entitlement.entryValue, const PlistStringArray(['Default']));
      expect(entitlement.when, isEmpty);

      final readme = contributions[6] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, 'Sign in with Apple');
      expect(readme.entryValue, readmeSection);

      final note = contributions[7] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, 'Sign in with Apple');
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the apps of the module with the localization role and '
        'without it, with the provider of the auth role', () {
      expect(
        {
          for (final result in results)
            if (result.contractCase.requested.contains(AppleSignInModule.id))
              result.contractCase.name: {
                for (final module in result.resolution!.modules)
                  module.descriptor.id.value,
              },
        },
        {
          'apple_sign_in with localization': {
            'apple_sign_in',
            'gen_l10n',
            'flutter_core',
            'test_auth',
            'shared_preferences',
          },
          'apple_sign_in': {'apple_sign_in', 'flutter_core', 'test_auth'},
        },
      );
    });

    test('finds no errors and no warnings in any app, rendered code included',
        () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(
          result.warnings.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test(
        'renders the file of the module, and the list of the ways to sign in '
        'with it, as code that type-checks with sign_in_with_apple and crypto',
        () async {
      final withModule = [
        for (final result in results)
          if (result.app!.files.containsKey(appleSignInFile)) result,
      ];
      expect(withModule, hasLength(2));
      for (final result in withModule) {
        final app = await DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems({
              _module,
              // The texts of the localization role are a class that
              // gen-l10n generates when the app is built, which the
              // list of an app with the role reads.
              if (!result.hook!.presentRoles.contains(localizationRole))
                const RoleTemplateOrigin(authRole),
            }),
            isEmpty,
            reason: '${result.contractCase}',
          );
        } finally {
          app.delete();
        }
      }
    });
  });

  group('an app with the module', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [
        AppleSignInModule.id,
        GenL10nModule.id,
      ]);
      app = result.app!;
      without = (await _resultOf(const [
        TestAuthModule.id,
        GenL10nModule.id,
      ]))
          .app!;
    });

    test(
        'is the app of the provider of the auth role but for the file of the '
        'module, the files of the roles and of their providers that its way '
        'to sign in, its label and its entitlement change, and the pubspec',
        () {
      // The provider of the app entry and of the localization role, which
      // render the native files and the texts, whichever they are.
      String providerOf(Role role) => [
            for (final module in result.resolution!.providersOf(role))
              '${ModuleOrigin(module.descriptor.id)}',
          ].single;
      final appEntry = providerOf(appEntryRole);
      final localization = providerOf(localizationRole);
      final changed = <String, Set<String>>{};
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (app.files[path]!.text == file.text) continue;
        changed.putIfAbsent('${file.owner}', () => {}).add(path);
      }

      expect(app.files.keys.toSet(), {...without.files.keys, appleSignInFile});
      expect(app.files[appleSignInFile]!.owner, _module);
      expect(
        changed.keys,
        unorderedEquals([
          appEntry,
          '${const RoleTemplateOrigin(appEntryRole)}',
          '${const RoleTemplateOrigin(authRole)}',
          localization,
        ]),
      );
      expect(changed[appEntry], {
        'pubspec.yaml',
        AppEntryRole.readmeFile,
        AppEntryRole.iosEntitlementsFile,
      });
      expect(
        changed['${const RoleTemplateOrigin(appEntryRole)}'],
        {AppEntryRole.agentsFile},
      );
      expect(
        changed['${const RoleTemplateOrigin(authRole)}'],
        {AuthRole.methodsFile},
      );
      // The provider of the localization role has the label of the button
      // in its files with the texts of the app.
      expect(changed[localization], isNotEmpty);
      expect(
        {
          for (final MapEntry(:key, :value) in _dependenciesOf(app).entries)
            if (!_dependenciesOf(without).containsKey(key)) key: value,
        },
        {'sign_in_with_apple': '^8.2.0', 'crypto': '^3.0.7'},
      );
      expect(
        [
          for (final file in app.files.values)
            if (file.path.endsWith('.dart') &&
                (file.text.contains('package:sign_in_with_apple/') ||
                    file.text.contains('package:crypto/')))
              file.path,
        ],
        [appleSignInFile],
      );
    });

    test(
        'has the way to sign in with Apple of the module, on iOS only, which '
        'the App Store takes as an equivalent, and whose deletion asks Apple '
        'again', () {
      final methods = _methodsOf(result);

      expect(methods, hasLength(1));
      expect(methods.single.owner, _module);
      expect(methods.single.method, isA<SignInMethod>());
      final (:items, :labels) = _listOf(app);
      expect(items, [
        {
          'label': '_appleSignInLabel',
          'icon': 'method0.AppleSignInIcon()',
          'platforms': '{TargetPlatform.iOS}',
          'credential': 'method0.appleCredential',
          'issuer': "'https://appleid.apple.com'",
          'revokesOnDeletion': 'true',
        },
      ]);
      // The label is a text of the module, which the app reads in its
      // language.
      expect(
        labels,
        {'_appleSignInLabel': '=> context.l10n.appleSignInLabel;'},
      );
      expect(
        [
          for (final text in localizationRole.textsIn(
            localizationRole.hookInput(result.hook!),
          ))
            if (text.owner == _module) (text.getter, text.text),
        ],
        [('appleSignInLabel', AppleSignInModule.label)],
      );
      // An app on iOS with only a way to sign in that the App Store takes
      // as an equivalent gets no warning of guideline 4.8.
      expect(result.warnings, isEmpty);
    });

    test('reads the label in English in an app without the localization role',
        () async {
      final english = (await _resultOf(const [AppleSignInModule.id])).app!;

      expect(
        _listOf(english).labels,
        {'_appleSignInLabel': "=> 'Continue with Apple';"},
      );
    });

    test(
        'signs the iOS app with the entitlement of Sign in with Apple, with '
        'the value Default', () {
      expect(
        [
          for (final (origin, key, value)
              in app.entriesOf(AppEntryRole.iosEntitlements))
            (origin, key, value),
        ],
        [
          (
            _module,
            'com.apple.developer.applesignin',
            const PlistStringArray(['Default'])
          ),
        ],
      );
      expect(without.entriesOf(AppEntryRole.iosEntitlements), isEmpty);
    });

    test(
        'has the section of the module in the README, after the section of '
        'the auth role, which lists the way to sign in', () {
      final readme = app.files[AppEntryRole.readmeFile]!.text;

      expect(
        readme,
        contains('\n## ${AuthRole.readmeHeading}\n'),
      );
      expect(
        readme,
        contains('\n## Sign in with Apple\n\n$readmeSection'),
      );
      expect(
        readme.indexOf('## ${AuthRole.readmeHeading}'),
        lessThan(readme.indexOf('## Sign in with Apple')),
      );
      expect(
        readme,
        contains('- Continue with Apple, on iOS. Deleting an account that '),
      );
      // The paths that it names are those of the app.
      for (final path in [appleSignInFile, AppEntryRole.iosEntitlementsFile]) {
        expect(_codeOf(readmeSection), contains(path));
        expect(app.files.keys, contains(path));
      }
      expect(
        readmeSection,
        allOf(
          contains('a team of the paid Apple Developer Program'),
          contains('remove the key from `${AppEntryRole.iosEntitlementsFile}`'),
          contains('only the first time that the user signs in'),
          contains('App Store Review Guideline 5.1.1(v)'),
          contains('needs a key of Apple'),
          contains('download that logo and show it in `AppleSignInIcon`'),
        ),
      );
    });

    test(
        'has the note of the module in the guide for coding agents, under a '
        'heading of its own, which names what the file of the module '
        'declares and uses', () {
      final notes = [
        for (final (origin, heading, note)
            in app.entriesOf(AppEntryRole.agentSections))
          if (origin == _module) (heading, note),
      ];
      final file = DartFileIndexer.index(
        appleSignInFile,
        app.files[appleSignInFile]!.text,
      );

      expect(notes, [('Sign in with Apple', AgentNote(agentNote))]);
      expect(agentNote, startsWith('With `sign_in_with_apple`:\n'));
      expect(
        app.files[AppEntryRole.agentsFile]!.text,
        contains('\n## Sign in with Apple\n\n${agentNote.trim()}\n'),
      );
      final code = _codeOf(agentNote);
      expect(
        code,
        containsAll([
          'appleCredential()',
          appleSignInFile,
          AuthRole.appSignInMethods,
          'SignInWithApple.getAppleIDCredential()',
          'generateNonce()',
          'IdTokenCredential',
          'rawNonce',
          'authorizationCode',
          'givenName',
          'familyName',
          'AuthorizationErrorCode.canceled',
          'AuthorizationErrorCode.unknown',
          'notConfigured',
          'unknown',
          'com.apple.developer.applesignin',
          AppEntryRole.iosEntitlementsFile,
          'debugDefaultTargetPlatformOverride',
          'TargetPlatform.iOS',
          'com.aboutyou.dart_packages.sign_in_with_apple',
          'performAuthorizationRequest',
        ]),
      );
      expect(
        file.declaration('appleCredential')?.kind,
        DeclarationKind.function,
      );
      for (final name in [
        'getAppleIDCredential',
        'generateNonce',
        'IdTokenCredential',
        'rawNonce',
        'authorizationCode',
        'givenName',
        'familyName',
        'canceled',
        'unknown',
        'notConfigured',
      ]) {
        expect(file.uses(name), isTrue, reason: name);
      }
      expect(
        app.files[AuthRole.methodsFile]!.text,
        contains('${AuthRole.appSignInMethods} = ['),
      );
    });
  });

  group('the function of the way to sign in', () {
    late Map<Object?, Object?> calls;

    setUpAll(() async {
      final result = await _resultOf(const [AppleSignInModule.id]);
      final app = await DartApp.write(result.app!);
      try {
        calls = (await app.run(_script))! as Map<Object?, Object?>;
      } finally {
        app.delete();
      }
    });

    test(
        'asks Apple for the email address and the full name with the SHA-256 '
        'hash of a new raw nonce each time, and returns the ID token of Apple '
        'with that raw nonce, the authorization code and the name, which '
        'only the first sign-in has', () {
      final [first, second] = calls['two sign-ins']! as List<Object?>;
      expect(first, {
        'type': 'IdTokenCredential',
        'issuer': 'https://appleid.apple.com',
        'idToken': 'token-1',
        'rawNonce': 'raw-nonce-1'.padRight(32, '0'),
        'authorizationCode': 'code-1',
        'givenName': 'Given',
        'familyName': 'Family',
        // The credential names no token.
        'toString': 'IdTokenCredential(https://appleid.apple.com)',
      });
      expect(second, {
        'type': 'IdTokenCredential',
        'issuer': 'https://appleid.apple.com',
        'idToken': 'token-2',
        'rawNonce': 'raw-nonce-2'.padRight(32, '0'),
        'authorizationCode': 'code-2',
        'givenName': null,
        'familyName': null,
        'toString': 'IdTokenCredential(https://appleid.apple.com)',
      });
      expect(calls['their raw nonces differ'], isTrue);
      const request = {
        'scopes': ['email', 'fullName'],
        'nonce is the hash of the raw nonce': true,
      };
      expect(calls['their requests'], [request, request]);
    });

    test(
        'returns null when the user closed the sheet, fails with '
        'notConfigured, and a hint at the README, when Apple answers with an '
        'unknown error, and with unknown when Apple answers with any other '
        'error or with no identity token', () {
      String unknownOf(String code) => 'failed: unknown: '
          'SignInWithAppleAuthorizationException(AuthorizationErrorCode.$code, '
          'The operation of $code failed.)';
      expect(calls['errors'], {
        'canceled': 'null',
        'failed': unknownOf('failed'),
        'invalidResponse': unknownOf('invalidResponse'),
        'notHandled': unknownOf('notHandled'),
        'notInteractive': unknownOf('notInteractive'),
        'unknown': 'failed: notConfigured: Apple answered with an unknown '
            'error (The operation of unknown failed.). It does so when the '
            'app is not signed with the capability Sign in with Apple, which '
            'needs a team of the paid Apple Developer Program, and may do so '
            'on a device without an Apple Account. See the section "Sign in '
            'with Apple" of the README of the app.',
        'credentialExport': unknownOf('credentialExport'),
        'credentialImport': unknownOf('credentialImport'),
        'matchedExcludedCredential': unknownOf('matchedExcludedCredential'),
        'not supported': 'failed: unknown: '
            'SignInWithAppleNotSupportedException(Not supported.)',
        'another error': 'failed: unknown: Bad state: broken',
        'no identity token': 'failed: unknown: Apple gave no identity token.',
      });
      // Each of them asked Apple once.
      expect(calls['requests of the errors'], 12);
    });

    test(
        'fails with notConfigured on every platform but iOS, without asking '
        'Apple', () {
      String failure(String platform) =>
          'failed: notConfigured: Sign in with Apple works on iOS only, and '
          'the app runs on $platform.';
      expect(calls['other platforms'], {
        for (final platform in const [
          'android',
          'fuchsia',
          'linux',
          'macOS',
          'windows',
        ])
          platform: [failure(platform), 0],
      });
    });
  });
}
