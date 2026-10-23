@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_onboarding/smf_onboarding.dart';
import 'package:smf_paywall/bundles/paywall_bloc_bundle.dart';
import 'package:smf_paywall/bundles/paywall_bloc_setting_bundle.dart';
import 'package:smf_paywall/bundles/paywall_bundle.dart';
import 'package:smf_paywall/bundles/paywall_riverpod_bundle.dart';
import 'package:smf_paywall/bundles/paywall_riverpod_setting_bundle.dart';
import 'package:smf_paywall/bundles/paywall_setting_bundle.dart';
import 'package:smf_paywall/bundles/paywall_step_bundle.dart';
import 'package:smf_paywall/smf_paywall.dart';
import 'package:smf_paywall/src/agents.dart';
import 'package:smf_paywall/src/readme.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';

import 'support/providers.dart';

/// The modules of the tests: flutter_core, which creates the app,
/// go_router, which routes it and asks the guard of the module, the two
/// modules that manage state, purchases in memory, dart_define, which
/// provides the env role that the module requires, gen_l10n, which
/// provides the localization role, with the preferences that it requires,
/// the settings module, the onboarding module, and this module.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BlocModule(),
  RiverpodModule(),
  MemoryPurchasesModule(),
  DartDefineModule(),
  SharedPreferencesModule(),
  GenL10nModule(),
  SettingsModule(),
  OnboardingModule(),
  PaywallModule(),
];

/// The directory of the files of the module in the app.
const _folder = 'lib/features/paywall';

/// The files of the look and of the values of the state, which every app
/// with the module has.
const _views = {
  'PaywallView': '$_folder/paywall_view.dart',
  'SubscriptionView': '$_folder/subscription_view.dart',
};
const _look = [
  '$_folder/paywall_view.dart',
  '$_folder/subscription_view.dart',
  '$_folder/paywall_widgets.dart',
  '$_folder/paywall_card.dart',
  '$_folder/paywall_texts.dart',
  '$_folder/paywall_state.dart',
  '$_folder/paywall_links.dart',
  '$_folder/paywall_guards.dart',
];

/// The file of the row of the entry of the settings screen, which only an
/// app with a settings screen has.
const _settingRow = '$_folder/subscription_setting_row.dart';

/// The files of the screens, which each variant has at the same paths.
const _screens = {
  'PaywallScreen': '$_folder/paywall_screen.dart',
  'SubscriptionScreen': '$_folder/subscription_screen.dart',
};

/// The file of the entry of the settings screen, which each variant has at
/// the same path in an app with a settings screen.
const _setting = '$_folder/subscription_setting.dart';

/// The file of the functions of the step of the onboarding, which only an
/// app with an onboarding has.
const _step = '$_folder/paywall_step.dart';

/// The variants of the module, each with the id of its state manager, the
/// package that it imports, and the files of its state.
const List<({ModuleId id, String package, List<String> stateFiles})> _variants =
    [
  (
    id: PaywallModule.blocVariant,
    package: 'flutter_bloc',
    stateFiles: [
      '$_folder/paywall_composition.dart',
      '$_folder/paywall_cubit.dart',
      '$_folder/subscription_cubit.dart',
      '$_folder/premium_cubit.dart',
    ],
  ),
  (
    id: PaywallModule.riverpodVariant,
    package: 'flutter_riverpod',
    stateFiles: [
      '$_folder/purchases_provider.dart',
      '$_folder/paywall_notifier.dart',
    ],
  ),
];

/// The names of the texts of the module, in their order: those of the
/// paywall, with the names, the suffixes and the lengths of the closed
/// sets, the terms, the links, the messages and the failures, and those of
/// the screen of the subscription.
const _textNames = [
  'close',
  'premium',
  'benefitAll',
  'benefitNew',
  'benefitSupport',
  'bestValue',
  'planWeekly',
  'planMonthly',
  'planTwoMonths',
  'planThreeMonths',
  'planSixMonths',
  'planYearly',
  'planLifetime',
  'perWeek',
  'perMonth',
  'perTwoMonths',
  'perThreeMonths',
  'perSixMonths',
  'perYear',
  'once',
  'threeDays',
  'oneWeek',
  'twoWeeks',
  'oneMonth',
  'twoMonths',
  'threeMonths',
  'sixMonths',
  'oneYear',
  'free',
  'forLength',
  'then',
  'freeTrial',
  'introPrice',
  'startTrial',
  'subscribe',
  'buy',
  'termsApple',
  'termsGoogle',
  'termsTrial',
  'termsIntro',
  'termsLifetime',
  'restore',
  'terms',
  'privacy',
  'nothingToRestore',
  'pendingNotice',
  'plansUnavailable',
  'tryAgain',
  'failureNetwork',
  'failureOwned',
  'failureNotAllowed',
  'failureUnavailable',
  'failureStore',
  'failureNotSetUp',
  'failureUnknown',
  'subscriptionTitle',
  'subscriptionIntro',
  'unlocked',
  'planLabel',
  'renewsOn',
  'endsOn',
  'trialEndsOn',
  'lifetimeAccess',
  'manage',
  'manageHint',
];

/// The names of the texts of the entry of the settings screen.
const _settingTextNames = ['settingTitle', 'settingActive', 'settingInactive'];

/// The names of the texts of the step of the onboarding.
const _stepTextNames = ['stepTitle', 'stepText', 'stepAction', 'stepLater'];

/// The name of the case of the module with [variant] and the roles that it
/// uses: the localization role if [localized], the settings screen role if
/// [settings], and the onboarding screen role if [onboarding].
String _caseOf(
  ModuleId variant, {
  bool localized = false,
  bool settings = false,
  bool onboarding = false,
}) {
  final roles = [
    if (localized) 'localization',
    if (settings) 'settings_screen',
    if (onboarding) 'onboarding_screen',
  ];
  final uses = roles.isEmpty ? '' : ' with ${roles.join(', ')}';
  return 'paywall ($variant)$uses';
}

/// What the contract harness finds for the module with [variant] and the
/// modules [others], which has no errors and is rendered.
Future<ContractResult> _rendered(
  ModuleId variant, {
  List<ModuleId> others = const [],
}) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(
      'paywall with $variant, ${others.join(', ')}',
      requested: [PaywallModule.id, MemoryPurchasesModule.id, ...others],
      picks: {stateManagementRole: variant},
    ),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError('The app has errors: ${result.errors.join('\n')}');
  }
  return result;
}

/// The getter of the text [name] of the module in the texts of the app.
String _getterOf(String name) =>
    'paywall${name[0].toUpperCase()}${name.substring(1)}';

/// The routes and the guards of the app of [result], as the router role
/// gives them to every router.
RouterFacade _facadeOf(ContractResult result) =>
    routerRole.facadeOf(routerRole.hookInput(result.hook!));

/// The modules that provide [role] in the app of [result].
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

/// The index of the Dart file at [path] of [app].
DartFileIndex _indexOf(RenderedApp app, String path) =>
    DartFileIndexer.index(path, app.files[path]!.text);

/// The parsed file [path] of [app].
CompilationUnit _parsed(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// Whether [name], inline code of a text, is the path of a file of the
/// app, not that of a directory.
bool _isFile(String name) => name.startsWith('lib/') && name.endsWith('.dart');

/// Whether [origin] is the module, or its variant for a state manager.
bool _isOwn(ContributionOrigin? origin) =>
    origin is ModuleOrigin && origin.module == PaywallModule.id;

/// The paths of the files of [app] that the module owns.
List<String> _ownFilesOf(RenderedApp app) => [
      for (final file in app.files.values)
        if (_isOwn(file.owner)) file.path,
    ];

/// The calls of the methods and functions of [unit] that navigate or close
/// a page, each as `<file>: <call>` with what it is called on.
List<String> _navigationIn(String path, CompilationUnit unit) {
  final visitor = _Navigation();
  unit.accept(visitor);
  return [for (final call in visitor.calls) '$path: $call'];
}

final class _Navigation extends RecursiveAstVisitor<void> {
  static const _names = {
    'pop',
    'maybePop',
    'popUntil',
    'removeRoute',
    'go',
    'push',
    'pushReplacement',
    'replace',
    'pushNamed',
    'goNamed',
  };

  final List<String> calls = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_names.contains(node.methodName.name)) {
      calls.add('${node.target?.toSource() ?? ''}.${node.methodName.name}');
    }
    super.visitMethodInvocation(node);
  }
}

/// The arguments of the calls of `split` in a part of a file.
final class _SplitArguments extends RecursiveAstVisitor<void> {
  final List<Expression> arguments = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'split') {
      arguments.addAll(node.argumentList.arguments.whereType<Expression>());
    }
    super.visitMethodInvocation(node);
  }
}

/// The pattern that [expression] is: a string literal, or a call of the
/// constructor of `RegExp` with one.
Pattern _patternOf(Expression expression) => switch (expression) {
      StringLiteral(:final stringValue?) => stringValue,
      MethodInvocation(methodName: SimpleIdentifier(name: 'RegExp')) ||
      InstanceCreationExpression() =>
        RegExp(
          (_argumentsOf(expression).single as StringLiteral).stringValue!,
        ),
      _ => throw StateError('No pattern: ${expression.toSource()}'),
    };

/// The positional arguments of [call].
Iterable<Expression> _argumentsOf(Expression call) => switch (call) {
      MethodInvocation(:final argumentList) ||
      InstanceCreationExpression(:final argumentList) =>
        argumentList.arguments.whereType<Expression>(),
      _ => const [],
    };

void main() {
  const module = PaywallModule();

  group('PaywallModule', () {
    test(
        'is a feature that requires the router, the purchases, the values '
        'of .env and a state manager, uses the localization, the settings '
        'screen and the onboarding screen, and needs no DI container', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('paywall'));
      expect(descriptor.kind, ModuleKinds.feature);
      expect(descriptor.provides, isEmpty);
      // The links to the terms of use and the privacy policy, which the App
      // Store asks of a paywall, are values of .env.
      expect(descriptor.requires, {purchasesRole, envRole});
      expect(
        descriptor.effectiveRequires,
        {purchasesRole, envRole, routerRole, stateManagementRole},
      );
      // The paywall works without a settings screen and without an
      // onboarding: through code that navigates to a route that needs
      // premium access.
      expect(
        descriptor.effectiveUses,
        {localizationRole, settingsScreenRole, onboardingScreenRole},
      );
      expect(descriptor.dependsOn, isEmpty);
    });

    test(
        'has a variant for bloc and one for riverpod, by the ids of the '
        'modules that provide the state management', () {
      final variants = module.descriptor.variants!;

      expect(variants.role, stateManagementRole);
      expect(variants.byProvider.keys, [BlocModule.id, RiverpodModule.id]);
      expect(PaywallModule.blocVariant, BlocModule.id);
      expect(PaywallModule.riverpodVariant, RiverpodModule.id);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'declares the paywall at / of the module and the screen of the '
        'subscription at /subscription, a route of its own that alone asks '
        'for premium access; neither is a destination or a screen that '
        'starts the app', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      expect(data.role, routerRole);
      final [paywall, subscription] = data.value.routes;
      expect((paywall.path, paywall.name), ('/', 'paywall'));
      // Outside the flow of the guard, which is the paywall alone: a route
      // that asks for a condition is in no flow.
      expect(
        (subscription.path, subscription.name),
        ('/subscription', 'subscription'),
      );
      expect(
        {
          for (final route in [paywall, subscription])
            route.screen.className: route.screen.file,
        },
        _screens,
      );
      for (final route in [paywall, subscription]) {
        expect(route.children, isEmpty, reason: route.name);
        expect(route.params, isEmpty, reason: route.name);
        expect(route.destination, isNull, reason: route.name);
        expect(route.startCandidate, isFalse, reason: route.name);
      }
      expect(paywall.conditions, isEmpty);
      expect(subscription.conditions, [PurchasesRole.premium]);
    });

    test(
        'declares a guard of premium access, which shows the paywall, has '
        'the stage of what asks who the user is, and brings the user back', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      final guard = data.value.guards.single;
      expect(guard.name, PaywallModule.premiumGuard);
      expect(guard.name, 'hasPremium');
      expect(guard.condition, PurchasesRole.premium);
      expect(guard.redirectTo, data.value.routes.first.name);
      expect(guard.allows.name, 'paywallHasPremium');
      expect(
        guard.allows.import,
        const ImportRef.app('features/paywall/paywall_guards.dart'),
      );
      expect(guard.stage, GuardStage.identity);
      // The access ends without a change of the user.
      expect(guard.resumes, isTrue);
    });

    test(
        'has each of its texts in English and in Ukrainian, without '
        'parameters', () {
      expect(
        [for (final text in PaywallModule.texts.texts) text.name],
        _textNames,
      );
      expect(
        [for (final text in PaywallModule.settingTexts.texts) text.name],
        _settingTextNames,
      );
      expect(
        [for (final text in PaywallModule.stepTexts.texts) text.name],
        _stepTextNames,
      );
      for (final text in [
        ...PaywallModule.texts.texts,
        ...PaywallModule.settingTexts.texts,
        ...PaywallModule.stepTexts.texts,
      ]) {
        expect(text.problems(), isEmpty, reason: '$text');
        expect(text.languages, ['en', 'uk'], reason: '$text');
        expect(text.textIn('uk'), isNot(text.en), reason: '$text');
        // gen-l10n reads braces as placeholders.
        expect(text.en, isNot(contains('{')), reason: '$text');
      }
    });

    test(
        'has a step of the onboarding that offers premium access after the '
        'steps that ask for permissions, while the user has none, with a '
        'button that shows the paywall and one that goes on without it', () {
      const step = PaywallModule.step;

      expect(step.problems(), isEmpty);
      expect(step.name, PaywallModule.stepName);
      expect(step.name, 'offer');
      expect(step.stage, OnboardingStage.offer);
      expect(
        OnboardingStage.values.indexOf(step.stage),
        greaterThan(OnboardingStage.values.indexOf(OnboardingStage.permission)),
      );
      expect(step.icon.code, 'Icons.workspace_premium_outlined');
      expect(
        [for (final import in step.icon.imports) import.uri],
        ['package:flutter/material.dart'],
      );
      // Its texts are those that the module gives the localization role in
      // an app with an onboarding.
      expect(step.shownTexts, PaywallModule.stepTexts.texts);
      expect(step.later, isNotNull);
      expect(
        [
          for (final function in step.functions)
            (function.name, function.import),
        ],
        [
          (
            'showPaywall',
            const ImportRef.app('features/paywall/paywall_step.dart')
          ),
          (
            'paywallStepShows',
            const ImportRef.app('features/paywall/paywall_step.dart'),
          ),
        ],
      );
    });

    test(
        'names the addresses of the terms of use and of the privacy policy '
        'as its keys of .env', () {
      expect(
        [for (final key in PaywallModule.keys) key.name],
        ['PAYWALL_TERMS_URL', 'PAYWALL_PRIVACY_URL'],
      );
      expect(PaywallModule.keys, [
        PaywallModule.termsKey,
        PaywallModule.privacyKey,
      ]);
      for (final key in PaywallModule.keys) {
        expect(key.problems(), isEmpty, reason: key.name);
      }
    });

    test(
        'lists the step by hand in which the developer publishes the terms '
        'of use and the privacy policy and puts their links into .env', () {
      const step = PaywallModule.legalPagesStep;

      expect(step.id.wire, 'paywall.legal_pages');
      expect(
        step.title,
        'Publish your terms of use and privacy policy and put their links '
        'into .env',
      );
      expect(step.title.length, lessThanOrEqualTo(ManualStep.maxTitleLength));
    });

    test(
        'contributes the brick of the look with the cell of the app, the '
        'keys, the texts and the values of .env, url_launcher, its routes '
        'with the guard, its keys, the entry of the settings screen with its '
        'brick and texts, its texts, the step of the onboarding with its '
        'brick and texts, its step by hand, its section of the README and '
        'its notes for coding agents', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(16));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(paywallBundle));
      expect(brick.bundle.name, 'paywall');
      expect(
        [for (final file in brick.bundle.files) file.path]..sort(),
        [..._look]..sort(),
      );
      expect(brick.when, isEmpty);
      expect(brick.vars.keys, [
        'app_symbol',
        'app_number',
        'terms_key',
        'privacy_key',
        for (final name in _textNames) 'text_${SmfNames.snakeCaseOf(name)}',
        'env_paywall_terms_url',
        'env_paywall_privacy_url',
      ]);
      // The symbol and the number of the app of the context, contract_app.
      expect(brick.vars['app_symbol'], "'Ca'");
      expect(brick.vars['app_number'], 11);
      expect(brick.vars['terms_key'], 'PAYWALL_TERMS_URL');
      expect(brick.vars['privacy_key'], 'PAYWALL_PRIVACY_URL');
      // Each text is a text of the app with the localization role, and its
      // English text without it.
      expect(
        [
          for (final variable in brick.vars.values.whereType<RoleVar>())
            if (variable.role == localizationRole)
              ((variable.present as Fragment).code, variable.absent),
        ],
        [
          for (final text in PaywallModule.texts.texts)
            (
              'context.l10n.${_getterOf(text.name)}',
              SmfNames.dartString(text.en),
            ),
        ],
      );
      // Each value of .env is read through AppEnv.
      expect(
        [
          for (final variable in brick.vars.values.whereType<RoleVar>())
            if (variable.role == envRole)
              ((variable.present as Fragment).code, variable.absent),
        ],
        [
          ('AppEnv.paywallTermsUrl', 'null'),
          ('AppEnv.paywallPrivacyUrl', 'null'),
        ],
      );
      final launcher = contributions[1] as PubspecDependency;
      expect(
        (launcher.package, launcher.constraint, launcher.dev),
        ('url_launcher', '^6.3.2', false),
      );
      expect(contributions[2], isA<RoleData<RoutesData>>());
      expect(
        [
          for (final data in contributions.sublist(3, 5))
            ((data as RoleData<EnvData>).role, data.value),
        ],
        [
          (envRole, PaywallModule.termsKey),
          (envRole, PaywallModule.privacyKey),
        ],
      );
      final settingBrick = contributions[5] as BrickContribution;
      expect(settingBrick.bundle, same(paywallSettingBundle));
      expect(
        [for (final file in settingBrick.bundle.files) file.path],
        [_settingRow],
      );
      expect(settingBrick.when, {settingsScreenRole});
      expect(settingBrick.vars.keys, [
        for (final name in _settingTextNames)
          'text_${SmfNames.snakeCaseOf(name)}',
      ]);
      final texts = contributions[6] as RoleData<TextsData>;
      expect(texts.role, localizationRole);
      expect(texts.value, same(PaywallModule.texts));
      expect(texts.when, isEmpty);
      final settingTexts = contributions[7] as RoleData<TextsData>;
      expect(settingTexts.value, same(PaywallModule.settingTexts));
      expect(settingTexts.when, {settingsScreenRole});
      final entry = contributions[8] as RoleData<SettingsData>;
      expect(entry.role, settingsScreenRole);
      final widget = (entry.value as SettingsEntry).widget;
      expect(widget.name, 'SubscriptionSetting');
      expect((entry.value as SettingsEntry).file, _setting);
      final stepBrick = contributions[9] as BrickContribution;
      expect(stepBrick.bundle, same(paywallStepBundle));
      expect(stepBrick.bundle.name, 'paywall_step');
      expect([for (final file in stepBrick.bundle.files) file.path], [_step]);
      expect(stepBrick.vars, isEmpty);
      expect(stepBrick.when, {onboardingScreenRole});
      final step = contributions[10] as RoleData<OnboardingData>;
      expect(step.role, onboardingScreenRole);
      expect(step.value, same(PaywallModule.step));
      // The data applies only when the role is present.
      expect(step.when, isEmpty);
      final stepTexts = contributions[11] as RoleData<TextsData>;
      expect(stepTexts.role, localizationRole);
      expect(stepTexts.value, same(PaywallModule.stepTexts));
      expect(stepTexts.when, {onboardingScreenRole});
      expect(contributions[12], same(PaywallModule.legalPagesStep));
      final readme = contributions[13] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect((readme.entryKey, readme.entryValue), ('Paywall', readmeSection));
      final note = contributions[14] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, agentHeading);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
      final stepNote = contributions[15] as SocketContribution;
      expect(stepNote.socket, AppEntryRole.agentSections);
      expect(stepNote.entryKey, agentHeading);
      expect(stepNote.entryValue, AgentNote(stepAgentNote));
      expect(stepNote.when, {onboardingScreenRole});
    });

    test(
        'adds with each variant the brick of its state, the brick of its '
        'entry of the settings screen, the package of its state manager '
        'with the constraint of the provider, and its part of the note; the '
        'variant for bloc also puts the cubit with the access of the user '
        'around the root of the app', () {
      final variants = module.descriptor.variants!.byProvider;
      final expected = {
        PaywallModule.blocVariant: (
          bundle: paywallBlocBundle,
          setting: paywallBlocSettingBundle,
          files: [
            '$_folder/paywall_composition.dart',
            '$_folder/paywall_cubit.dart',
            '$_folder/subscription_cubit.dart',
            '$_folder/premium_cubit.dart',
            ..._screens.values,
          ],
          package: 'flutter_bloc',
          note: blocAgentNote,
        ),
        PaywallModule.riverpodVariant: (
          bundle: paywallRiverpodBundle,
          setting: paywallRiverpodSettingBundle,
          files: [
            '$_folder/purchases_provider.dart',
            '$_folder/paywall_notifier.dart',
            ..._screens.values,
          ],
          package: 'flutter_riverpod',
          note: riverpodAgentNote,
        ),
      };

      expect(variants.keys, expected.keys);
      for (final MapEntry(key: id, value: variant) in expected.entries) {
        final contributions = variants[id]!(ContractHarness.defaultContext);
        final bloc = id == PaywallModule.blocVariant;

        expect(contributions, hasLength(bloc ? 5 : 4), reason: '$id');
        final brick = contributions[0] as BrickContribution;
        expect(brick.bundle, same(variant.bundle), reason: '$id');
        expect(
          [for (final file in brick.bundle.files) file.path]..sort(),
          [...variant.files]..sort(),
          reason: '$id',
        );
        expect(brick.vars, isEmpty, reason: '$id');
        expect(brick.when, isEmpty, reason: '$id');
        final setting = contributions[1] as BrickContribution;
        expect(setting.bundle, same(variant.setting), reason: '$id');
        expect(
          [for (final file in setting.bundle.files) file.path],
          [_setting],
          reason: '$id',
        );
        expect(setting.when, {settingsScreenRole}, reason: '$id');
        final package = contributions[2] as PubspecDependency;
        expect(package.package, variant.package, reason: '$id');
        // The version is that of the module that provides the role.
        expect(package.constraint, 'any', reason: '$id');
        expect(package.source, PubspecSource.hosted);
        expect(package.dev, isFalse);
        if (bloc) {
          final wrapper = contributions[3] as SocketContribution;
          expect(wrapper.socket, AppEntryRole.rootWrappers);
          final fragment = wrapper.fragment!;
          expect(
            fragment.code,
            'BlocProvider(create: (_) => createPremiumCubit(), child: ',
          );
          expect(
            [for (final import in fragment.imports) import.uri],
            [
              'package:flutter_bloc/flutter_bloc.dart',
              'features/paywall/paywall_composition.dart',
            ],
          );
        }
        final note = contributions.last as SocketContribution;
        expect(note.socket, AppEntryRole.agentSections);
        expect(note.entryKey, agentHeading);
        expect(note.entryValue, AgentNote(variant.note), reason: '$id');
      }
    });
  });

  group('the contract harness', () {
    late ContractHarness harness;
    late List<ContractResult> results;

    setUpAll(() async {
      harness = ContractHarness(ModuleRegistry(_modules));
      results = await harness.checkAll();
    });

    test(
        'builds the app of the module with each state manager, with each '
        'subset of the localization, the settings screen and the onboarding '
        'screen, each with the router, the purchases and the values of .env '
        'that it requires', () {
      final own = [
        for (final result in results)
          if (result.contractCase.name.startsWith('paywall')) result,
      ];

      expect(own.map((result) => result.contractCase.name), [
        for (final (localized, settings, onboarding) in [
          (true, true, true),
          (true, true, false),
          (true, false, true),
          (false, true, true),
          (true, false, false),
          (false, true, false),
          (false, false, true),
          (false, false, false),
        ])
          for (final variant in [BlocModule.id, RiverpodModule.id])
            _caseOf(
              variant,
              localized: localized,
              settings: settings,
              onboarding: onboarding,
            ),
      ]);
      for (final result in own) {
        final name = result.contractCase.name;
        expect(
          [
            for (final role in <Role>[routerRole, purchasesRole, envRole])
              _providersOf(result, role),
          ],
          [
            {GoRouterModule.id},
            {MemoryPurchasesModule.id},
            {DartDefineModule.id},
          ],
          reason: name,
        );
        expect(
          _providersOf(result, stateManagementRole),
          {if (name.contains('bloc')) BlocModule.id else RiverpodModule.id},
          reason: name,
        );
        expect(
          _providersOf(result, localizationRole),
          name.contains('localization') ? {GenL10nModule.id} : isEmpty,
          reason: name,
        );
        expect(
          _providersOf(result, settingsScreenRole),
          name.contains('settings_screen') ? {SettingsModule.id} : isEmpty,
          reason: name,
        );
        expect(
          _providersOf(result, onboardingScreenRole),
          name.contains('onboarding_screen') ? {OnboardingModule.id} : isEmpty,
          reason: name,
        );
        expect(result.hook!.presentRoles, isNot(contains(diRole)));
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

    test(
        'finds no warning in an app of the module but that no route starts '
        'it, and with the settings screen that no main navigation leads to '
        'that screen', () {
      for (final result in results) {
        final name = result.contractCase.name;
        if (!name.startsWith('paywall')) continue;
        expect(
          [for (final warning in result.issues) warning.code],
          [
            RouterRole.noStartWarning,
            if (name.contains('settings_screen'))
              RouterRole.noMainNavigationWarning,
          ],
          reason: name,
        );
      }
    });

    test(
        'checks each module with the provider of each role it requires or '
        'uses', () async {
      expect(await harness.uncheckedProviders(), isEmpty);
    });
  });

  group('the app with the paywall', () {
    late Map<ModuleId, ContractResult> full;
    late Map<ModuleId, ContractResult> bare;

    setUpAll(() async {
      full = {
        for (final variant in _variants)
          variant.id: await _rendered(
            variant.id,
            others: const [
              GenL10nModule.id,
              SettingsModule.id,
              OnboardingModule.id,
            ],
          ),
      };
      bare = {
        for (final variant in _variants)
          variant.id: await _rendered(variant.id),
      };
    });

    test(
        'has the look and the state of the variant of the app, the entry of '
        'the settings screen only with a settings screen, and the step of '
        'the onboarding only with an onboarding', () {
      for (final variant in _variants) {
        expect(
          _ownFilesOf(full[variant.id]!.app!),
          unorderedEquals([
            ..._look,
            ..._screens.values,
            ...variant.stateFiles,
            _settingRow,
            _setting,
            _step,
          ]),
          reason: '${variant.id}',
        );
        expect(
          _ownFilesOf(bare[variant.id]!.app!),
          unorderedEquals([
            ..._look,
            ..._screens.values,
            ...variant.stateFiles,
          ]),
          reason: '${variant.id}',
        );
      }
    });

    test(
        'gives the router the paywall as the target of the guard of premium '
        'access, which stands for the condition of the screen of the '
        'subscription', () {
      final facade = _facadeOf(full[PaywallModule.blocVariant]!);
      final guard = facade.guardFor(PurchasesRole.premium)!;

      expect(guard.fullName, 'paywall.hasPremium');
      expect(guard.target.fullName, 'paywall.paywall');
      expect(guard.target.fullPath, '/paywall');
      expect(
        [for (final route in guard.flow) route.fullName],
        ['paywall.paywall'],
      );
      expect(
        [
          for (final route in facade.routesAsking(PurchasesRole.premium))
            route.fullName,
        ],
        ['paywall.subscription'],
      );
      final subscription = facade.routes.singleWhere(
        (route) => route.fullName == 'paywall.subscription',
      );
      expect(subscription.fullPath, '/paywall/subscription');
    });

    test(
        'gives the onboarding its step, after the steps of the stages before '
        'it, and the localization role the texts of the step, only in an app '
        'with an onboarding', () async {
      final app = full[PaywallModule.blocVariant]!;
      final steps = onboardingScreenRole.stepsIn(
        onboardingScreenRole.hookInput(app.hook!),
      );
      final own = [
        for (final placed in steps)
          if (_isOwn(placed.owner)) placed,
      ];
      expect(own, hasLength(1));
      expect(own.single.fullName, 'paywall.offer');
      expect(own.single.step, same(PaywallModule.step));
      // The step of an offer comes after every step of an earlier stage.
      expect(
        steps.skipWhile((placed) => placed != own.single).skip(1).where(
              (placed) => placed.step.stage.index < OnboardingStage.offer.index,
            ),
        isEmpty,
      );
      final input = localizationRole.hookInput(app.hook!);
      expect(
        [
          for (final text in localizationRole.textsIn(input))
            if (_isOwn(text.owner) && _stepTextNames.contains(text.text.name))
              text.text,
        ],
        PaywallModule.stepTexts.texts,
      );
      // Without an onboarding, the step, its file and its texts are not
      // there.
      final withoutOnboarding = await _rendered(
        PaywallModule.blocVariant,
        others: const [GenL10nModule.id, SettingsModule.id],
      );
      expect(
        withoutOnboarding.hook!.presentRoles,
        isNot(contains(onboardingScreenRole)),
      );
      expect(withoutOnboarding.app!.files.keys, isNot(contains(_step)));
      expect(
        [
          for (final text in localizationRole.textsIn(
            localizationRole.hookInput(withoutOnboarding.hook!),
          ))
            if (_isOwn(text.owner)) text.text.name,
        ],
        isNot(anyElement(isIn(_stepTextNames))),
      );
    });

    test(
        'gives the settings screen the entry of the subscription only in an '
        'app with one, and the localization role its texts, those of the '
        'entry only with a settings screen', () async {
      final app = full[PaywallModule.blocVariant]!;
      final input = settingsScreenRole.hookInput(app.hook!);
      expect(
        [
          for (final RoleData(:value, :origin) in input.data)
            if (value is SettingsEntry && _isOwn(origin)) value.widget.name,
        ],
        ['SubscriptionSetting'],
      );
      final texts = localizationRole.textsIn(
        localizationRole.hookInput(app.hook!),
      );
      final own = [
        for (final text in texts)
          if (_isOwn(text.owner)) text.text.name,
      ];
      expect(own, [..._textNames, ..._settingTextNames, ..._stepTextNames]);
      // Without a settings screen, the entry and its texts are not there.
      final withoutSettings = await _rendered(
        PaywallModule.blocVariant,
        others: const [GenL10nModule.id],
      );
      expect(
        [
          for (final text in localizationRole.textsIn(
            localizationRole.hookInput(withoutSettings.hook!),
          ))
            if (_isOwn(text.owner)) text.text.name,
        ],
        _textNames,
      );
      expect(
        withoutSettings.app!.files.keys,
        isNot(contains(_setting)),
      );
    });

    test('gives the env role its two keys', () {
      final keys = envRole.keysIn(
        envRole.hookInput(bare[PaywallModule.blocVariant]!.hook!),
      );

      expect(
        [for (final key in keys) (key.owner, key.key.name)],
        [
          (const ModuleOrigin(PaywallModule.id), 'PAYWALL_TERMS_URL'),
          (const ModuleOrigin(PaywallModule.id), 'PAYWALL_PRIVACY_URL'),
        ],
      );
    });

    test(
        'puts the cubit with the access of the user around the root of an '
        'app with bloc, and nothing around that of an app with riverpod', () {
      List<String> wrappersOf(ContractResult result) => [
            for (final collected in result.app!
                    .socketOrders[AppEntryRole.rootWrappers]?.contributions ??
                const <Collected>[])
              if (_isOwn(collected.origin))
                (collected.contribution as SocketContribution).fragment!.code,
          ];

      expect(wrappersOf(full[PaywallModule.blocVariant]!), [
        'BlocProvider(create: (_) => createPremiumCubit(), child: ',
      ]);
      expect(wrappersOf(full[PaywallModule.riverpodVariant]!), isEmpty);
    });

    test(
        'reads each text from the texts of the app with the localization '
        'role, and as its English text without it', () {
      final localized = full[PaywallModule.blocVariant]!.app!;
      final english = bare[PaywallModule.blocVariant]!.app!;
      const texts = '$_folder/paywall_texts.dart';

      expect(
        localized.files[texts]!.text,
        allOf(
          contains('context.l10n.paywallPlanYearly'),
          isNot(contains("'Yearly'")),
        ),
      );
      expect(
        english.files[texts]!.text,
        allOf(
          contains("'Yearly'"),
          isNot(contains('context.l10n')),
        ),
      );
      // The cell of the app.
      expect(
        localized.files['$_folder/paywall_card.dart']!.text,
        allOf(
          contains("const _appSymbol = 'Ca';"),
          contains('const _appNumber = 11;'),
          contains("const _appName = 'Contract App';"),
        ),
      );
    });

    test('lists its step by hand among those of the app', () {
      expect(
        [
          for (final step in full[PaywallModule.blocVariant]!.manualSteps)
            step.step.id.wire,
        ],
        contains('paywall.legal_pages'),
      );
    });

    test(
        'navigates from no file of the feature after a purchase or a '
        'restore: the paywall closes only with its close button, only the '
        'entry of the settings screen pushes the screen of the subscription, '
        'and only the step of the onboarding shows the paywall outside the '
        'router, which it closes itself once the user has premium access, '
        'since the router does not know that route', () {
      for (final variant in _variants) {
        final app = full[variant.id]!.app!;
        final calls = [
          for (final path in _ownFilesOf(app))
            ..._navigationIn(path, _parsed(app, path)),
        ];

        expect(
          calls,
          unorderedEquals([
            '$_folder/paywall_view.dart: Navigator.maybePop',
            '$_setting: context.nav.paywall.subscription().push',
            '$_step: navigator.pop',
            '$_step: navigator.removeRoute',
            '$_step: navigator.push',
          ]),
          reason: '${variant.id}',
        );
      }
    });

    test(
        'keeps the look free of any state manager, and has the screens and '
        'the entry at the same paths with each variant', () {
      for (final variant in _variants) {
        final app = full[variant.id]!.app!;
        for (final path in [..._look, _settingRow]) {
          expect(
            [
              for (final import in _indexOf(app, path).imports)
                if (import.uri.contains('bloc') ||
                    import.uri.contains('riverpod'))
                  import.uri,
            ],
            isEmpty,
            reason: '${variant.id}: $path',
          );
        }
        for (final MapEntry(key: name, value: path) in {
          ..._screens,
          ..._views,
          'SubscriptionSetting': _setting,
        }.entries) {
          expect(
            _indexOf(app, path).declaration(name)?.kind,
            DeclarationKind.classType,
            reason: '${variant.id}: $name',
          );
        }
      }
    });
    test(
        'keeps its words whole with PaywallWords, a name of its own, which '
        'breaks a text into words at every white space but the no-break '
        'spaces', () {
      for (final variant in _variants) {
        final app = full[variant.id]!.app!;
        const widgets = '$_folder/paywall_widgets.dart';
        // A name that no other feature has, so that an import of the
        // widgets of another feature into a file of the paywall is never
        // ambiguous.
        expect(
          _indexOf(app, widgets).declaration('PaywallWords')?.kind,
          DeclarationKind.classType,
          reason: '${variant.id}',
        );
        expect(
          [
            for (final path in _ownFilesOf(app))
              for (final declaration in _indexOf(app, path).declarations)
                if (declaration.name == 'WholeWords') '$path: WholeWords',
          ],
          isEmpty,
          reason: '${variant.id}',
        );
        // The words that it measures, with the pattern that it splits a
        // text on.
        final unit = _parsed(app, widgets);
        final words =
            unit.declarations.whereType<ClassDeclaration>().singleWhere(
                  (declaration) =>
                      declaration.namePart.typeName.lexeme == 'PaywallWords',
                );
        final splits = _SplitArguments();
        words.accept(splits);
        final argument = splits.arguments.single;
        final pattern = switch (argument) {
          SimpleIdentifier(:final name) => _patternOf(
              unit.declarations
                  .whereType<TopLevelVariableDeclaration>()
                  .expand((declaration) => declaration.variables.variables)
                  .singleWhere((variable) => variable.name.lexeme == name)
                  .initializer!,
            ),
          _ => _patternOf(argument),
        };
        List<String> wordsOf(String text) => text.split(pattern);
        expect(wordsOf('one two'), ['one', 'two'], reason: '${variant.id}');
        // With one line for each word that it measures, a word after a line
        // break or a tab would never be measured.
        expect(
          wordsOf('one\nnext\tlast  end'),
          ['one', 'next', 'last', 'end'],
          reason: '${variant.id}',
        );
        // A price stays one word, as it stays on one line.
        expect(
          wordsOf('then \$29.99\u00A0/\u00A0year'),
          ['then', '\$29.99\u00A0/\u00A0year'],
          reason: '${variant.id}',
        );
        expect(
          wordsOf('29,99\u202F€ 1\u2007000'),
          ['29,99\u202F€', '1\u2007000'],
          reason: '${variant.id}',
        );
      }
    });
  });

  group('the note of the module for coding agents', () {
    late Map<ModuleId, ContractResult> results;
    late ContractResult withoutOnboarding;

    setUpAll(() async {
      results = {
        for (final variant in _variants)
          variant.id: await _rendered(
            variant.id,
            others: const [
              GenL10nModule.id,
              SettingsModule.id,
              OnboardingModule.id,
            ],
          ),
      };
      withoutOnboarding = await _rendered(
        PaywallModule.blocVariant,
        others: const [GenL10nModule.id, SettingsModule.id],
      );
    });

    /// The notes of the module in the guide of [app], each with its heading.
    List<(String, AgentNote)> notesOf(RenderedApp app) => [
          for (final (origin, heading, note)
              in app.entriesOf(AppEntryRole.agentSections))
            if (_isOwn(origin)) (heading, note),
        ];

    test(
        'is a section of its own in the guide of the app, with what the '
        'variant of the app adds after it, and what the step of the '
        'onboarding adds in an app with an onboarding', () {
      const added = {
        PaywallModule.blocVariant: blocAgentNote,
        PaywallModule.riverpodVariant: riverpodAgentNote,
      };

      expect(agentHeading, 'Paywall');
      for (final variant in _variants) {
        expect(
          notesOf(results[variant.id]!.app!),
          [
            (agentHeading, AgentNote(agentNote)),
            (agentHeading, AgentNote(stepAgentNote)),
            (agentHeading, AgentNote(added[variant.id]!)),
          ],
          reason: '${variant.id}',
        );
      }
      expect(notesOf(withoutOnboarding.app!), [
        (agentHeading, AgentNote(agentNote)),
        (agentHeading, AgentNote(blocAgentNote)),
      ]);
    });

    test(
        'names in the part of the step of the onboarding its name, its '
        'functions, the screen that it shows and its texts, as the app with '
        'an onboarding has them', () {
      final result = results[PaywallModule.blocVariant]!;
      final app = result.app!;
      final code = _codeOf(stepAgentNote);
      final placed = onboardingScreenRole
          .stepsIn(onboardingScreenRole.hookInput(result.hook!))
          .singleWhere((placed) => _isOwn(placed.owner));

      expect(
        code,
        containsAll([
          placed.fullName,
          '${PaywallModule.step.showIf!.name}()',
          '${PaywallModule.step.run.name}()',
          'PaywallScreen',
          '/paywall',
          _step,
          ..._stepTextNames,
        ]),
      );
      final declared = {
        for (final declaration in _indexOf(app, _step).declarations)
          declaration.name,
      };
      expect(
        declared,
        containsAll([
          PaywallModule.step.showIf!.name,
          PaywallModule.step.run.name,
        ]),
      );
      for (final path in code.where(_isFile)) {
        expect(app.files.keys, contains(path), reason: path);
      }
    });

    test(
        'names the routes, the guard, the files and the declarations of the '
        'module as the app has them', () {
      final result = results[PaywallModule.blocVariant]!;
      final app = result.app!;
      final facade = _facadeOf(result);
      final code = _codeOf(agentNote);
      final guard = facade.guardFor(PurchasesRole.premium)!;

      expect(
        code,
        containsAll([
          guard.fullName,
          guard.target.fullName,
          guard.target.fullPath,
          'paywall.subscription',
          '/paywall/subscription',
          RouterRole.routeGuards,
          'PurchasesRole.premium',
          'appPurchases.hasPremium',
          'context.nav.paywall.subscription().push<void>()',
          PaywallModule.termsKey.name,
          PaywallModule.privacyKey.name,
          EnvRole.dotEnvFile,
        ]),
      );
      // Each file that the note names is a file of the app, and each name
      // of code that it names is declared there.
      final files = {for (final path in app.files.keys) path};
      for (final path in code.where(_isFile)) {
        expect(files, contains(path), reason: path);
      }
      final declared = {
        for (final path in _ownFilesOf(app))
          for (final declaration in _indexOf(app, path).declarations)
            declaration.name,
      };
      expect(
        declared,
        containsAll([
          'PaywallScreen',
          'SubscriptionScreen',
          'PaywallView',
          'SubscriptionView',
          'PaywallState',
          'PaywallMessage',
          'paywallHasPremium',
          'failureTextOf',
        ]),
      );
      for (final name in [
        'PaywallScreen',
        'SubscriptionScreen',
        'PaywallView',
        'SubscriptionView',
        'PaywallState',
        'PaywallMessage',
        'paywallHasPremium()',
        'failureTextOf()',
        'benefitAll',
        'benefitNew',
        'benefitSupport',
      ]) {
        expect(code, contains(name), reason: name);
      }
      expect(
        [for (final text in PaywallModule.texts.texts) text.name],
        containsAll(['benefitAll', 'benefitNew', 'benefitSupport']),
      );
    });

    test(
        'names in the part of each variant the state and what gives it the '
        'purchases of the app, as the app of that variant declares them', () {
      for (final (variant, note, names) in [
        (
          PaywallModule.blocVariant,
          blocAgentNote,
          ['PaywallCubit', 'SubscriptionCubit', 'PremiumCubit'],
        ),
        (
          PaywallModule.riverpodVariant,
          riverpodAgentNote,
          [
            'paywallProvider',
            'appPurchasesProvider',
            'paywallLinkOpenerProvider',
            'premiumProvider',
          ],
        ),
      ]) {
        final app = results[variant]!.app!;
        final declared = {
          for (final path in _ownFilesOf(app))
            for (final declaration in _indexOf(app, path).declarations)
              declaration.name,
        };
        final code = _codeOf(note);
        for (final name in names) {
          expect(code, contains(name), reason: '$variant: $name');
          expect(declared, contains(name), reason: '$variant: $name');
        }
        for (final path in code.where(_isFile)) {
          expect(app.files.keys, contains(path), reason: '$variant: $path');
        }
      }
    });
  });

  group('the section of the module in the README of the app', () {
    test(
        'tells the routes, the guard, the keys of .env, the step of the '
        'onboarding and the sections of the roles that it refers to, and '
        'names only files that every app with the module has', () async {
      final code = _codeOf(readmeSection);
      expect(
        code,
        containsAll([
          '/paywall',
          '/paywall/subscription',
          'paywall.hasPremium',
          'PurchasesRole.premium',
          RouterRole.routeGuards,
          'context.nav.paywall.subscription().push<void>()',
          PaywallModule.termsKey.name,
          PaywallModule.privacyKey.name,
          EnvRole.dotEnvFile,
          'lib/features/paywall/paywall_texts.dart',
          'benefitAll',
        ]),
      );
      // The section is the same in every app, with an onboarding and a
      // settings screen and without them, so it names no file that only
      // some apps have, such as the file of the step of the onboarding.
      for (final others in [
        const [GenL10nModule.id, SettingsModule.id, OnboardingModule.id],
        const <ModuleId>[],
      ]) {
        final result = await _rendered(
          PaywallModule.blocVariant,
          others: others,
        );
        final readme = result.app!.files['README.md']!.text;
        expect(readme, contains('## $readmeHeading\n'), reason: '$others');
        expect(readme, contains(readmeSection.trim()), reason: '$others');
        for (final path in code.where(_isFile)) {
          expect(
            result.app!.files.keys,
            contains(path),
            reason: '$path, in the app with $others',
          );
        }
        for (final heading in [
          PurchasesRole.readmeHeading,
          EnvRole.readmeHeading,
        ]) {
          expect(readme, contains('## $heading\n'), reason: heading);
          expect(readmeSection, contains('section $heading'), reason: heading);
        }
      }
    });
  });

  group('the documentation of the package', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test(
        'shows in its example a command that generates an app with the '
        'module, and parts of its files', () async {
      final example = read('example/README.md');
      const command = 'smf create my_app -m paywall,bloc,revenuecat';

      expect(example, contains('$command --no-input'));
      expect(read('README.md'), contains('$command\n'));
      final app = (await _rendered(
        PaywallModule.blocVariant,
        others: const [SettingsModule.id],
      ))
          .app!;
      // Without the blocks of code, whose backticks are no inline code.
      final code = _codeOf(
        example.replaceAll(RegExp(r'```[\s\S]*?```'), ''),
      );
      expect(
        code,
        containsAll(['PAYWALL_TERMS_URL', 'PAYWALL_PRIVACY_URL', '.env']),
      );
      expect(
        app.files[_setting]!.text,
        contains('context.nav.paywall.subscription().push<void>()'),
      );
      expect(
        app.files['$_folder/premium_cubit.dart']!.text,
        contains('class PremiumCubit extends Cubit<AppAccess>'),
      );
      expect(example, contains('context.watch<PremiumCubit>().state'));
    });
  });
}
