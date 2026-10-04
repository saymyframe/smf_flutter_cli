@TestOn('vm')
library;

import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/texts.dart';
import 'support/type_check.dart';

/// A text with what code and JSON escape, a line break and letters beyond
/// ASCII, which has no translation.
const _bye = 'Say "bye" to the app\'s \\ for \$5 — до зустрічі\nSee you';

/// A module with a text in three languages of the app and in Maltese, a
/// language that no app can be in, and a text without a translation.
const _greeting = TextsModule('greeting', [
  LocalizedText(
    'hello',
    en: 'Hello',
    translations: {'uk': 'Вітаю', 'mt': 'Bonġu', 'de': 'Hallo'},
  ),
  LocalizedText('bye', en: _bye),
]);

/// A second module with a text, in two languages.
const _tabs = TextsModule('tabs', [
  LocalizedText('first', en: 'First', translations: {'uk': 'Перша'}),
]);

/// The modules of the tests: flutter_core, which creates the app, this
/// module, and two modules with texts.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GenL10nModule(),
  _greeting,
  _tabs,
];

const _module = ModuleOrigin(GenL10nModule.id);

/// The path of the file with the extension that the role requires.
const String _accessor = LocalizationRole.textsFile;

/// What the contract harness finds for the app of [modules] among
/// [registry], with the role [options].
Future<ContractResult> _check(
  List<ModuleId> modules, {
  List<SmfModule> registry = _modules,
  Map<String, String> options = const {},
}) =>
    ContractHarness(ModuleRegistry(registry)).check(
      ContractCase(
        modules.join(', '),
        requested: modules,
        roleOptions: options,
      ),
    );

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _rendered(
  List<ModuleId> modules, {
  Map<String, String> options = const {},
}) async {
  final result = await _check(modules, options: options);
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// [text], YAML, as plain maps and lists.
Object? _yamlOf(String text) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(text));
}

/// The ARB files of [app] by path, each as the entries of its JSON object
/// in their order.
Map<String, List<(String, Object?)>> _arbFilesOf(RenderedApp app) => {
      for (final file in app.files.values)
        if (file.path.endsWith('.arb'))
          file.path: [
            for (final MapEntry(:key, :value)
                in (jsonDecode(file.text) as Map<String, Object?>).entries)
              (key, value),
          ],
    };

/// What the contributors of the app of [result] put into [socket], each as
/// its origin and the code of its fragment or its key, in the order that
/// the pipeline rendered them.
List<(String, String)> _putInto(ContractResult result, SocketRef socket) => [
      for (final collected in result.app!.socketOrders[socket]?.contributions ??
          const <Collected>[])
        if (collected.contribution case final SocketContribution contribution)
          (
            '${collected.origin}',
            contribution.fragment?.code ?? contribution.entryKey!,
          ),
    ];

void main() {
  const module = GenL10nModule();

  group('GenL10nModule', () {
    test('is infrastructure that provides the localization role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('gen_l10n'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {localizationRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, the generation of the localizations, intl '
        'in the version of Flutter, its delegate and a section of the '
        'README, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(5));
      final brick = (contributions[0] as BrickContribution).bundle;
      expect(brick.name, 'gen_l10n');
      expect(brick.hooks, isEmpty);
      expect(
        [for (final file in brick.files) file.path],
        unorderedEquals(['l10n.yaml', _accessor]),
      );
      final flutter = contributions[1] as PubspecFlutter;
      expect(flutter.generate, isTrue);
      expect(flutter.assets, isEmpty);
      expect(flutter.fonts, isEmpty);
      expect(flutter.usesMaterialDesign, isFalse);
      final intl = contributions[2] as PubspecDependency;
      expect(intl.package, 'intl');
      expect(intl.source, PubspecSource.hosted);
      // flutter_localizations of the Flutter SDK pins the version.
      expect(intl.constraint, 'any');
      expect(intl.dev, isFalse);
      final delegate = contributions[3] as SocketContribution;
      expect(delegate.socket, AppEntryRole.appArgs);
      expect(delegate.argName, 'localizationsDelegates');
      expect(delegate.fragment!.code, 'AppLocalizations.delegate');
      expect(
        delegate.fragment!.imports,
        [const ImportRef.app('l10n/app_localizations.dart')],
      );
      final readme = contributions[4] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, 'Languages');
      for (final contribution in contributions) {
        expect(contribution.when, isEmpty);
      }
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the apps of the modules with texts with the module', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core',
        'gen_l10n',
        'greeting with localization',
        'greeting',
        'tabs with localization',
        'tabs',
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
        'renders code that type-checks with what gen-l10n generates from '
        'the options and the template of the app: the extension of the '
        'role, and the code of a module that reads its texts', () async {
      final withModule = [
        for (final result in results)
          if (result.app!.files.containsKey(_accessor)) result,
      ];
      expect(withModule, hasLength(3));
      for (final result in withModule) {
        expect(
          await analysisProblems(result.app!, {
            _module,
            ModuleOrigin(_greeting.id),
            ModuleOrigin(_tabs.id),
          }),
          isEmpty,
          reason: '${result.contractCase}',
        );
      }
    });
  });

  group('an app whose modules have no texts', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _rendered(const [GenL10nModule.id]);
      app = result.app!;
      without = (await _rendered(const [FlutterCoreModule.id])).app!;
    });

    test('has the options of gen-l10n, the extension and the English file', () {
      expect(
        {
          for (final file in app.files.values)
            if (!without.files.containsKey(file.path))
              file.path: '${file.owner}',
        },
        {
          'l10n.yaml': 'gen_l10n',
          LocalizationRole.appLocaleFile: 'role:localization',
          _accessor: 'gen_l10n',
          GenL10nModule.templateArbFile: 'gen_l10n',
        },
      );
      expect(app.files[GenL10nModule.templateArbFile]!.fromHook, isTrue);
    });

    test('has a template of gen-l10n without texts, in English', () {
      expect(
        app.files[GenL10nModule.templateArbFile]!.text,
        '{\n  "@@locale": "en"\n}\n',
      );
    });

    test('generates the localizations with flutter pub get', () {
      final pubspec =
          _yamlOf(app.files['pubspec.yaml']!.text)! as Map<String, Object?>;

      expect(
        pubspec['flutter'],
        {'uses-material-design': true, 'generate': true},
      );
      expect(pubspec['dependencies'], {
        'flutter': {'sdk': 'flutter'},
        // The template of the role adds the localizations of Flutter.
        'flutter_localizations': {'sdk': 'flutter'},
        'intl': 'any',
      });
    });
  });

  group('an app whose modules have texts', () {
    late ContractResult result;
    late RenderedApp app;

    setUpAll(() async {
      result = await _rendered([GenL10nModule.id, _greeting.id, _tabs.id]);
      app = result.app!;
    });

    test('has an ARB file for each language of the app', () {
      final input = localizationRole.hookInput(result.hook!);

      // The role leaves out Maltese, a language of a text in which Flutter
      // has no texts for its own widgets, so gen-l10n gets no file for it.
      expect(localizationRole.localesIn(input), ['en', 'uk', 'de']);
      expect(_arbFilesOf(app).keys, [
        'lib/l10n/app_de.arb',
        'lib/l10n/app_en.arb',
        'lib/l10n/app_uk.arb',
      ]);
      expect(
        [for (final file in app.files.values) file.text],
        everyElement(isNot(contains('Bonġu'))),
      );
      for (final path in _arbFilesOf(app).keys) {
        expect(app.files[path]!.owner, _module, reason: path);
        expect(app.files[path]!.fromHook, isTrue, reason: path);
      }
    });

    test(
        'has every text in English in the template, by the getter that the '
        'role names it, in the order of the role', () {
      final input = localizationRole.hookInput(result.hook!);

      expect(_arbFilesOf(app)[GenL10nModule.templateArbFile], [
        ('@@locale', 'en'),
        ('greetingHello', 'Hello'),
        ('greetingBye', _bye),
        ('tabsFirst', 'First'),
      ]);
      expect(
        [for (final text in localizationRole.textsIn(input)) text.getter],
        ['greetingHello', 'greetingBye', 'tabsFirst'],
      );
    });

    test(
        'has only the translations in the file of another language, so that '
        'a text without one reads in English', () {
      final files = _arbFilesOf(app);

      expect(files['lib/l10n/app_uk.arb'], [
        ('@@locale', 'uk'),
        ('greetingHello', 'Вітаю'),
        ('tabsFirst', 'Перша'),
      ]);
      expect(files['lib/l10n/app_de.arb'], [
        ('@@locale', 'de'),
        ('greetingHello', 'Hallo'),
      ]);
    });

    test('writes each file as JSON with one text on a line', () {
      expect(
        app.files['lib/l10n/app_de.arb']!.text,
        '{\n'
        '  "@@locale": "de",\n'
        '  "greetingHello": "Hallo"\n'
        '}\n',
      );
      // Letters beyond ASCII stay as they are, for the people who
      // translate the file.
      expect(
        app.files['lib/l10n/app_uk.arb']!.text,
        contains('"greetingHello": "Вітаю"'),
      );
    });

    test('has files only for the languages of --locales', () async {
      final narrowed = await _rendered(
        [GenL10nModule.id, _greeting.id, _tabs.id],
        options: const {'locales': 'uk,en'},
      );

      expect(_arbFilesOf(narrowed.app!).keys, [
        'lib/l10n/app_en.arb',
        'lib/l10n/app_uk.arb',
      ]);
      expect(
        _arbFilesOf(narrowed.app!)[GenL10nModule.templateArbFile],
        _arbFilesOf(app)[GenL10nModule.templateArbFile],
      );

      final english = await _rendered(
        [GenL10nModule.id, _greeting.id, _tabs.id],
        options: const {'locales': 'en'},
      );
      expect(
        _arbFilesOf(english.app!).keys,
        [GenL10nModule.templateArbFile],
      );
    });

    test('puts its delegate before those of Flutter at the root of the app',
        () {
      expect(
        [
          for (final (origin, code) in _putInto(result, AppEntryRole.appArgs))
            if (code.endsWith('.delegate')) (origin, code),
        ],
        [
          ('gen_l10n', 'AppLocalizations.delegate'),
          ('role:localization', 'GlobalMaterialLocalizations.delegate'),
          ('role:localization', 'GlobalWidgetsLocalizations.delegate'),
          ('role:localization', 'GlobalCupertinoLocalizations.delegate'),
        ],
      );
    });
  });

  group('the options of gen-l10n', () {
    late RenderedApp app;

    setUpAll(() async {
      app = (await _rendered([GenL10nModule.id, _greeting.id])).app!;
    });

    test(
        'name the directory of the ARB files, the template among them and '
        'the file of the localizations, whose class is not nullable', () {
      final options = _yamlOf(app.files['l10n.yaml']!.text);

      expect(options, {
        'arb-dir': GenL10nModule.arbDirectory,
        'template-arb-file': 'app_en.arb',
        'output-localization-file': 'app_localizations.dart',
        'nullable-getter': false,
      });
      expect(GenL10nModule.arbDirectory, 'lib/l10n');
      expect(
        GenL10nModule.templateArbFile,
        '${GenL10nModule.arbDirectory}/app_en.arb',
      );
      expect(app.files.keys, contains(GenL10nModule.templateArbFile));
    });

    test(
        'generate the file that the extension and the delegate of the '
        'module import', () {
      final generated = generatedLocalizationsOf(app);
      final import = module
          .contribute(ContractHarness.defaultContext)
          .whereType<SocketContribution>()
          .first
          .fragment!
          .imports
          .single;

      expect(generated.path, 'lib/l10n/app_localizations.dart');
      expect(import.isAppFile, isTrue);
      expect('lib/${import.uri}', generated.path);
      // gen-l10n writes the file, never the module.
      expect(app.files.keys, isNot(contains(generated.path)));
      expect(
        generated.text,
        allOf(
          contains('static AppLocalizations of('),
          contains('String get greetingHello;'),
          contains('String get greetingBye;'),
        ),
      );
    });
  });

  group('a text whose getter is a member of the class of gen-l10n', () {
    test('is reported to its owner', () async {
      final registry = [
        ..._modules,
        const TextsModule('locale', [LocalizedText('name', en: 'Name')]),
        const TextsModule('supported', [
          LocalizedText('locales', en: 'Languages'),
          LocalizedText('devices', en: 'Devices'),
        ]),
        const TextsModule('localizations', [
          LocalizedText('delegates', en: 'Delegates'),
        ]),
      ];

      final result = await _check(
        const [
          GenL10nModule.id,
          ModuleId('locale'),
          ModuleId('supported'),
          ModuleId('localizations'),
        ],
        registry: registry,
      );

      String reported(String owner, String name, String getter) =>
          '$owner: The text $name of the module $owner would be read as '
          'context.l10n.$getter, but the class that gen-l10n generates for '
          'the texts of the app has a member $getter of its own. Rename the '
          'text.';
      expect(
        [
          for (final issue in result.errors)
            '${issue.origin}: ${issue.message} ${issue.hint}',
        ],
        [
          reported('locale', 'name', 'localeName'),
          reported('supported', 'locales', 'supportedLocales'),
          reported('localizations', 'delegates', 'localizationsDelegates'),
        ],
      );
      expect(result.app, isNull);
    });

    test('is reported for every member of the class', () {
      final provider = module.descriptor.providers.single;
      List<String?> reported(String owner, String name) => [
            for (final issue in provider.validate(
              localizationRole.hookInput(
                RoleHookRequest(
                  data: [
                    localizationRole
                        .data(TextsData([LocalizedText(name, en: 'Text')]))
                        .withOrigin(ModuleOrigin(ModuleId(owner))),
                  ],
                  presentRoles: const {localizationRole},
                  context: ContractHarness.defaultContext,
                ),
              ),
            ))
              issue.message,
          ];

      // A text without a name, which the role reports, would be read by
      // the id of its module alone.
      for (final (owner, name) in [
        ('locale', 'name'),
        ('of', ''),
        ('delegate', ''),
        ('localizations', 'delegates'),
        ('supported', 'locales'),
      ]) {
        expect(reported(owner, name), hasLength(1), reason: '$owner $name');
      }
      expect(reported('locale', 'names'), isEmpty);
      expect(reported('greeting', 'hello'), isEmpty);
    });
  });

  group('the README of the app', () {
    late ContractResult result;

    setUpAll(() async {
      result = await _rendered([GenL10nModule.id, _greeting.id]);
    });

    test('has a section of the module on the languages', () {
      expect(
        _putInto(result, AppEntryRole.readmeSections),
        [('gen_l10n', 'Languages')],
      );
    });

    test('names files of the app, but for the one of a language to add', () {
      final section = module
          .contribute(ContractHarness.defaultContext)
          .whereType<SocketContribution>()
          .singleWhere((socket) => socket.socket == AppEntryRole.readmeSections)
          .entryValue! as String;
      final paths = {
        for (final match
            in RegExp(r'`((?:lib|ios)/[^`]+|l10n\.yaml)`').allMatches(section))
          match[1]!,
      };

      expect(paths, {
        GenL10nModule.arbDirectory,
        GenL10nModule.templateArbFile,
        'l10n.yaml',
        _accessor,
        '${GenL10nModule.arbDirectory}/app_de.arb',
        LocalizationRole.appLocaleFile,
        AppEntryRole.infoPlistFile,
      });
      final files = result.app!.files.keys;
      for (final path in paths.difference({
        GenL10nModule.arbDirectory,
        '${GenL10nModule.arbDirectory}/app_de.arb',
      })) {
        expect(files, contains(path));
      }
      expect(
        files.where((path) => path.startsWith(GenL10nModule.arbDirectory)),
        isNotEmpty,
      );
    });
  });
}
