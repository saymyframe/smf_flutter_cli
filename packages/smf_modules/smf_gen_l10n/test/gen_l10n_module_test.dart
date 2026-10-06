@TestOn('vm')
library;

import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_gen_l10n/src/agents.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
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

/// The modules of the tests: flutter_core, which creates the app,
/// shared_preferences, the preferences that the localization role requires,
/// this module, and two modules with texts.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  SharedPreferencesModule(),
  GenL10nModule(),
  _greeting,
  _tabs,
];

const _module = ModuleOrigin(GenL10nModule.id);

/// The provider of the preferences, which every app with the localization
/// role has, since the app remembers its language in them.
const ModuleId _preferences = SharedPreferencesModule.id;

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

/// The texts that the app entry gives the app of [result], which an app
/// has after those of its modules, as the entries of the ARB file of
/// [language]: each text that is in the language, by its getter.
List<(String, Object?)> _ofAppEntry(ContractResult result, String language) => [
      for (final text in localizationRole.textsIn(
        localizationRole.hookInput(result.hook!),
      ))
        if (text.owner == const ModuleOrigin(FlutterCoreModule.id))
          if (text.text.textIn(language) case final translation?)
            (text.getter, translation),
    ];

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
        'in the version of Flutter, its delegate, a section of the README '
        'and its note for coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(6));
      final note = contributions[5] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, localizationRole.description);
      expect(note.entryValue, AgentNote(agentNote));
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
      expect(readme.entryKey, GenL10nModule.readmeHeading);
      expect(GenL10nModule.readmeHeading, 'Texts');
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
        // The app of the module alone, with the texts of the app entry.
        'flutter_core with localization',
        'flutter_core',
        'shared_preferences',
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

  group('an app whose modules have no texts but the app entry', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _rendered(const [GenL10nModule.id, _preferences]);
      app = result.app!;
      // The app with the preferences, without the localization.
      without = (await _rendered(const [_preferences])).app!;
    });

    test(
        'has the options of gen-l10n, the extension, and a file for each '
        'language of the texts of the app entry, the English one first', () {
      final languages = localizationRole.localesIn(
        localizationRole.hookInput(result.hook!),
      );

      expect(languages.first, 'en');
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
          for (final language in languages)
            '${GenL10nModule.arbDirectory}/app_$language.arb': 'gen_l10n',
        },
      );
      expect(app.files[GenL10nModule.templateArbFile]!.fromHook, isTrue);
    });

    test(
        'has a template of gen-l10n with the texts of the app entry alone, '
        'in English', () {
      final entry = _ofAppEntry(result, 'en');

      expect(entry, isNotEmpty);
      expect(
        _arbFilesOf(app)[GenL10nModule.templateArbFile],
        [('@@locale', 'en'), ...entry],
      );
    });

    test('generates the localizations with flutter pub get', () {
      final pubspec =
          _yamlOf(app.files['pubspec.yaml']!.text)! as Map<String, Object?>;

      expect(
        pubspec['flutter'],
        {'uses-material-design': true, 'generate': true},
      );
      final others =
          _yamlOf(without.files['pubspec.yaml']!.text)! as Map<String, Object?>;
      expect(pubspec['dependencies'], {
        ...others['dependencies']! as Map<String, Object?>,
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
      result = await _rendered(
        [GenL10nModule.id, _preferences, _greeting.id, _tabs.id],
      );
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

      final entry = _ofAppEntry(result, 'en');
      expect(_arbFilesOf(app)[GenL10nModule.templateArbFile], [
        ('@@locale', 'en'),
        ('greetingHello', 'Hello'),
        ('greetingBye', _bye),
        ('tabsFirst', 'First'),
        ...entry,
      ]);
      expect(
        [for (final text in localizationRole.textsIn(input)) text.getter],
        [
          'greetingHello',
          'greetingBye',
          'tabsFirst',
          for (final (getter, _) in entry) getter,
        ],
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
        ..._ofAppEntry(result, 'uk'),
      ]);
      expect(files['lib/l10n/app_de.arb'], [
        ('@@locale', 'de'),
        ('greetingHello', 'Hallo'),
        ..._ofAppEntry(result, 'de'),
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
        [GenL10nModule.id, _preferences, _greeting.id, _tabs.id],
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
        [GenL10nModule.id, _preferences, _greeting.id, _tabs.id],
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
      app = (await _rendered([GenL10nModule.id, _preferences, _greeting.id]))
          .app!;
    });

    test(
        'name the directory of the ARB files, the template among them and '
        'the file of the localizations, whose class is not nullable, and '
        'take each text as it is written', () {
      final options = _yamlOf(app.files['l10n.yaml']!.text);

      expect(options, {
        'arb-dir': GenL10nModule.arbDirectory,
        'template-arb-file': 'app_en.arb',
        'output-localization-file': 'app_localizations.dart',
        'nullable-getter': false,
        // The module writes a text into the ARB file as its owner gave it,
        // so gen-l10n must not read an apostrophe as an escape. It does
        // not by default; the option keeps the texts as they are when a
        // later Flutter has another default.
        'use-escaping': false,
      });
      expect(
        _arbFilesOf(app)[GenL10nModule.templateArbFile],
        contains(('greetingBye', _bye)),
      );
      expect(_bye, contains("'"));
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
          _preferences,
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

  group('the texts of the template of a role', () {
    test(
        'go into the ARB files like those of a module, by the getter that '
        'the role names them', () {
      final provider = module.descriptor.providers.single;
      final output = provider.render(
        localizationRole.hookInput(
          RoleHookRequest(
            data: [
              localizationRole
                  .data(
                    const TextsData([
                      LocalizedText(
                        'language',
                        en: 'Language',
                        translations: {'uk': 'Мова'},
                      ),
                    ]),
                  )
                  .withOrigin(const RoleTemplateOrigin(localizationRole)),
              localizationRole
                  .data(const TextsData([LocalizedText('hello', en: 'Hello')]))
                  .withOrigin(ModuleOrigin(_greeting.id)),
            ],
            presentRoles: const {localizationRole},
            context: ContractHarness.defaultContext,
          ),
        ),
      );

      expect(
        {
          for (final MapEntry(key: path, value: text) in output.files.entries)
            path: jsonDecode(text),
        },
        {
          'lib/l10n/app_en.arb': {
            '@@locale': 'en',
            'localizationLanguage': 'Language',
            'greetingHello': 'Hello',
          },
          'lib/l10n/app_uk.arb': {
            '@@locale': 'uk',
            'localizationLanguage': 'Мова',
          },
        },
      );
    });
  });

  group('the note of the module for coding agents', () {
    late RenderedApp app;

    setUpAll(() async {
      app = (await _rendered(
        [GenL10nModule.id, _preferences, _greeting.id, _tabs.id],
      ))
          .app!;
    });

    /// The inline code of the note: what stands between two backticks.
    Set<String> code() => {
          for (final match in RegExp('`([^`]+)`').allMatches(agentNote))
            match[1]!,
        };

    test(
        'is in the section of the localization of the guide, after what the '
        'role says, and changes no other section', () async {
      final localization = <ContributionOrigin>{
        const RoleTemplateOrigin(localizationRole),
        _module,
      };
      final without =
          (await _rendered([_preferences, _greeting.id, _tabs.id])).app!;
      final notes = app.entriesOf(AppEntryRole.agentSections);

      // The guide has the notes of the app without the localization, and
      // in the section of the localization what the role says and what the
      // module adds.
      expect(
        notes.where((note) => !localization.contains(note.$1)),
        without.entriesOf(AppEntryRole.agentSections),
      );
      expect(
        [
          for (final (origin, heading, note) in notes)
            if (localization.contains(origin)) (origin, heading, note.isOfRole),
        ],
        unorderedEquals([
          (_module, localizationRole.description, false),
          (
            const RoleTemplateOrigin(localizationRole),
            localizationRole.description,
            true,
          ),
        ]),
      );
      expect(
        [
          for (final (origin, _, note) in notes)
            if (origin == _module) note,
        ],
        [AgentNote(agentNote)],
      );
      final ofRole = [
        for (final (origin, _, note) in notes)
          if (origin == const RoleTemplateOrigin(localizationRole)) note.text,
      ].single;

      // The tool of Flutter that the module generates the texts with, as
      // the note of a provider with a package names its package.
      expect(agentNote, startsWith('With `gen-l10n` of Flutter:\n'));
      expect(
        app.files[AppEntryRole.agentsFile]!.text,
        contains(
          '\n## ${localizationRole.description}\n'
          '\n'
          '$ofRole\n'
          '\n'
          '${agentNote.trim()}\n',
        ),
      );
    });

    test(
        'names in inline code its tool and the command of it, the ARB files '
        'of the app by the directory and the pattern of their paths, the '
        'files that gen-l10n writes by a pattern, the options and how code '
        'reads a text, and nothing else', () {
      final arbFiles = _arbFilesOf(app).keys;
      final generated = generatedLocalizationsOf(app).path;
      // A pattern of the note as an expression: any text in place of
      // `<code>` and of `*`.
      RegExp patternOf(String pattern) {
        final parts = pattern.split(RegExp(r'<code>|\*'));
        return RegExp('^${parts.map(RegExp.escape).join('.*')}\$');
      }

      // All of them: the note names nothing of the role, such as the file
      // of the languages, which the note of the role tells of.
      expect(code(), {
        'gen-l10n',
        GenL10nModule.arbDirectory,
        GenL10nModule.templateArbFile,
        '${GenL10nModule.arbDirectory}/app_<code>.arb',
        'flutter gen-l10n',
        'context.l10n.<name>',
        '${GenL10nModule.arbDirectory}/app_localizations*.dart',
        'l10n.yaml',
        'use-escaping: false',
      });
      expect(arbFiles, hasLength(3));
      for (final path in arbFiles) {
        expect(
          path,
          matches(patternOf('${GenL10nModule.arbDirectory}/app_<code>.arb')),
        );
      }
      // The module writes none of the files of gen-l10n, so the note names
      // them by a pattern, which the guide does not read as a path.
      expect(
        generated,
        matches(
          patternOf('${GenL10nModule.arbDirectory}/app_localizations*.dart'),
        ),
      );
      expect(app.files.keys, isNot(contains(generated)));
    });

    test(
        'tells to run the command of the README of the app after every '
        'change of the ARB files, to name a text as the module names the '
        'texts of the app, and that the options turn the escapes off', () {
      final readme = module
          .contribute(ContractHarness.defaultContext)
          .whereType<SocketContribution>()
          .singleWhere((socket) => socket.socket == AppEntryRole.readmeSections)
          .entryValue! as String;
      final options =
          _yamlOf(app.files['l10n.yaml']!.text)! as Map<String, Object?>;

      // One command, which generates the code after every change of the
      // ARB files, a new file included; `flutter pub get` does so only for
      // a file that it read before, in the directory of its last run.
      expect(
        {
          for (final span in code())
            if (span.startsWith('flutter ')) span,
        },
        {'flutter gen-l10n'},
      );
      expect(
        agentNote,
        contains(
          'After every change of the ARB files, a new file included, run '
          '`flutter gen-l10n`',
        ),
      );
      expect(readme, contains('`flutter gen-l10n`'));
      expect(options['use-escaping'], isFalse);
      // The getter that the note reads a text through is the one that the
      // file of the module declares on a context.
      final texts = DartFileIndexer.index(
        _accessor,
        app.files[_accessor]!.text,
      ).declaration(LocalizationRole.appTexts.name)!;
      expect(texts.kind, DeclarationKind.extension);
      expect(
        [
          for (final member in texts.members)
            if (member.kind == MemberKind.getter) member.name,
        ],
        ['l10n'],
      );
      // The case that the note asks of the name of a new text is the case
      // of the names that the module writes, the getters of the role.
      final asked = RegExp('under a name in ([A-Za-z_]+),').firstMatch(
        agentNote,
      )![1];
      expect(asked, 'lowerCamelCase');
      final names = [
        for (final (name, _)
            in _arbFilesOf(app)[GenL10nModule.templateArbFile]!)
          if (!name.startsWith('@')) name,
      ];
      expect(names, isNotEmpty);
      for (final name in names) {
        expect(name, matches(RegExp(r'^[a-z][A-Za-z0-9]*$')));
      }
    });
  });

  group('the README of the app', () {
    late ContractResult result;
    late String section;

    setUpAll(() async {
      result = await _rendered([GenL10nModule.id, _preferences, _greeting.id]);
      section = module
          .contribute(ContractHarness.defaultContext)
          .whereType<SocketContribution>()
          .singleWhere((socket) => socket.socket == AppEntryRole.readmeSections)
          .entryValue! as String;
    });

    test(
        'has the section of the module on the texts, and the section of '
        'the role on the languages', () {
      expect(
        _putInto(result, AppEntryRole.readmeSections),
        [
          ('gen_l10n', GenL10nModule.readmeHeading),
          ('role:localization', LocalizationRole.readmeHeading),
        ],
      );
    });

    test('names files of the app, but for the one of a language to add', () {
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
      // The file that gen-l10n writes, as the options name it.
      final options = _yamlOf(result.app!.files['l10n.yaml']!.text)!
          as Map<String, Object?>;
      expect(section, contains('`${options['output-localization-file']}`'));
    });

    test(
        'tells to run gen-l10n after every change of the ARB files: after a '
        'new text, and once the file of a new language is added', () {
      final steps = [
        for (final line in section.split('\n'))
          if (RegExp(r'^\d+\. ').hasMatch(line)) line,
      ];
      final commands = {
        for (final match in RegExp('`(flutter [^`]+)`').allMatches(section))
          match[1]!,
      };

      expect(steps, hasLength(2));
      expect(steps.first, startsWith('1. '));
      expect(
        steps.first,
        contains('`${GenL10nModule.arbDirectory}/app_de.arb`'),
      );
      expect(steps.last, '2. Run `flutter gen-l10n`.');
      final paragraphs = section.split('\n\n');
      expect(
        paragraphs.first,
        contains('Run `flutter gen-l10n` after every change of the ARB files.'),
      );
      expect(
        paragraphs.singleWhere((text) => text.startsWith('To add a text, ')),
        contains('Then run `flutter gen-l10n`.'),
      );
      // The other command is for a fresh clone, which has no generated
      // code: after a change it generates the code only for a file that it
      // read before, in the directory of its last run.
      expect(commands, {'flutter pub get', 'flutter gen-l10n'});
      expect(
        paragraphs.first,
        contains(
          'In a fresh clone of the app, `flutter pub get` generates those '
          'files',
        ),
      );
      expect(
        [
          for (final paragraph in paragraphs)
            if (paragraph.contains('`flutter pub get`')) paragraph,
        ],
        [paragraphs.first],
      );
    });

    test(
        'leaves where else a new language goes to the section of the role, '
        'which it names', () {
      final role = _putInto(result, AppEntryRole.readmeSections).last;

      expect(role, ('role:localization', LocalizationRole.readmeHeading));
      expect(section, contains('"${LocalizationRole.readmeHeading}"'));
      // What the template of the role writes for each language is in its
      // section alone, so that no provider keeps a copy of it.
      for (final ofRole in [
        LocalizationRole.appLocaleFile,
        'appLocales',
        AppEntryRole.infoPlistFile,
        'CFBundleLocalizations',
        LocalizationRole.languageSettingFile,
        '_names',
      ]) {
        expect(section, isNot(contains(ofRole)), reason: ofRole);
      }
    });
  });
}
