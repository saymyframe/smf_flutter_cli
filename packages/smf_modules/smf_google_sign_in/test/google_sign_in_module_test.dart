@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_google_sign_in/bundles/google_sign_in_bundle.dart';
import 'package:smf_google_sign_in/smf_google_sign_in.dart';
import 'package:smf_google_sign_in/src/agents.dart';
import 'package:smf_google_sign_in/src/ios_setup.dart';
import 'package:smf_google_sign_in/src/readme.dart';
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
  GoogleSignInModule(),
  TestAuthModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
];

/// The module as the owner of its files and of its contributions.
const _module = ModuleOrigin(GoogleSignInModule.id);

/// The files of the logo of Google in the app: the image for a screen with
/// one pixel for each logical pixel, and those for the screens with two and
/// with three.
final List<String> _logoFiles = [
  GoogleSignInModule.logoFile,
  ...GoogleSignInModule.logoVariants.values,
];

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

/// The pubspec of [app].
YamlMap _pubspecOf(RenderedApp app) =>
    loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;

/// The dependencies of the pubspec of [app], as plain values.
Map<String, Object?> _dependenciesOf(RenderedApp app) => {
      for (final MapEntry(:key, :value)
          in (_pubspecOf(app)['dependencies'] as YamlMap).entries)
        '$key': value is YamlMap ? {...value} : value,
    };

/// The assets that the pubspec of [app] declares.
List<Object?> _assetsOf(RenderedApp app) => [
      ...(_pubspecOf(app)['flutter'] as YamlMap)['assets'] as YamlList? ??
          const [],
    ];

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// The width and the height in pixels of the PNG image [bytes], which its
/// header has after the signature of the format.
(int, int) _pngSizeOf(List<int> bytes) {
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
  expect(bytes.sublist(12, 16), 'IHDR'.codeUnits);
  return (data.getUint32(16), data.getUint32(20));
}

/// The types of the errors that the catch clauses of [code] catch, in the
/// order of the clauses.
List<String> _caughtTypesOf(String code) {
  final types = <String>[];
  parseString(content: code).unit.accept(_CatchClauses(types.add));
  return types;
}

/// Gives each type of an error that a catch clause catches to [_found].
final class _CatchClauses extends RecursiveAstVisitor<void> {
  _CatchClauses(this._found);

  final void Function(String type) _found;

  @override
  void visitCatchClause(CatchClause node) {
    if (node.exceptionType case final type?) _found(type.toSource());
    super.visitCatchClause(node);
  }
}

/// The keys of the answer of the app delegate that [code], the file of the
/// module, reads: the keys of the map patterns of its code, and the indexes
/// of `answer`.
Set<String> _answerKeysReadBy(String code) {
  final keys = <String>{};
  parseString(content: code).unit.accept(_AnswerKeys(keys.add));
  return keys;
}

/// Gives each key of the answer of the app delegate that the code reads to
/// [_found].
final class _AnswerKeys extends RecursiveAstVisitor<void> {
  _AnswerKeys(this._found);

  final void Function(String key) _found;

  @override
  void visitIndexExpression(IndexExpression node) {
    if ((node.target, node.index)
        case (
          SimpleIdentifier(name: 'answer'),
          SimpleStringLiteral(:final value)
        )) {
      _found(value);
    }
    super.visitIndexExpression(node);
  }

  @override
  void visitMapPatternEntry(MapPatternEntry node) {
    if (node.key case SimpleStringLiteral(:final value)) _found(value);
    super.visitMapPatternEntry(node);
  }
}

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

/// Runs `googleCredential()` of the app of the module without the
/// localization role, with the stand-ins of Flutter and of google_sign_in,
/// once for each of the cases that it scripts, and sends back what each
/// call returned or failed with, the starts of the package and the
/// sign-ins that reached the platform.
const _script = r'''
import 'dart:isolate';

import 'package:contract_app/core/auth/app_session.dart';
import 'package:contract_app/core/google_sign_in/google_sign_in.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// What a call of googleCredential() ended with: the fields of the
/// credential, null, or the reason and the hint of the failure.
Future<Object?> call() async {
  try {
    final credential = await googleCredential();
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

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};

  googleAnswers
    ..add(const GoogleAnswer('token-1'))
    ..add(const GoogleAnswer('token-2'));
  result['two sign-ins'] = [await call(), await call()];
  result['their sign-ins'] = googleSignIns;

  final errors = <String, Object?>{};
  for (final (name, error) in <(String, Object)>[
    for (final code in GoogleSignInExceptionCode.values)
      (
        code.name,
        GoogleSignInException(code: code, description: 'Google of ${code.name}.'),
      ),
    (
      'canceled by the user',
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Cancelled by user.',
      ),
    ),
    (
      'canceled without a description',
      const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    ),
    (
      'canceled when the reauth of the account failed',
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Account reauth failed.',
      ),
    ),
    (
      'canceled when the reauth of the account failed, in another form',
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'GetCredentialCancellationException: Account reauth '
            'failed',
      ),
    ),
    (
      'unknownError of a server client that is no web client',
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: '[28444] Developer console is not set up correctly.',
      ),
    ),
    (
      'unknownError of a server client that is no web client, in another '
          'form',
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'GetCredentialCustomException: 28444: Developer console '
            'is not set up correctly.',
      ),
    ),
    (
      'unknownError with another number',
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'Error 128444.',
      ),
    ),
    (
      'clientConfigurationError without a description',
      const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      ),
    ),
    ('another error', StateError('broken')),
    ('no ID token', const GoogleAnswer(null)),
  ]) {
    googleAnswers.add(error);
    errors[name] = await call();
  }
  result['errors'] = errors;
  result['sign-ins of the errors'] = googleSignIns - 2;
  result['starts'] = googleStarts;
  port.send(result);
}
''';

/// Signs in with Google first in a zone whose microtasks run only while
/// the script flushes them, as those of a widget test in fake time do, and
/// then, once that zone runs none any more, as when the test is over,
/// signs in again in the root zone, as a later test does in real time.
const _otherZoneScript = '''
import 'dart:async';
import 'dart:isolate';

import 'package:contract_app/core/auth/app_session.dart';
import 'package:contract_app/core/google_sign_in/google_sign_in.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};
  final microtasks = <void Function()>[];
  final zone = Zone.current.fork(
    specification: ZoneSpecification(
      scheduleMicrotask: (self, parent, zone, microtask) =>
          microtasks.add(microtask),
    ),
  );
  googleAnswers
    ..add(const GoogleAnswer('token-1'))
    ..add(const GoogleAnswer('token-2'));

  String? first;
  zone.run(
    () => unawaited(
      googleCredential().then(
        (credential) => first = (credential! as IdTokenCredential).idToken,
      ),
    ),
  );
  while (microtasks.isNotEmpty) {
    microtasks.removeAt(0)();
  }
  result['the first sign-in'] = first;

  result['a sign-in after it'] = await Future.any([
    googleCredential().then(
      (credential) => (credential! as IdTokenCredential).idToken,
    ),
    Future<String>.delayed(const Duration(seconds: 1), () => 'still waiting'),
  ]);
  result['starts'] = googleStarts.length;
  port.send(result);
}
''';

/// Runs `googleCredential()` of the app of the module without the
/// localization role on iOS, once for each setup of the iOS app that the
/// app delegate tells of, as the stand-in of the method channel answers
/// for it, and then once on Android, and sends back what each call
/// returned or failed with, how many sign-ins of each reached the
/// platform, the starts of the package after the first call, and the calls
/// of the method channels.
///
/// It uses only `googleCredential()` and the stand-ins, so it runs on an
/// app whose function asks the Google Sign-In SDK without a check too.
const _iosScript = r'''
import 'dart:isolate';

import 'package:contract_app/core/auth/app_session.dart';
import 'package:contract_app/core/google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

const _channel = 'google_sign_in/ios_setup';
const _id = '123456789012-abcdef.apps.googleusercontent.com';
const _scheme = 'com.googleusercontent.apps.123456789012-abcdef';
const _otherId = '210987654321-fedcba.apps.googleusercontent.com';

/// What a call of googleCredential() ended with: the ID token of the
/// credential, null, or the reason and the hint of the failure.
Future<Object?> call() async {
  try {
    final credential = await googleCredential();
    return switch (credential) {
      null => 'null',
      IdTokenCredential() => 'credential: ${credential.idToken}',
    };
  } on AuthFailure catch (failure) {
    return 'failed: ${failure.reason.name}: ${failure.developerHint}';
  } on Object catch (error) {
    return 'threw: $error';
  }
}

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};
  final outcomes = <String, Object?>{};
  final signIns = <String, int>{};
  Future<void> signIn(String name) async {
    googleAnswers
      ..clear()
      ..add(GoogleAnswer('token of $name'));
    final before = googleSignIns;
    outcomes[name] = await call();
    signIns[name] = googleSignIns - before;
  }

  defaultTargetPlatform = TargetPlatform.iOS;
  for (final (name, answer) in <(String, Object?)>[
    (
      'a client without its scheme',
      {
        'serviceInfo': true,
        'serviceInfoClientId': _id,
        'urlSchemes': ['com.example.other'],
      },
    ),
    (
      'a client and its scheme',
      {
        'serviceInfo': true,
        'serviceInfoClientId': _id,
        'urlSchemes': ['com.example.other', _scheme],
      },
    ),
    (
      'its scheme in upper case',
      {
        'serviceInfo': true,
        'serviceInfoClientId': _id,
        'urlSchemes': [_scheme.toUpperCase()],
      },
    ),
    (
      'no CLIENT_ID in GoogleService-Info.plist',
      {
        'serviceInfo': true,
        'urlSchemes': [_scheme],
      },
    ),
    (
      'no GoogleService-Info.plist',
      {
        'serviceInfo': false,
        'urlSchemes': <String>[],
      },
    ),
    (
      'an empty CLIENT_ID',
      {
        'serviceInfo': true,
        'serviceInfoClientId': '',
        'urlSchemes': [_scheme],
      },
    ),
    (
      'GIDClientID alone without its scheme',
      {
        'serviceInfo': false,
        'infoPlistClientId': _id,
        'urlSchemes': <String>[],
      },
    ),
    (
      'GIDClientID alone with its scheme',
      {
        'serviceInfo': false,
        'infoPlistClientId': _id,
        'urlSchemes': [_scheme],
      },
    ),
    (
      'an empty GIDClientID',
      {
        'serviceInfo': false,
        'infoPlistClientId': '',
        'urlSchemes': <String>[],
      },
    ),
    (
      'CLIENT_ID over a GIDClientID whose scheme is there',
      {
        'serviceInfo': true,
        'serviceInfoClientId': _otherId,
        'infoPlistClientId': _id,
        'urlSchemes': [_scheme],
      },
    ),
    ('no answer of the app delegate', null),
    (
      'an error of the app delegate',
      PlatformException(code: 'error', message: 'The setup failed.'),
    ),
    ('an answer of the app delegate that is no map', 'setup'),
    (
      'URL schemes that are no list',
      {
        'serviceInfo': true,
        'serviceInfoClientId': _id,
        'urlSchemes': _scheme,
      },
    ),
  ]) {
    if (answer == null) {
      channelAnswers.remove(_channel);
    } else {
      channelAnswers[_channel] = answer;
    }
    await signIn(name);
    if (outcomes.length == 1) result['starts after the first'] = googleStarts.length;
  }
  final ofIos = [...channelCalls];

  defaultTargetPlatform = TargetPlatform.android;
  await signIn('on Android');

  result['outcomes'] = outcomes;
  result['sign-ins'] = signIns;
  result['calls on iOS'] = ofIos;
  result['calls on Android'] = channelCalls.length - ofIos.length;
  port.send(result);
}
''';

/// Signs in once on iOS, with the answers of the app delegate that it
/// scripts: `GoogleService-Info.plist` has a client without its URL scheme,
/// and the app has the URL scheme of another client, the iOS client of the
/// app's own. Sends back what the call returned or failed with, and the
/// arguments of the start of google_sign_in.
const _ownClientScript = r'''
import 'dart:isolate';

import 'package:contract_app/core/auth/app_session.dart';
import 'package:contract_app/core/google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  defaultTargetPlatform = TargetPlatform.iOS;
  channelAnswers['google_sign_in/ios_setup'] = {
    'serviceInfo': true,
    'serviceInfoClientId': 'files.apps.googleusercontent.com',
    'urlSchemes': ['com.googleusercontent.apps.own'],
  };
  googleAnswers.add(GoogleAnswer('token'));
  Object? outcome;
  try {
    outcome = switch (await googleCredential()) {
      final IdTokenCredential credential => credential.idToken,
      final other => '$other',
    };
  } on AuthFailure catch (failure) {
    outcome = 'failed: ${failure.developerHint}';
  }
  port.send({'outcome': outcome, 'starts': googleStarts});
}
''';

/// Reads the setup of the iOS app with `readGoogleSignInIosSetup()` of the
/// app of the module, on Android and then on iOS, with the answers of the
/// app delegate that it scripts, and sends back the fields of each setup
/// and how many calls reached the method channel.
const _iosSetupScript = '''
import 'dart:isolate';

import 'package:contract_app/core/google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = 'google_sign_in/ios_setup';

Object? fieldsOf(GoogleSignInIosSetup? setup) => setup == null
    ? null
    : {
        'answered': setup.answered,
        'hasServiceInfo': setup.hasServiceInfo,
        'clientId': setup.clientId,
        'source': setup.source,
        'urlSchemes': setup.urlSchemes,
        'urlScheme': setup.urlScheme,
        'problem': setup.problem,
      };

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};
  channelAnswers[_channel] = {
    'serviceInfo': true,
    'serviceInfoClientId': 'one.apps.googleusercontent.com',
    'infoPlistClientId': 'two.apps.googleusercontent.com',
    'urlSchemes': [
      'Com.GoogleUserContent.Apps.Three',
      7,
      'com.googleusercontent.apps.one',
    ],
  };
  result['on Android'] = fieldsOf(await readGoogleSignInIosSetup());
  final onAndroid = channelCalls.length;

  defaultTargetPlatform = TargetPlatform.iOS;
  result['from the files'] = fieldsOf(await readGoogleSignInIosSetup());
  result['with a clientId of the app'] = fieldsOf(
    await readGoogleSignInIosSetup(
      clientId: 'three.apps.googleusercontent.com',
    ),
  );
  result['with an empty clientId of the app'] =
      fieldsOf(await readGoogleSignInIosSetup(clientId: ''));
  channelAnswers[_channel] = null;
  result['an answer without values'] =
      fieldsOf(await readGoogleSignInIosSetup());
  channelAnswers.remove(_channel);
  result['no answer'] = fieldsOf(await readGoogleSignInIosSetup());
  result['calls'] = [onAndroid, channelCalls.length];
  port.send(result);
}
''';

void main() {
  const module = GoogleSignInModule();

  group('GoogleSignInModule', () {
    test(
        'is infrastructure that requires the auth role and uses the '
        'localization role, and depends on no module', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('google_sign_in'));
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
        'contributes its brick, the code of the app delegate that tells the '
        'setup of the iOS app, google_sign_in, the logo of Google among the '
        'assets, its way to sign in with its label, its section of the '
        'README and its note for coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(8));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(googleSignInBundle));
      expect(brick.bundle.name, 'google_sign_in');
      expect(
        [for (final file in brick.bundle.files) file.path]..sort(),
        [googleSignInFile, ..._logoFiles]..sort(),
      );
      expect(brick.vars, {
        'issuer': 'https://accounts.google.com',
        'logo': 'lib/core/google_sign_in/assets/google_logo.png',
        'readme': 'Google sign-in',
        'ios_setup_channel': 'google_sign_in/ios_setup',
        'info_plist': 'ios/Runner/Info.plist',
        'app_delegate': 'ios/Runner/AppDelegate.swift',
      });
      expect(brick.vars['ios_setup_channel'], iosSetupChannel);
      final delegate = contributions[1] as SocketContribution;
      expect(delegate.socket, AppEntryRole.iosAppDelegateEngine);
      expect(delegate.fragment!.code, iosSetupReader);
      expect(delegate.fragment!.imports, isEmpty);
      expect(delegate.when, isEmpty);
      final dependency = contributions[2] as PubspecDependency;
      expect(
        (dependency.package, dependency.constraint, dependency.dev),
        ('google_sign_in', '^7.2.0', false),
      );
      final flutter = contributions[3] as PubspecFlutter;
      expect(flutter.assets, [GoogleSignInModule.logoFile]);
      expect(flutter.fonts, isEmpty);

      final data = contributions[4] as RoleData<Object>;
      expect(data.role, authRole);
      final method = data.value as SignInMethod;
      expect(method.issuer, 'https://accounts.google.com');
      expect(method.issuer, GoogleSignInModule.issuer);
      expect(method.label, GoogleSignInModule.label);
      expect(method.label.name, 'label');
      expect(method.label.en, 'Continue with Google');
      expect(method.label.translations, {'uk': 'Продовжити з Google'});
      expect(method.platforms, {AppPlatform.android, AppPlatform.ios});
      expect(method.appStore, AppStoreLogin.thirdParty);
      // Google knows the Android app by its key, gives the iOS app a
      // client whose reversed id is its URL scheme, and issues the token
      // to the server client of the backend.
      expect(method.needs, {
        SignInNeed.androidCertificate,
        SignInNeed.iosClient,
        SignInNeed.serverClient,
      });
      expect(method.revokesOnDeletion, isFalse);
      const file = ImportRef.app('core/google_sign_in/google_sign_in.dart');
      expect(
        method.credential,
        const FunctionRef('googleCredential', import: file),
      );
      expect(method.icon, const TypeRef('GoogleSignInIcon', import: file));
      expect(method.problems(), isEmpty);

      final texts = contributions[5] as RoleData<Object>;
      expect(texts.role, localizationRole);
      expect((texts.value as TextsData).texts, [GoogleSignInModule.label]);

      final readme = contributions[6] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, 'Google sign-in');
      expect(readme.entryValue, readmeSection);

      final note = contributions[7] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, 'Google sign-in');
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });

    test(
        'keeps the logo of Google in the directory of its file, with the '
        'files for the screens with more pixels next to it, each the same '
        'image of 18 logical pixels', () {
      final directory = File(GoogleSignInModule.logoFile).parent.path;
      final name = GoogleSignInModule.logoFile.substring(directory.length + 1);
      expect(directory, '${File(googleSignInFile).parent.path}/assets');
      expect(GoogleSignInModule.logoVariants, {
        2: '$directory/2.0x/$name',
        3: '$directory/3.0x/$name',
      });
      final files = {
        for (final file in googleSignInBundle.files) file.path: file,
      };
      expect(
        {
          for (final (ratio, path) in [
            (1, GoogleSignInModule.logoFile),
            for (final MapEntry(key: ratio, value: path)
                in GoogleSignInModule.logoVariants.entries)
              (ratio, path),
          ])
            ratio: (
              files[path]!.type,
              _pngSizeOf(base64.decode(files[path]!.data)),
            ),
        },
        {
          1: ('binary', (18, 18)),
          2: ('binary', (36, 36)),
          3: ('binary', (54, 54)),
        },
      );
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
            if (result.contractCase.requested.contains(GoogleSignInModule.id))
              result.contractCase.name: {
                for (final module in result.resolution!.modules)
                  module.descriptor.id.value,
              },
        },
        {
          'google_sign_in with localization': {
            'google_sign_in',
            'gen_l10n',
            'flutter_core',
            'test_auth',
            'shared_preferences',
          },
          'google_sign_in': {'google_sign_in', 'flutter_core', 'test_auth'},
        },
      );
    });

    test(
        'finds no errors in any app, rendered code included, and warns of '
        'each app with the module of guideline 4.8 of the App Store alone', () {
      for (final result in results) {
        final withModule =
            result.contractCase.requested.contains(GoogleSignInModule.id);
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(
          [for (final issue in result.warnings) issue.code],
          [if (withModule) AuthRole.noEquivalentSignInWarning],
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test(
        'renders the file of the module, and the list of the ways to sign in '
        'with it, as code that type-checks with google_sign_in', () async {
      final withModule = [
        for (final result in results)
          if (result.app!.files.containsKey(googleSignInFile)) result,
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
        GoogleSignInModule.id,
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
        'is the app of the provider of the auth role but for the files of '
        'the module, the files of the roles and of their providers that its '
        'way to sign in and its label change, and the pubspec, which gets '
        'google_sign_in and the logo of Google', () {
      // The provider of the app entry and of the localization role, which
      // render the README and the pubspec, and the texts, whichever they
      // are.
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

      expect(
        app.files.keys.toSet(),
        {...without.files.keys, googleSignInFile, ..._logoFiles},
      );
      for (final path in [googleSignInFile, ..._logoFiles]) {
        expect(app.files[path]!.owner, _module, reason: path);
      }
      for (final path in _logoFiles) {
        expect(
          app.files[path]!.bytes,
          File('bricks/google_sign_in/__brick__/$path').readAsBytesSync(),
          reason: 'The app gets the image of the brick as it is: $path',
        );
      }
      expect(
        changed.keys,
        unorderedEquals([
          appEntry,
          '${const RoleTemplateOrigin(appEntryRole)}',
          '${const RoleTemplateOrigin(authRole)}',
          localization,
        ]),
      );
      expect(
        changed[appEntry],
        {
          'pubspec.yaml',
          AppEntryRole.readmeFile,
          // The code that tells the setup of the iOS app.
          AppEntryRole.appDelegateFile,
        },
      );
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
        {'google_sign_in': '^7.2.0'},
      );
      expect(_assetsOf(without), isEmpty);
      // Flutter takes the files for the screens with more pixels next to
      // the declared one.
      expect(_assetsOf(app), [GoogleSignInModule.logoFile]);
      expect(
        [
          for (final file in app.files.values)
            if (file.path.endsWith('.dart') &&
                file.text.contains('package:google_sign_in/'))
              file.path,
        ],
        [googleSignInFile],
      );
      expect(
        app.files[googleSignInFile]!.text,
        contains(
          "const String _logo = '${GoogleSignInModule.logoFile}';",
        ),
      );
    });

    test(
        'has the way to sign in with Google of the module, on Android and '
        'iOS, which is a login service of a third party for the App Store, '
        'and warns of guideline 4.8 without an equivalent', () {
      final methods = _methodsOf(result);

      expect(methods, hasLength(1));
      expect(methods.single.owner, _module);
      expect(methods.single.method, isA<SignInMethod>());
      final (:items, :labels) = _listOf(app);
      expect(items, [
        {
          'label': '_googleSignInLabel',
          'icon': 'method0.GoogleSignInIcon()',
          'platforms': '{TargetPlatform.android, TargetPlatform.iOS}',
          'credential': 'method0.googleCredential',
          'issuer': "'https://accounts.google.com'",
        },
      ]);
      // The label is a text of the module, which the app reads in its
      // language.
      expect(
        labels,
        {'_googleSignInLabel': '=> context.l10n.googleSignInLabel;'},
      );
      expect(
        [
          for (final text in localizationRole.textsIn(
            localizationRole.hookInput(result.hook!),
          ))
            if (text.owner == _module) (text.getter, text.text),
        ],
        [('googleSignInLabel', GoogleSignInModule.label)],
      );
      expect(
        [
          for (final issue in result.warnings)
            (issue.code, issue.message, issue.hint),
        ],
        [
          (
            AuthRole.noEquivalentSignInWarning,
            'The app offers Continue with Google on iOS, a login service of a '
                'third party, but no way to sign in that the App Store takes '
                'as an equivalent: one that asks for no more than the name '
                'and the email address of the user and lets the user keep the '
                'address private (App Store Review Guideline 4.8).',
            'Add such a way to sign in on iOS, such as Sign in with Apple.',
          ),
        ],
      );
    });

    test(
        'gives the app delegate the code that answers the method channel of '
        'the setup of the iOS app, with the keys that the function of the '
        'module reads', () {
      expect(
        [
          for (final collected in app
              .socketOrders[AppEntryRole.iosAppDelegateEngine]!.contributions)
            (
              collected.origin,
              (collected.contribution as SocketContribution).fragment!.code,
            ),
        ],
        [(_module, iosSetupReader)],
      );
      expect(iosSetupReader, contains('name: "$iosSetupChannel",'));
      // The lines of the body of the method are indented by four spaces.
      expect(
        [
          for (final line in iosSetupReader.split('\n'))
            if (!line.startsWith('    ')) line,
        ],
        isEmpty,
      );
      final answered = {
        for (final match in RegExp(r'^\s*"(\w+)": ', multiLine: true)
            .allMatches(iosSetupReader))
          match[1]!,
        for (final match
            in RegExp(r'\bsetup\["(\w+)"\]').allMatches(iosSetupReader))
          match[1]!,
      };
      expect(
        answered,
        {
          'serviceInfo',
          'urlSchemes',
          'serviceInfoClientId',
          'infoPlistClientId',
        },
      );
      expect(
        _answerKeysReadBy(app.files[googleSignInFile]!.text),
        answered,
        reason: 'The function of the module reads what the app delegate '
            'answers.',
      );
    });

    test(
        'reads the setup of the iOS app under the names by which '
        'google_sign_in_ios and the Google Sign-In SDK read it', () {
      // GoogleSignInPlugin.swift of google_sign_in_ios 6.3.8 reads CLIENT_ID
      // of GoogleService-Info.plist. GIDSignIn.m of GoogleSignIn-iOS 9.2.0
      // reads GIDClientID of Info.plist, and GIDSignInCallbackSchemes.m of
      // the same release reads the schemes of each entry of CFBundleURLTypes.
      // With one name misspelled, the app delegate would find no iOS client
      // in any app, so every sign-in on iOS would fail, and the probe of the
      // start check would pass whatever the setup.
      for (final name in [
        'Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")',
        'serviceInfo?["CLIENT_ID"] as? String',
        'Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String',
        'Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes")',
        r'$0["CFBundleURLSchemes"] as? [String]',
      ]) {
        expect(iosSetupReader, contains(name));
      }
    });

    test('reads the label in English in an app without the localization role',
        () async {
      final english = (await _resultOf(const [GoogleSignInModule.id])).app!;

      expect(
        _listOf(english).labels,
        {'_googleSignInLabel': "=> 'Continue with Google';"},
      );
    });

    test(
        'has the section of the module in the README, after the section of '
        'the auth role, which lists the way to sign in', () {
      final readme = app.files[AppEntryRole.readmeFile]!.text;

      expect(readme, contains('\n## ${AuthRole.readmeHeading}\n'));
      expect(readme, contains('\n## Google sign-in\n\n$readmeSection'));
      expect(
        readme.indexOf('## ${AuthRole.readmeHeading}'),
        lessThan(readme.indexOf('## Google sign-in')),
      );
      expect(readme, contains('- Continue with Google, on Android and iOS.\n'));
      // The paths that it names are those of the app.
      for (final path in [
        googleSignInFile,
        GoogleSignInModule.logoFile,
        AppEntryRole.infoPlistFile,
        AppEntryRole.appDelegateFile,
      ]) {
        expect(_codeOf(readmeSection), contains(path));
        expect(app.files.keys, contains(path));
      }
      expect(
        readmeSection,
        allOf([
          contains('the SHA-1 of each key that signs it'),
          contains('the reversed id of that client as a URL scheme in '
              '`CFBundleURLTypes`'),
          contains('the server client'),
          contains('`GoogleSignIn.instance.initialize()` without ids'),
          contains('`default_web_client_id`'),
          contains(
              'The section of the provider of sign-in in this README tells '
              'which of these it sets up.'),
          contains('fails with the reason `notConfigured`'),
          contains('On iOS, the Google Sign-In SDK stops the app instead of '
              'failing when the app has no iOS client of Google, when the id '
              'of that client is empty, or when the app lacks the URL scheme '
              'of that client.'),
          contains('`googleCredential()` first asks '
              '`${AppEntryRole.appDelegateFile}`'),
          contains('the handler of the method channel `$iosSetupChannel` in '
              '`didInitializeImplicitFlutterEngine(_:)` of the app delegate, '
              'so keep it there'),
          contains('To use an iOS client of your own, set `_iosClientId` in '
              '`$googleSignInFile`: `googleCredential()` gives that id to '
              'both `initialize()` and `readGoogleSignInIosSetup()`'),
          contains('- `[16] Account reauth failed.`, after the user picked '
              'an account: Google does not know the SHA-1 of the key that '
              'signed this build of the app.'),
          contains('A device that cannot reach Google gets the same answer.'),
          contains('- `[28444] Developer console is not set up correctly.`: '
              'Google does not take the server client of the app as a web '
              'client of the Google project'),
          contains('such as the one of the `sign_in` module'),
          contains('pass its id to `initialize()` in `googleCredential()` '
              'as `serverClientId`'),
          contains('the logo of the Google Sign-In SDK (Apache License 2.0)'),
          contains('keep the image as it is'),
        ]),
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
        googleSignInFile,
        app.files[googleSignInFile]!.text,
      );

      expect(notes, [('Google sign-in', AgentNote(agentNote))]);
      expect(agentNote, startsWith('With `google_sign_in`:\n'));
      expect(
        app.files[AppEntryRole.agentsFile]!.text,
        contains('\n## Google sign-in\n\n${agentNote.trim()}\n'),
      );
      final code = _codeOf(agentNote);
      expect(
        code,
        containsAll([
          'googleCredential()',
          googleSignInFile,
          AuthRole.appSignInMethods,
          'GoogleSignIn.instance.initialize()',
          'GoogleSignIn.instance.authenticate()',
          'IdTokenCredential',
          'idToken',
          'rawNonce',
          'GoogleSignInExceptionCode.canceled',
          'canceled',
          'Account reauth failed',
          'clientConfigurationError',
          'providerConfigurationError',
          'unknownError',
          '28444',
          'notConfigured',
          'unknown',
          'GoogleSignInIcon',
          GoogleSignInModule.logoFile,
          'pubspec.yaml',
          'IconTheme',
          'GoogleSignInPlatform.instance',
          'GoogleSignInPlatform',
          'init',
          'authenticate',
          'readGoogleSignInIosSetup()',
          '_iosClientId',
          'initialize()',
          iosSetupChannel,
          'didInitializeImplicitFlutterEngine(_:)',
          AppEntryRole.appDelegateFile,
          'problem',
          'setMockMethodCallHandler',
          'serviceInfo',
          'serviceInfoClientId',
          'urlSchemes',
        ]),
      );
      for (final (name, kind) in [
        ('googleCredential', DeclarationKind.function),
        ('GoogleSignInIcon', DeclarationKind.classType),
        ('readGoogleSignInIosSetup', DeclarationKind.function),
        ('GoogleSignInIosSetup', DeclarationKind.classType),
        ('_iosClientId', DeclarationKind.variable),
      ]) {
        expect(file.declaration(name)?.kind, kind, reason: name);
      }
      for (final name in [
        'initialize',
        'authenticate',
        'IdTokenCredential',
        'idToken',
        'canceled',
        'clientConfigurationError',
        'providerConfigurationError',
        'unknownError',
        'notConfigured',
        'unknown',
        'IconTheme',
        'problem',
      ]) {
        expect(file.uses(name), isTrue, reason: name);
      }
      expect(
        _caughtTypesOf(app.files[googleSignInFile]!.text),
        [
          'MissingPluginException',
          'PlatformException',
          'GoogleSignInException',
          'Object',
        ],
      );
      expect(file.uses('rawNonce'), isFalse);
      expect(
        app.files[AuthRole.methodsFile]!.text,
        contains('${AuthRole.appSignInMethods} = ['),
      );
    });
  });

  group('the function of the way to sign in', () {
    late Map<Object?, Object?> calls;
    late Map<Object?, Object?> otherZone;
    late Map<Object?, Object?> onIos;
    late Map<Object?, Object?> iosSetup;

    setUpAll(() async {
      final result = await _resultOf(const [GoogleSignInModule.id]);
      final app = await DartApp.write(result.app!);
      try {
        calls = (await app.run(_script))! as Map<Object?, Object?>;
        otherZone = (await app.run(_otherZoneScript))! as Map<Object?, Object?>;
        onIos = (await app.run(_iosScript))! as Map<Object?, Object?>;
        iosSetup = (await app.run(_iosSetupScript))! as Map<Object?, Object?>;
      } finally {
        app.delete();
      }
    });

    test(
        "gives the iOS client of the app's own, _iosClientId, to both the "
        'start of google_sign_in and the check of the setup of the iOS app',
        () async {
      const declaration = 'const String? _iosClientId = null;';
      final result = await _resultOf(const [GoogleSignInModule.id]);
      final rendered = result.app!;
      expect(rendered.files[googleSignInFile]!.text, contains(declaration));
      final app = await DartApp.write(
        RenderedApp([
          for (final file in rendered.files.values)
            file.path == googleSignInFile
                ? RenderedFile(
                    path: file.path,
                    bytes: utf8.encode(
                      file.text.replaceFirst(
                        declaration,
                        'const String? _iosClientId = '
                        "'own.apps.googleusercontent.com';",
                      ),
                    ),
                    owner: file.owner,
                  )
                : file,
        ]),
      );
      try {
        expect(await app.run(_ownClientScript), {
          'outcome': 'token',
          'starts': [
            {
              'clientId': 'own.apps.googleusercontent.com',
              'serverClientId': null,
              'nonce': null,
              'hostedDomain': null,
            },
          ],
        });
      } finally {
        app.delete();
      }
    });

    test(
        'on iOS, asks the app delegate for the setup that the Google Sign-In '
        'SDK reads, and fails with notConfigured, without asking the SDK, '
        'when the SDK would stop the app: without an iOS client of Google, '
        'with an empty one, or without its URL scheme', () {
      const scheme = 'com.googleusercontent.apps.123456789012-abcdef';
      const other = 'com.googleusercontent.apps.210987654321-fedcba';
      String notConfigured(String problem) => 'failed: notConfigured: Google '
          'sign-in is not set up for the app ($problem). The Google Sign-In '
          'SDK stops an iOS app whose setup it cannot use, so the app did not '
          'ask it. See the section "Google sign-in" of the README of the app.';
      String noScheme(String scheme, String source) => notConfigured(
            '${AppEntryRole.infoPlistFile} has no URL scheme $scheme, the '
            'reversed id of the iOS client of Google in $source, among '
            'CFBundleURLSchemes of CFBundleURLTypes: add it there',
          );
      String noClient(String serviceInfo) => notConfigured(
            'the iOS app has no iOS client of Google: $serviceInfo, and '
            '${AppEntryRole.infoPlistFile} has no GIDClientID',
          );
      String empty(String source) => notConfigured(
            'the id of the iOS client of Google in $source is empty',
          );
      const serviceInfo = 'CLIENT_ID of GoogleService-Info.plist';
      const infoPlist = 'GIDClientID of ${AppEntryRole.infoPlistFile}';
      final noAnswer = notConfigured(
        '${AppEntryRole.appDelegateFile} does not answer, or fails, on the '
        'method channel google_sign_in/ios_setup, through which the app '
        'learns whether the Google Sign-In SDK finds the iOS client of Google '
        'and its URL scheme',
      );

      expect(
        onIos['outcomes'],
        {
          'a client without its scheme': noScheme(scheme, serviceInfo),
          'a client and its scheme': 'credential: token of a client and its '
              'scheme',
          'its scheme in upper case': 'credential: token of its scheme in '
              'upper case',
          'no CLIENT_ID in GoogleService-Info.plist':
              noClient('GoogleService-Info.plist has no CLIENT_ID'),
          'no GoogleService-Info.plist':
              noClient('the app has no GoogleService-Info.plist'),
          'an empty CLIENT_ID': empty(serviceInfo),
          'GIDClientID alone without its scheme': noScheme(scheme, infoPlist),
          'GIDClientID alone with its scheme': 'credential: token of '
              'GIDClientID alone with its scheme',
          'an empty GIDClientID': empty(infoPlist),
          'CLIENT_ID over a GIDClientID whose scheme is there':
              noScheme(other, serviceInfo),
          'no answer of the app delegate': noAnswer,
          'an error of the app delegate': noAnswer,
          'an answer of the app delegate that is no map': noAnswer,
          'URL schemes that are no list': noScheme(scheme, serviceInfo),
          'on Android': 'credential: token of on Android',
        },
        reason: 'The Google Sign-In SDK stops an iOS app without its iOS '
            'client of Google, with an empty one, or without the URL scheme '
            'of that client, which it compares in lower case; a CLIENT_ID of '
            'GoogleService-Info.plist comes before the GIDClientID of '
            'Info.plist. An app delegate that does not answer, fails or gives '
            'an answer of another form leaves the app unable to tell, so the '
            'call fails rather than let the SDK stop the app.',
      );
      expect(
        onIos['sign-ins'],
        {
          for (final MapEntry(:key, :value)
              in (onIos['outcomes']! as Map<Object?, Object?>).entries)
            key: '$value'.startsWith('credential: ') ? 1 : 0,
        },
        reason: 'A call that the check fails asks the SDK nothing.',
      );
      expect(
        onIos['starts after the first'],
        0,
        reason: 'A call that the check fails does not start google_sign_in '
            'either.',
      );
      expect(
        onIos['calls on iOS'],
        List.filled(14, '$iosSetupChannel read'),
        reason: 'Each call on iOS asks the app delegate once.',
      );
      expect(
        onIos['calls on Android'],
        0,
        reason: 'On Android, which has no such setup, nothing asks the app '
            'delegate.',
      );
    });

    test(
        'reads the setup of the iOS app as the Google Sign-In SDK takes it: '
        'the clientId of the app before CLIENT_ID of GoogleService-Info.plist '
        'before GIDClientID of Info.plist, and the URL schemes in lower case; '
        'and on another platform reads nothing', () {
      const fromApp = 'the clientId that the app gives initialize()';
      const schemes = [
        'com.googleusercontent.apps.three',
        'com.googleusercontent.apps.one',
      ];
      expect(iosSetup, {
        'on Android': null,
        'from the files': {
          'answered': true,
          'hasServiceInfo': true,
          'clientId': 'one.apps.googleusercontent.com',
          'source': 'CLIENT_ID of GoogleService-Info.plist',
          'urlSchemes': schemes,
          'urlScheme': 'com.googleusercontent.apps.one',
          'problem': null,
        },
        'with a clientId of the app': {
          'answered': true,
          'hasServiceInfo': true,
          'clientId': 'three.apps.googleusercontent.com',
          'source': fromApp,
          'urlSchemes': schemes,
          'urlScheme': 'com.googleusercontent.apps.three',
          'problem': null,
        },
        'with an empty clientId of the app': {
          'answered': true,
          'hasServiceInfo': true,
          'clientId': '',
          'source': fromApp,
          'urlSchemes': schemes,
          'urlScheme': '',
          'problem': 'the id of the iOS client of Google in $fromApp is empty',
        },
        'an answer without values': {
          'answered': true,
          'hasServiceInfo': false,
          'clientId': null,
          'source': null,
          'urlSchemes': <String>[],
          'urlScheme': null,
          'problem': 'the iOS app has no iOS client of Google: the app has no '
              'GoogleService-Info.plist, and ${AppEntryRole.infoPlistFile} has '
              'no GIDClientID',
        },
        'no answer': {
          'answered': false,
          'hasServiceInfo': false,
          'clientId': null,
          'source': null,
          'urlSchemes': <String>[],
          'urlScheme': null,
          'problem': '${AppEntryRole.appDelegateFile} does not answer, or '
              'fails, on the method channel $iosSetupChannel, through which '
              'the app learns whether the Google Sign-In SDK finds the iOS '
              'client of Google and its URL scheme',
        },
        'calls': [0, 5],
      });
    });

    test(
        'waits for the start of google_sign_in in the zone of each call: a '
        'widget test in fake time may sign in first, before a later test '
        'signs in in real time', () {
      expect(otherZone, {
        'the first sign-in': 'token-1',
        'a sign-in after it': 'token-2',
        'starts': 1,
      });
    });

    test(
        'starts google_sign_in once, without the ids of the clients, and '
        'returns the ID token of the account as a credential of Google', () {
      Map<String, Object?> credential(String idToken) => {
            'type': 'IdTokenCredential',
            'issuer': 'https://accounts.google.com',
            'idToken': idToken,
            'rawNonce': null,
            'authorizationCode': null,
            'givenName': null,
            'familyName': null,
            // The credential names no token.
            'toString': 'IdTokenCredential(https://accounts.google.com)',
          };
      expect(calls['two sign-ins'], [
        credential('token-1'),
        credential('token-2'),
      ]);
      expect(calls['their sign-ins'], 2);
      // Every call of the script, the failed ones too, started the package
      // at most once.
      expect(calls['starts'], [
        {
          'clientId': null,
          'serverClientId': null,
          'nonce': null,
          'hostedDomain': null,
        },
      ]);
    });

    test(
        'returns null when the user closed the sheet, fails with '
        'notConfigured, and a hint at the README, when Google refuses an app '
        'that is not set up for it, and with unknown when Google answers '
        'with any other error or with no ID token', () {
      String notConfigured(String message) => 'failed: notConfigured: Google '
          'sign-in is not set up for the app ($message). See the section '
          '"Google sign-in" of the README of the app.';
      String reauthFailed(String message) => 'failed: notConfigured: Google '
          'sign-in is not set up for the app ($message). On Android, '
          'Credential Manager answers so when Google does not know the SHA-1 '
          'of the key that signed this build of the app, and also when the '
          'device cannot reach Google. See the section "Google sign-in" of '
          'the README of the app.';
      String unknownOf(String code) => 'failed: unknown: '
          'GoogleSignInException(code GoogleSignInExceptionCode.$code, '
          'Google of $code., null)';
      expect(
        calls['errors'],
        {
          'unknownError': unknownOf('unknownError'),
          'canceled': 'null',
          'interrupted': unknownOf('interrupted'),
          'clientConfigurationError':
              notConfigured('Google of clientConfigurationError.'),
          'providerConfigurationError':
              notConfigured('Google of providerConfigurationError.'),
          'uiUnavailable': unknownOf('uiUnavailable'),
          'userMismatch': unknownOf('userMismatch'),
          'canceled by the user': 'null',
          'canceled without a description': 'null',
          'canceled when the reauth of the account failed':
              reauthFailed('[16] Account reauth failed.'),
          'canceled when the reauth of the account failed, in another form':
              reauthFailed(
            'GetCredentialCancellationException: Account reauth failed',
          ),
          'unknownError of a server client that is no web client':
              notConfigured(
            '[28444] Developer console is not set up correctly.',
          ),
          'unknownError of a server client that is no web client, in another '
              'form': notConfigured(
            'GetCredentialCustomException: 28444: Developer console is not '
            'set up correctly.',
          ),
          'unknownError with another number': 'failed: unknown: '
              'GoogleSignInException(code '
              'GoogleSignInExceptionCode.unknownError, Error 128444., null)',
          'clientConfigurationError without a description':
              notConfigured('clientConfigurationError'),
          'another error': 'failed: unknown: Bad state: broken',
          'no ID token': 'failed: unknown: Google gave no ID token.',
        },
        reason: 'A cancel of Credential Manager whose reauth of the account '
            'failed, which it answers after the user picked an account when '
            'Google does not know the SHA-1 of the key that signed the app, '
            'is no closed sheet.',
      );
      // Each of them asked Google once.
      expect(calls['sign-ins of the errors'], 17);
    });
  });
}
