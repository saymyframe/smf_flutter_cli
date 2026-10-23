@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_revenuecat/bundles/revenuecat_bundle.dart';
import 'package:smf_revenuecat/smf_revenuecat.dart';
import 'package:smf_revenuecat/src/agents.dart';
import 'package:smf_revenuecat/src/readme.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module and dart_define, a provider of the env role, which it requires,
/// and the providers of the roles that the purchases role uses, with what
/// they need: firebase_auth with firebase_core, settings with go_router,
/// and gen_l10n with shared_preferences.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  SettingsModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
  DartDefineModule(),
  FirebaseCoreModule(),
  FirebaseAuthModule(),
  RevenueCatModule(),
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

/// The inline code of [markdown]: what stands between two backticks,
/// outside its blocks of code.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(
        markdown.replaceAll(RegExp(r'```[\s\S]*?```'), ''),
      ))
        match[1]!,
    };

/// The calls of the function [name] in [node].
List<MethodInvocation> _callsOf(String name, AstNode node) {
  final calls = <MethodInvocation>[];
  node.accept(_Calls(name, calls));
  return calls;
}

final class _Calls extends RecursiveAstVisitor<void> {
  _Calls(this._name, this._calls);

  final String _name;
  final List<MethodInvocation> _calls;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == _name) _calls.add(node);
    super.visitMethodInvocation(node);
  }
}

/// Runs the service of the module on the stand-in for purchases_flutter
/// and sends back, for each step, what reached RevenueCat and what the
/// step ended with: the key that `revenueCatKey` chooses, a service without
/// a key, a configuration that RevenueCat holds, the identifications, the
/// reason of each code of RevenueCat, a cancel and a purchase that gives no
/// premium access.
const _script = r'''
import 'dart:async';
import 'dart:isolate';

import 'package:contract_app/core/purchases/purchases_service.dart';
import 'package:contract_app/core/purchases/revenuecat_purchases_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

String key(RevenueCatKey key) =>
    key.value == null ? 'none: ${key.hint}' : '${key.name}=${key.value}';

String outcome(Object? value) => switch (value) {
      PurchasesFailure(:final reason, :final developerHint) =>
        'failed: ${reason.name} ($developerHint)',
      _ => '= $value',
    };

/// What reached RevenueCat while [action] ran, and what it ended with.
Future<List<String>> step(Future<Object?> Function() action) async {
  revenueCatCalls.clear();
  Object? result;
  try {
    result = await action();
  } on Object catch (error) {
    result = error;
  }
  return [...revenueCatCalls, outcome(result)];
}

PlatformException failure(String code, {bool? userCancelled}) =>
    PlatformException(
      code: code,
      message: 'RevenueCat failed.',
      details: userCancelled == null ? null : {'userCancelled': userCancelled},
    );

const package = Package(
  r'$rc_annual',
  StoreProduct('premium_annual', 'Annual (App)', 39.99, r'$39.99', 'USD',
      subscriptionPeriod: 'P1Y'),
);

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};

  result['keys'] = {
    'debug with the test key': key(revenueCatKey(
        platform: TargetPlatform.android, debug: true,
        apple: 'appl_a', google: 'goog_g', test: 'test_t')),
    'release with the test key': key(revenueCatKey(
        platform: TargetPlatform.iOS, debug: false,
        apple: 'appl_a', google: 'goog_g', test: 'test_t')),
    'empty': key(revenueCatKey(platform: TargetPlatform.android, debug: true,
        apple: 'appl_a', google: null, test: null)),
    'secret': key(revenueCatKey(platform: TargetPlatform.android, debug: true,
        apple: 'appl_a', google: 'sk_secret', test: null)),
    'test key of a store in release': key(revenueCatKey(
        platform: TargetPlatform.android, debug: false,
        apple: 'appl_a', google: 'test_t', test: null)),
  };

  final none = RevenueCatPurchasesService(const RevenueCatKey.none('No key.'));
  result['without a key'] = [
    ...await step(() => none.identify(null)),
    ...await step(none.access),
    ...await step(none.restore),
  ];

  final held = holdNext['setupPurchases'] = Completer<void>();
  final service = RevenueCatPurchasesService(
    const RevenueCatKey('REVENUECAT_GOOGLE_KEY', 'goog_tests'),
  );
  final calls = Future.wait([service.identify(null), service.access()]);
  await Future<void>.delayed(const Duration(milliseconds: 10));
  result['while configuring'] = [...revenueCatCalls];
  held.complete();
  await calls;
  result['once configured'] = [...revenueCatCalls];

  result['identify'] = [
    ...await step(() => service.identify('user-a')),
    ...await step(() => service.identify(null)),
    ...await step(() => service.identify(null)),
  ];
  anonymous = false;
  failNext['logOut'] = failure('22');
  result['logOut of an anonymous user'] =
      await step(() => service.identify(null));

  final reasons = <String, String>{};
  for (final code in ['20', '10', '6', '3', '5', '11', '2', '42', '22', '99',
      'error']) {
    failNext['getCustomerInfo'] = failure(code);
    try {
      await service.access();
    } on PurchasesFailure catch (failure) {
      reasons[code] = failure.reason.name;
    }
  }
  result['reasons'] = reasons;

  failNext['getCustomerInfo'] = StateError('not a failure of RevenueCat');
  result['another error'] = await step(service.access);

  failNext['setupPurchases'] = MissingPluginException('No implementation');
  final unmocked = RevenueCatPurchasesService(
    const RevenueCatKey('REVENUECAT_GOOGLE_KEY', 'goog_tests'),
  );
  result['without a platform side'] = [
    await unmocked.configured,
    ...await step(unmocked.access),
  ];
  failNext['setupPurchases'] = StateError('broken');
  final broken = RevenueCatPurchasesService(
    const RevenueCatKey('REVENUECAT_GOOGLE_KEY', 'goog_tests'),
  );
  result['configuration that fails otherwise'] = [
    await broken.configured,
    ...await step(broken.access),
  ];

  customerInfo = const CustomerInfo(
    EntitlementInfos({
      'premium': EntitlementInfo(
        'premium_annual',
        willRenew: true,
        expirationDate: '2099-01-01T00:00:00.000Z',
      ),
    }),
  );
  final heldOfferings = holdNext['getOfferings'] = Completer<void>();
  final took = Stopwatch()..start();
  final first = await service.access() as PremiumAccess;
  took.stop();
  offerings = const Offerings({'default': Offering('default', [package])},
      current: Offering('default', [package]));
  heldOfferings.complete();
  await Future<void>.delayed(const Duration(milliseconds: 10));
  final later = await service.access() as PremiumAccess;
  result['offerings that come late'] = [
    '${first.period}',
    took.elapsed < const Duration(seconds: 3),
    '${later.period}',
  ];
  customerInfo = const CustomerInfo(EntitlementInfos({}));

  final plan = (await service.plans()).single;
  failNext['purchasePackage'] = failure('1');
  result['cancel by code'] = await step(() => service.purchase(plan));
  failNext['purchasePackage'] = failure('2', userCancelled: true);
  result['cancel by details'] = await step(() => service.purchase(plan));
  result['no premium'] = await step(() => service.purchase(plan));

  port.send(result);
}
''';

void main() {
  const module = RevenueCatModule();

  group('RevenueCatModule', () {
    test(
        'is infrastructure that provides the purchases role and requires the '
        'env role, for its keys', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('revenuecat'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {purchasesRole});
      expect(descriptor.requires, {envRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick with the variables of its keys and of the '
        'entitlement, purchases_flutter, its implementation of the service, '
        'created without waiting, its three keys, its four steps by hand, its '
        'section of the README and its note for coding agents, and nothing '
        'else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(12));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(revenuecatBundle));
      expect(brick.bundle.name, 'revenuecat');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [serviceFile],
      );
      expect(brick.vars.keys, [
        'env_revenuecat_apple_key',
        'env_revenuecat_google_key',
        'env_revenuecat_test_key',
        'entitlement',
        'values_heading',
      ]);
      expect(brick.vars['values_heading'], EnvRole.readmeHeading);
      expect(brick.vars['entitlement'], 'premium');
      for (final key in RevenueCatModule.keys) {
        final variable = brick.vars['env_${key.name.toLowerCase()}']!;
        expect(
          ((variable as RoleVar).role, variable.absent),
          (envRole, 'null'),
          reason: key.name,
        );
      }
      final plugin = contributions[1] as PubspecDependency;
      expect(
        (plugin.package, plugin.constraint, plugin.dev),
        ('purchases_flutter', '^10.18.0', false),
      );
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, purchasesRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'RevenueCatPurchasesService');
      expect(implementation.create!.name, 'createRevenueCatPurchasesService');
      expect(implementation.create!.deps, isEmpty);
      expect(implementation.create!.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', serviceFile);
      expect(
        [
          for (final contribution in contributions.sublist(3, 6))
            ((contribution as RoleData<Object>).role, contribution.value),
        ],
        [
          for (final key in RevenueCatModule.keys) (envRole, key),
        ],
      );
      expect(contributions.sublist(6, 10), [
        RevenueCatModule.entitlementAndOfferingStep,
        RevenueCatModule.apiKeysStep,
        RevenueCatModule.appStoreKeyStep,
        RevenueCatModule.playServiceAccountStep,
      ]);
      final readme = contributions[10] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(
        (readme.entryKey, readme.entryValue),
        ('RevenueCat', readmeSection),
      );
      final note = contributions[11] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, purchasesRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      for (final contribution in contributions) {
        expect(contribution.when, isEmpty, reason: '$contribution');
      }
    });

    test(
        'has the keys of the public API keys of the App Store app, of the '
        'Play Store app and of the Test Store, which the env role takes', () {
      expect(
        {
          for (final key in RevenueCatModule.keys)
            key.name: '${key.getter}: ${key.description}',
        },
        {
          'REVENUECAT_APPLE_KEY': 'revenuecatAppleKey: The public API key of '
              'the App Store app in RevenueCat, which starts with appl_',
          'REVENUECAT_GOOGLE_KEY': 'revenuecatGoogleKey: The public API key '
              'of the Play Store app in RevenueCat, which starts with goog_',
          'REVENUECAT_TEST_KEY': 'revenuecatTestKey: The public API key of the '
              'Test Store in RevenueCat, which starts with test_, for debug '
              'builds only',
        },
      );
      for (final key in RevenueCatModule.keys) {
        expect(key.problems(), isEmpty, reason: key.name);
      }
    });

    test('has its steps by hand under ids of its own', () {
      expect(
        {
          for (final step in [
            RevenueCatModule.entitlementAndOfferingStep,
            RevenueCatModule.apiKeysStep,
            RevenueCatModule.appStoreKeyStep,
            RevenueCatModule.playServiceAccountStep,
          ])
            step.id.wire: step.title,
        },
        {
          'revenuecat.entitlement_and_offering': 'Set up the entitlement '
              'premium and the default offering in RevenueCat',
          'revenuecat.api_keys': 'Copy the API keys of your RevenueCat apps '
              'into .env',
          'revenuecat.app_store_key': 'Give RevenueCat your In-App Purchase '
              'key from App Store Connect',
          'revenuecat.play_service_account': 'Give RevenueCat access to Google '
              'Play with a service account',
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
        'builds an app of the module with each subset of the roles that the '
        'purchases role uses', () async {
      expect(
        [
          for (final result in results)
            if (result.contractCase.requested.contains(RevenueCatModule.id))
              result.contractCase.name,
        ],
        [
          'revenuecat with auth, settings_screen, localization',
          'revenuecat with auth, settings_screen',
          'revenuecat with auth, localization',
          'revenuecat with settings_screen, localization',
          'revenuecat with auth',
          'revenuecat with settings_screen',
          'revenuecat with localization',
          'revenuecat',
        ],
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

    test(
        'renders the service, which type-checks with purchases_flutter in '
        'every app of the module', () async {
      for (final result in results) {
        if (!result.contractCase.requested.contains(RevenueCatModule.id)) {
          continue;
        }
        expect(
          [
            for (final file in result.app!.files.values)
              if (file.owner == const ModuleOrigin(RevenueCatModule.id))
                file.path,
          ],
          [serviceFile],
        );
        final app = DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems(
              {const ModuleOrigin(RevenueCatModule.id)},
            ),
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
    late RenderedApp app;
    late Map<String, Object?> run;

    setUpAll(() async {
      app = (await _resultOf(const [RevenueCatModule.id])).app!;
      final dartApp = DartApp.write(app);
      try {
        run = (await dartApp.run(_script))! as Map<String, Object?>;
      } finally {
        dartApp.delete();
      }
    });

    test(
        'reads the keys of .env through AppEnv, and has purchases_flutter in '
        'its pubspec', () {
      final service = app.files[serviceFile]!.text;
      final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;

      expect(
        service,
        allOf([
          contains('apple: AppEnv.revenuecatAppleKey,'),
          contains('google: AppEnv.revenuecatGoogleKey,'),
          contains('test: AppEnv.revenuecatTestKey,'),
          contains("const _entitlement = 'premium';"),
          for (final key in RevenueCatModule.keys) contains("'${key.name}'"),
        ]),
      );
      expect(
        (pubspec['dependencies'] as YamlMap)['purchases_flutter'],
        '^10.18.0',
      );
      expect(
        [
          for (final file in app.files.values)
            if (file.path.endsWith('.dart') &&
                file.text.contains('package:purchases_flutter/'))
              file.path,
        ],
        [serviceFile],
      );
    });

    test(
        'creates the service with the key that revenueCatKey chooses for the '
        'platform of the app, in a debug build only while kDebugMode is true: '
        'iOS compiles a profile build without DEBUG, and RevenueCat stops '
        'such a build that is configured with the key of the Test Store', () {
      final unit = parseString(content: app.files[serviceFile]!.text).unit;
      final factory = unit.declarations
          .whereType<FunctionDeclaration>()
          .singleWhere(
            (declaration) =>
                declaration.name.lexeme == 'createRevenueCatPurchasesService',
          );
      final call = _callsOf('revenueCatKey', factory).single;

      expect(
        {
          for (final argument
              in call.argumentList.arguments.whereType<NamedArgument>())
            argument.name.lexeme: argument.argumentExpression.toSource(),
        },
        {
          'platform': 'defaultTargetPlatform',
          'debug': 'kDebugMode',
          'apple': 'AppEnv.revenuecatAppleKey',
          'google': 'AppEnv.revenuecatGoogleKey',
          'test': 'AppEnv.revenuecatTestKey',
        },
      );
    });

    test(
        'takes the key of the Test Store only in a debug build, the key of '
        'the store of the platform otherwise, and no empty, secret or, in a '
        'release build, Test Store key', () {
      expect(run['keys'], {
        'debug with the test key': 'REVENUECAT_TEST_KEY=test_t',
        'release with the test key': 'REVENUECAT_APPLE_KEY=appl_a',
        'empty': 'none: REVENUECAT_GOOGLE_KEY has no value in this build. '
            'In .env, give it the public API key of the Play Store app in '
            'RevenueCat, or give REVENUECAT_TEST_KEY the public API key of the '
            'Test Store. Then build the app as the section "Values in .env" '
            'of its README says.',
        'secret': 'none: REVENUECAT_GOOGLE_KEY in .env is a secret key of '
            'RevenueCat, which never goes into an app: use the public API key '
            'of the Play Store app.',
        'test key of a store in release': 'none: REVENUECAT_GOOGLE_KEY in .env '
            'is a key of the Test Store, which RevenueCat refuses in a profile '
            'or release build: use the public API key of the Play Store app.',
      });
    });

    test(
        'calls nothing of RevenueCat without a key, and fails every call with '
        'notConfigured and the hint of the key', () {
      expect(run['without a key'], [
        'failed: notConfigured (No key.)',
        'failed: notConfigured (No key.)',
        'failed: notConfigured (No key.)',
      ]);
    });

    test(
        'configures RevenueCat when it is created, and calls nothing else '
        'before the configuration completed', () {
      expect(run['while configuring'], ['setupPurchases goog_tests']);
      expect(run['once configured'], [
        'setupPurchases goog_tests',
        'isAnonymous',
        'getCustomerInfo',
      ]);
    });

    test(
        'logs a user of the app in, logs out for the user of this device '
        'after a user of the app, and takes a logOut that RevenueCat fails '
        'for an anonymous user for done', () {
      expect(run['identify'], [
        'logIn user-a',
        '= null',
        'isAnonymous',
        'logOut',
        '= null',
        'isAnonymous',
        '= null',
      ]);
      expect(run['logOut of an anonymous user'], [
        'isAnonymous',
        'logOut',
        '= null',
      ]);
    });

    test(
        'gives the codes of RevenueCat the reasons of the role, and a code '
        'that is no number the reason unknown', () {
      expect(run['reasons'], {
        '20': 'pending',
        '10': 'network',
        '6': 'alreadyOwned',
        '3': 'notAllowed',
        '5': 'unavailable',
        '11': 'notConfigured',
        '2': 'storeProblem',
        '42': 'storeProblem',
        '22': 'unknown',
        '99': 'unknown',
        'error': 'unknown',
      });
    });

    test(
        'turns an error of another kind than of RevenueCat into the reason '
        'unknown, and a configuration that fails in any way into a service '
        'that is not configured, whose calls fail with notConfigured', () {
      expect(run['another error'], [
        'getCustomerInfo',
        'failed: unknown (Bad state: not a failure of RevenueCat)',
      ]);
      const withoutPlatformSide = 'failed: notConfigured (RevenueCat did '
          'not start with REVENUECAT_GOOGLE_KEY: the app has no platform side '
          'of purchases_flutter, as in a test without mocks of the method '
          'channel purchases_flutter (No implementation).)';
      expect(run['without a platform side'], [false, withoutPlatformSide]);
      const broken = 'failed: notConfigured (RevenueCat did not start with '
          'REVENUECAT_GOOGLE_KEY: Bad state: broken)';
      expect(run['configuration that fails otherwise'], [false, broken]);
    });

    test(
        'waits only a moment for offerings that RevenueCat does not give, '
        'with an access without a period then, and has the period once they '
        'come', () {
      expect(run['offerings that come late'], [
        'null',
        true,
        'BillingPeriod(1 year)',
      ]);
    });

    test(
        'completes a purchase that the user cancelled with null, and fails one '
        'that gives no premium access with notConfigured', () {
      expect(run['cancel by code'], [r'purchasePackage $rc_annual', '= null']);
      expect(run['cancel by details'], [
        r'purchasePackage $rc_annual',
        '= null',
      ]);
      const noPremium = 'failed: notConfigured (The user bought '
          'premium_annual, but RevenueCat gives no active entitlement premium '
          'for it: attach the product to the entitlement premium in '
          'RevenueCat, and a restore gives the access.)';
      expect(run['no premium'], [r'purchasePackage $rc_annual', noPremium]);
    });

    group('the section of the module in the README of the app', () {
      test('refers to the sections of the purchases and of the steps by hand',
          () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;

        expect(readme, contains('\n## $readmeHeading\n\n$readmeSection'));
        expect(readme, contains('\n## ${PurchasesRole.readmeHeading}\n'));
        expect(readme, contains('\n## ${EnvRole.readmeHeading}\n'));
        expect(
          readmeSection,
          allOf(
            contains('(see the section ${PurchasesRole.readmeHeading})'),
            contains('The section ${AppEntryRole.setupHeading} lists'),
          ),
        );
      });

      test(
          'tells the way to a first purchase in the Test Store, what a release '
          'needs, which key a build takes, that a secret key never goes '
          'there, and what the app does without a key', () {
        expect(
          readmeSection,
          allOf([
            contains('Test Store'),
            contains('Test valid purchase'),
            contains('the default offering, which the SDK calls the '
                'current offering'),
            contains('make that offering the default one'),
            contains('In-App Purchase key of App Store Connect'),
            contains('give it the type Non-consumable in RevenueCat'),
            contains('service account of Google Play'),
            contains('A profile or release build never takes it'),
            contains('leave `REVENUECAT_TEST_KEY` empty'),
            contains('`sk_`'),
            contains('the reason `notConfigured`'),
          ]),
        );
        expect(
          _codeOf(readmeSection),
          containsAll([
            serviceFile,
            'premium',
            EnvRole.dotEnvFile,
            for (final key in RevenueCatModule.keys) key.name,
            'appl_',
            'goog_',
            'test_',
            'appPurchases',
          ]),
        );
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the purchases of the guide, after what the '
          'role says', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);

        expect(
          [
            for (final (origin, heading, note) in notes)
              if (origin == const ModuleOrigin(RevenueCatModule.id) ||
                  origin == const RoleTemplateOrigin(purchasesRole))
                (origin, heading, note.isOfRole),
          ],
          contains(
            (
              const ModuleOrigin(RevenueCatModule.id),
              purchasesRole.description,
              false,
            ),
          ),
        );
        expect(agentNote, startsWith('With `purchases_flutter`:\n'));
        final guide = app.files[AppEntryRole.agentsFile]!.text;
        expect(guide, contains('\n${agentNote.trim()}\n'));
        expect(
          guide.indexOf(agentNote.trim()),
          greaterThan(guide.indexOf('\n## ${purchasesRole.description}\n')),
        );
      });

      test(
          'names the file of the module, the only one of the app that imports '
          'the package, and what that file declares and calls', () {
        final service = DartFileIndexer.index(
          serviceFile,
          app.files[serviceFile]!.text,
        );

        expect(
          _codeOf(agentNote),
          containsAll([
            serviceFile,
            'RevenueCatPurchasesService',
            'PurchasesService',
            'Purchases',
            'appPurchases',
            'premium',
            'Plan',
            'revenueCatKey()',
            EnvRole.dotEnvFile,
            for (final key in RevenueCatModule.keys) key.name,
            'kDebugMode',
            'sk_',
            'Purchases.configure()',
            'notConfigured',
            'Purchases.invalidateCustomerInfoCache()',
            'bootstrap()',
            'purchases_flutter',
            'setMockMethodCallHandler',
          ]),
        );
        for (final name in [
          'RevenueCatPurchasesService',
          'createRevenueCatPurchasesService',
          'revenueCatKey',
          'RevenueCatKey',
        ]) {
          expect(service.declaration(name), isNotNull, reason: name);
        }
        for (final call in ['Purchases.configure(', 'kDebugMode']) {
          expect(app.files[serviceFile]!.text, contains(call), reason: call);
        }
      });
    });

    test('has a README that leads to the page of the module', () {
      expect(
        File('README.md').readAsStringSync(),
        contains('(https://doc.saymyframe.com/modules/revenuecat)'),
      );
    });
  });
}
