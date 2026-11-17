@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_remote_config/smf_firebase_remote_config.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_in_app_review/smf_in_app_review.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:smf_update_required/bundles/update_required_bundle.dart';
import 'package:smf_update_required/smf_update_required.dart';
import 'package:smf_update_required/src/agents.dart';
import 'package:smf_update_required/src/readme.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: flutter_core, which creates the app, go_router,
/// which routes it and asks the guard of the module, the providers of the
/// two roles that the module requires, remote config, with the module that
/// sets up Firebase that it depends on, and the reviews, with the
/// preferences and the values of .env that the review role requires,
/// gen_l10n, which provides the localization role, and this module.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  SharedPreferencesModule(),
  DartDefineModule(),
  FirebaseCoreModule(),
  FirebaseRemoteConfigModule(),
  InAppReviewModule(),
  GenL10nModule(),
  UpdateRequiredModule(),
];

/// The paths of the files of the module in the app.
const _screen = '$folder/update_required_screen.dart';
const _status = '$folder/update_status.dart';
const _compare = '$folder/version_compare.dart';

/// The owner of the files of the module.
const _module = ModuleOrigin(UpdateRequiredModule.id);

/// The getters of the texts of the module in an app with the localization
/// role, each with its English text, in the order of the texts.
const _texts = {
  'updateRequiredTitle': 'Update required',
  'updateRequiredBody': 'This version of the app is no longer supported. '
      'Update the app to keep using it.',
  'updateRequiredUpdate': 'Update',
  'updateRequiredLater': 'Not now',
  'updateRequiredStoreFailed': "Couldn't open the store.",
};

/// The Ukrainian texts of the module, by the same getters.
const _ukrainian = {
  'updateRequiredTitle': 'Потрібне оновлення',
  'updateRequiredBody': 'Ця версія застосунку більше не підтримується. '
      'Оновіть застосунок, щоб користуватися ним далі.',
  'updateRequiredUpdate': 'Оновити',
  'updateRequiredLater': 'Не зараз',
  'updateRequiredStoreFailed': 'Не вдалося відкрити магазин.',
};

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _rendered(List<ModuleId> modules) async {
  final result = await ContractHarness(
    ModuleRegistry(_modules),
  ).check(ContractCase(modules.join(', '), requested: modules));
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The parsed file [path] of [app].
CompilationUnit _parsed(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

/// The class [name] of [unit].
ClassDeclaration _classOf(CompilationUnit unit, String name) => unit
    .declarations
    .whereType<ClassDeclaration>()
    .singleWhere((declaration) => declaration.namePart.typeName.lexeme == name);

/// The getters of the texts of the app that [unit] reads, as
/// `context.l10n.<getter>`, in the order of the code.
List<String> _textsReadIn(CompilationUnit unit) {
  final visitor = _TextReads();
  unit.accept(visitor);
  return visitor.getters;
}

final class _TextReads extends RecursiveAstVisitor<void> {
  final List<String> getters = [];

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.target?.toSource() == 'context.l10n') {
      getters.add(node.propertyName.name);
    }
    super.visitPropertyAccess(node);
  }
}

/// The values of the string literals of [unit], in the order of the code.
List<String> _stringsIn(CompilationUnit unit) {
  final visitor = _Strings();
  unit.accept(visitor);
  return visitor.values;
}

final class _Strings extends RecursiveAstVisitor<void> {
  final List<String> values = [];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) =>
      values.add(node.value);
}

/// The guards of the routes of the app of [result], as the router role
/// gives them to every router, in the order the app asks them.
List<FacadeGuard> _guardsOf(ContractResult result) =>
    routerRole.facadeOf(routerRole.hookInput(result.hook!)).guards;

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

/// The contributions to [socket] in the app of [result], those of the
/// render hooks of the roles included, in the order they were rendered,
/// each as its contributor and its code.
List<String> _contributionsTo(ContractResult result, SocketRef socket) => [
      for (final collected in result.app!.socketOrders[socket]?.contributions ??
          const <Collected>[])
        _described(collected),
    ];

/// The contribution [collected] to a socket as its contributor and its code.
String _described(Collected collected) {
  final contribution = collected.contribution as SocketContribution;
  return '${collected.origin}: ${contribution.fragment!.code}';
}

/// The index of the Dart file at [path] of [app].
DartFileIndex _indexOf(RenderedApp app, String path) =>
    DartFileIndexer.index(path, app.files[path]!.text);

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// Whether [code] is the path of a file of an app.
bool _isFile(String code) =>
    code.startsWith('lib/') && code.endsWith('.dart') && !code.contains(' ');

void main() {
  const module = UpdateRequiredModule();

  group('UpdateRequiredModule', () {
    test(
        'is a feature without variants, which requires remote config and the '
        'reviews and the router, as a feature does, and uses the '
        'localization', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('update_required'));
      expect(descriptor.kind, ModuleKinds.feature);
      expect(descriptor.provides, isEmpty);
      expect(descriptor.requires, {remoteConfigRole, reviewRole});
      // The kind makes a feature require the router.
      expect(
        descriptor.effectiveRequires,
        {remoteConfigRole, reviewRole, routerRole},
      );
      expect(descriptor.effectiveUses, {localizationRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.variants, isNull);
      expect(descriptor.feeds, isEmpty);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'declares one route: the screen at / of the module, which is no '
        'destination and on which the app does not start', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      expect(data.role, routerRole);
      final route = data.value.routes.single;
      expect(route.path, '/');
      expect(route.name, 'updateRequired');
      expect(route.name, UpdateRequiredModule.route);
      expect(route.screen.className, 'UpdateRequiredScreen');
      expect(route.screen.file, _screen);
      expect(route.params, isEmpty);
      expect(route.children, isEmpty);
      expect(route.conditions, isEmpty);
      expect(route.destination, isNull);
      expect(route.startCandidate, isFalse);
    });

    test(
        'declares the gate supported, which shows its route while the '
        'function of the status says that the version may not run, needs to '
        'know nothing of the user, and brings the user back', () {
      final data = [
        for (final contribution
            in module.contribute(ContractHarness.defaultContext))
          if (contribution is RoleData<RoutesData>) contribution,
      ].single;

      final guard = data.value.guards.single;
      expect(guard.name, 'supported');
      expect(guard.name, UpdateRequiredModule.guard);
      expect(guard.redirectTo, data.value.routes.single.name);
      expect(guard.allows.name, 'versionSupported');
      expect(
        guard.allows.import,
        const ImportRef.app('features/update_required/update_status.dart'),
      );
      // A gate over the whole app, asked before a guard that asks who the
      // user is, which brings the user back to the screen that it kept the
      // user from once the version may run.
      expect(guard.condition, isNull);
      expect(guard.stage, GuardStage.welcome);
      expect(guard.resumes, isTrue);
    });

    test(
        'gives remote config the lowest version that may run, a text whose '
        'default is none', () {
      const key = UpdateRequiredModule.minimumVersion;

      expect(key.name, 'update_required_minimum_version');
      expect(key.type, RemoteParameterType.text);
      expect(key.defaultValue, '');
      expect(key.getter, 'updateRequiredMinimumVersion');
      expect(
        key.description,
        'The lowest version of the app that may run, such as 1.4.0; empty for '
        'none',
      );
      expect(key.problems(), isEmpty);
    });

    test('has each of its texts in English and in Ukrainian', () {
      final texts = UpdateRequiredModule.texts.texts;

      expect(texts, hasLength(_texts.length));
      for (final text in texts) {
        expect(text.problems(), isEmpty, reason: '$text');
        expect(text.languages, ['en', 'uk'], reason: '$text');
      }
      expect([for (final text in texts) text.en], _texts.values);
      expect([for (final text in texts) text.textIn('uk')], _ukrainian.values);
    });

    test(
        'contributes its brick with the cell of the app, the key of the App '
        'Store ID and the texts, package_info_plus, its route with the gate, '
        'its parameter of remote config, the start of its status, its texts, '
        'its section of the README and its note for coding agents, and '
        'nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(8));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(updateRequiredBundle));
      expect(brick.bundle.name, 'update_required');
      expect(
        [for (final file in brick.bundle.files) file.path]..sort(),
        [_screen, _status, _compare],
      );
      expect(brick.when, isEmpty);
      expect(brick.vars.keys, [
        'app_symbol',
        'app_number',
        'app_store_id_key',
        'text_title',
        'text_body',
        'text_update',
        'text_later',
        'text_store_failed',
      ]);
      // The cell of the app of the context, contract_app, and the key of the
      // review role.
      expect(brick.vars['app_symbol'], "'Ca'");
      expect(brick.vars['app_number'], 11);
      expect(brick.vars['app_store_id_key'], 'REVIEW_APP_STORE_ID');
      // Each text is a text of the app with the localization role, and its
      // English text without it.
      expect(
        [
          for (final variable in brick.vars.values.whereType<RoleVar>())
            (
              variable.role,
              (variable.present as Fragment).code,
              variable.absent,
            ),
        ],
        [
          for (final MapEntry(key: getter, value: english) in _texts.entries)
            (
              localizationRole,
              'context.l10n.$getter',
              SmfNames.dartString(english),
            ),
        ],
      );
      final package = contributions[1] as PubspecDependency;
      expect(package.package, 'package_info_plus');
      expect(package.constraint, '^10.2.0');
      expect(package.dev, isFalse);
      expect(contributions[2], isA<RoleData<RoutesData>>());
      final key = contributions[3] as RoleData<RemoteConfigData>;
      expect(key.role, remoteConfigRole);
      expect(key.value, same(UpdateRequiredModule.minimumVersion));
      expect(key.when, isEmpty);
      final start = contributions[4] as SocketContribution;
      expect(start.socket, AppEntryRole.bootstrapLate);
      expect(start.fragment!.code, 'await updateStatus.start();');
      expect(
        start.fragment!.imports,
        [const ImportRef.app('features/update_required/update_status.dart')],
      );
      expect(start.when, isEmpty);
      final texts = contributions[5] as RoleData<TextsData>;
      expect(texts.role, localizationRole);
      expect(texts.value, same(UpdateRequiredModule.texts));
      final readme = contributions[6] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, readmeHeading);
      expect(readme.entryValue, readmeSection);
      final note = contributions[7] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, agentHeading);
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
        'builds the app of the module with the localization and without, '
        'each with the router, remote config and the reviews that it '
        'requires', () {
      final own = [
        for (final result in results)
          if (result.contractCase.name.startsWith('update_required')) result,
      ];

      expect(
        own.map((result) => result.contractCase.name),
        ['update_required with localization', 'update_required'],
      );
      for (final result in own) {
        expect(
          [
            for (final role in <Role>[
              routerRole,
              remoteConfigRole,
              reviewRole,
              localizationRole,
            ])
              _providersOf(result, role),
          ],
          [
            {GoRouterModule.id},
            {FirebaseRemoteConfigModule.id},
            {InAppReviewModule.id},
            if (result.contractCase.name == 'update_required')
              isEmpty
            else
              {GenL10nModule.id},
          ],
          reason: '${result.contractCase}',
        );
      }
    });

    test(
        'finds no errors in any app, rendered code included, and warns of '
        'nothing but the fallback screen on which an app of the module '
        'alone starts', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
        if (result.contractCase.name.startsWith('update_required')) {
          expect(
            result.warnings.map((issue) => issue.code),
            [RouterRole.noStartWarning],
            reason: '${result.contractCase}',
          );
        }
      }
    });

    test(
        'checks the module with the provider of each role it requires or '
        'uses', () async {
      expect(
        await ContractHarness(ModuleRegistry(_modules)).uncheckedProviders(),
        isEmpty,
      );
    });
  });

  group('the app with the screen', () {
    late ContractResult result;
    late RenderedApp app;

    setUpAll(() async {
      result = await _rendered(const [UpdateRequiredModule.id]);
      app = result.app!;
    });

    test(
        'gets the only providers of the roles that it requires, and the '
        'modules that those need', () {
      expect(
        {
          for (final module in result.resolution!.modules)
            '${module.id}': '${module.reason}',
        },
        containsPair('update_required', 'requested'),
      );
      expect(
        {for (final module in result.resolution!.modules) module.id},
        {
          UpdateRequiredModule.id,
          FlutterCoreModule.id,
          GoRouterModule.id,
          FirebaseRemoteConfigModule.id,
          FirebaseCoreModule.id,
          InAppReviewModule.id,
          SharedPreferencesModule.id,
          DartDefineModule.id,
        },
      );
    });

    test('has the three files of the module, which it owns', () {
      for (final path in [_compare, _status, _screen]) {
        expect(app.files[path]?.owner, _module, reason: path);
      }
      expect(
        [
          for (final MapEntry(key: path, value: file) in app.files.entries)
            if (file.owner == _module) path,
        ]..sort(),
        [_screen, _status, _compare],
      );
    });

    test(
        'keeps the user on the screen with one gate, whose target and whole '
        'flow is its route', () {
      final guard = _guardsOf(result).single;

      expect(guard.fullName, 'update_required.supported');
      expect(guard.feature.module, UpdateRequiredModule.id);
      expect(guard.target.fullName, 'update_required.updateRequired');
      expect(guard.target.fullPath, '/update_required');
      expect(guard.target.hasRequiredParams, isFalse);
      expect(guard.flow, [guard.target]);
      expect(guard.isGate, isTrue);
    });

    test(
        'gives remote config its parameter, which the values of the app '
        'read with its getter', () {
      final keys = remoteConfigRole.keysIn(
        remoteConfigRole.hookInput(result.hook!),
      );

      expect(
        [for (final key in keys) (key.owner, key.key)],
        [(_module, UpdateRequiredModule.minimumVersion)],
      );
      expect(
        [
          for (final access in _indexOf(app, _status).memberAccesses)
            access.name,
        ],
        contains(UpdateRequiredModule.minimumVersion.getter),
      );
    });

    test(
        'starts its status in the last phase of the start-up, once the '
        'values of remote config and the reviews are there', () {
      expect(
        _contributionsTo(result, AppEntryRole.bootstrapPlatform),
        contains('role:remote_config: await initRemoteConfig();'),
      );
      expect(
        _contributionsTo(result, AppEntryRole.bootstrapLate),
        containsAll([
          'update_required: await updateStatus.start();',
          'role:review: await initReview();',
        ]),
      );
    });

    test(
        'adds package_info_plus to the app, with the constraint of the '
        'module, which the provider of the reviews takes as it is', () {
      final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;

      expect(
        (pubspec['dependencies'] as YamlMap)['package_info_plus'],
        '^10.2.0',
      );
    });

    test(
        'reads the version of the app with package_info_plus, the values of '
        'remote config and the store page of the reviews, and nothing of the '
        'services of their providers', () {
      final index = _indexOf(app, _status);

      expect(
        index.imports.map((directive) => directive.uri),
        unorderedEquals([
          'dart:async',
          'package:flutter/foundation.dart',
          'package:package_info_plus/package_info_plus.dart',
          '../../core/remote_config/app_remote_config.dart',
          '../../core/review/app_review.dart',
          'version_compare.dart',
        ]),
      );
      expect(
        index.imports.map((directive) => directive.uri),
        isNot(contains(contains(RemoteConfigRole.serviceFile.split('/').last))),
      );
      expect(
        index.imports.map((directive) => directive.uri),
        isNot(contains(contains(ReviewRole.serviceFile.split('/').last))),
      );
      // The hint for a developer whose iOS app has no App Store ID names the
      // key of the review role.
      expect(app.files[_status]!.text, contains('REVIEW_APP_STORE_ID of'));
    });

    test(
        'shows the cell of the app and the English texts in an app without '
        'the localization role', () {
      final unit = _parsed(app, _screen);
      final strings = _stringsIn(unit);

      expect(_textsReadIn(unit), isEmpty);
      expect(strings, containsAll(_texts.values));
      // The symbol of the app, contract_app.
      expect(strings, contains('Ca'));
      expect(app.files[_screen]!.text, contains('const _appNumber = 11;'));
      expect(_classOf(unit, 'UpdateRequiredScreen'), isNotNull);
    });

    test(
        'has the section of the module in the README, which names only '
        'files that the app has', () {
      final readme = app.files['README.md']!.text;

      expect(readme, contains('## $readmeHeading\n'));
      expect(readme, contains(readmeSection.trim()));
      for (final heading in [
        RemoteConfigRole.readmeHeading,
        ReviewRole.readmeHeading,
      ]) {
        expect(readme, contains('## $heading\n'), reason: heading);
        expect(readmeSection, contains('section $heading'), reason: heading);
      }
      final code = _codeOf(readmeSection);
      expect(
        code,
        containsAll([
          UpdateRequiredModule.minimumVersion.name,
          'update_required.supported',
          RouterRole.routeGuards,
          ReviewRole.appStoreIdKey.name,
          EnvRole.dotEnvFile,
          'updateStatus',
          'context.l10n',
        ]),
      );
      for (final path in code.where(_isFile)) {
        expect(app.files.keys, contains(path), reason: path);
      }
      // A feature knows the roles and not their providers.
      expect(readmeSection.toLowerCase(), isNot(contains('firebase')));
    });

    test(
        'has the note of the module, a section of its own in the guide, which '
        'names the guard, the route, the files and the code of the module as '
        'the app has them', () {
      final notes = [
        for (final (origin, heading, note)
            in app.entriesOf(AppEntryRole.agentSections))
          if (origin == _module) (heading, note),
      ];
      expect(notes, [(agentHeading, AgentNote(agentNote))]);
      expect(agentHeading, 'Update required');

      final guard = _guardsOf(result).single;
      final code = _codeOf(agentNote);
      expect(
        code,
        containsAll([
          guard.fullName,
          guard.target.fullName,
          guard.target.fullPath,
          RouterRole.routeGuards,
          UpdateRequiredModule.minimumVersion.name,
          UpdateRequiredModule.minimumVersion.getter,
          'UpdateRequiredScreen',
          'updateStatus',
          'versionBelow()',
          'updateStatus.openStore()',
          'updateStatus.continueForNow()',
          'updateStatus.start()',
          'appReview.hasStorePage',
          'appReview.openStorePage()',
          'appRemoteConfig.start()',
          'appReview.start()',
        ]),
      );
      for (final path in code.where(_isFile)) {
        expect(app.files.keys, contains(path), reason: path);
      }
      final declared = {
        for (final path in [_screen, _status, _compare])
          for (final declaration in _indexOf(app, path).declarations)
            declaration.name,
      };
      expect(
        declared,
        containsAll([
          'UpdateRequiredScreen',
          'updateStatus',
          'UpdateStatus',
          'versionSupported',
          'versionBelow',
          'versionNumbers',
          'StoreVisit',
        ]),
      );
      expect(agentNote.toLowerCase(), isNot(contains('firebase')));
    });
  });

  group('in an app with the localization role', () {
    late ContractResult result;
    late RenderedApp app;

    setUpAll(() async {
      result = await _rendered(
        const [UpdateRequiredModule.id, GenL10nModule.id],
      );
      app = result.app!;
    });

    test(
        'gives the role its texts, which the screen reads from the texts of '
        'the app, in English and in Ukrainian', () {
      final input = localizationRole.hookInput(result.hook!);

      expect(localizationRole.localesIn(input), ['en', 'uk']);
      final unit = _parsed(app, _screen);
      expect(_textsReadIn(unit), [
        'updateRequiredTitle',
        'updateRequiredBody',
        'updateRequiredUpdate',
        'updateRequiredStoreFailed',
        'updateRequiredLater',
      ]);
      expect(_stringsIn(unit), isNot(contains(_texts['updateRequiredBody'])));
      for (final (getter, language, text) in [
        for (final MapEntry(key: getter, value: text) in _texts.entries)
          (getter, 'en', text),
        for (final MapEntry(key: getter, value: text) in _ukrainian.entries)
          (getter, 'uk', text),
      ]) {
        final arb = app.files.entries
            .singleWhere(
              (file) =>
                  file.key.endsWith('_$language.arb') &&
                  file.key.startsWith('lib/'),
            )
            .value
            .text;
        expect(arb, contains('"$getter": "${text.replaceAll('"', r'\"')}"'));
      }
    });
  });

  group('the documentation of the package', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test(
        'shows in its example and its README a command that generates an app '
        'with the module, and names the parameter and the key of .env', () {
      const command = 'smf create my_app -m update_required';
      final example = read('example/README.md');

      expect(example, contains('$command --no-input'));
      expect(read('README.md'), contains('$command\n'));
      final code = _codeOf(
        example.replaceAll(RegExp(r'```[\s\S]*?```'), ''),
      );
      expect(
        code,
        containsAll([
          UpdateRequiredModule.minimumVersion.name,
          ReviewRole.appStoreIdKey.name,
        ]),
      );
    });
  });
}
