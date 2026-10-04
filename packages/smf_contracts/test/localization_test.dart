import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:mason/mason.dart' show MasonBundle;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

const _title = LocalizedText(
  'title',
  en: 'Settings',
  translations: {'uk': 'Налаштування'},
);

const _openDetails = LocalizedText(
  'openDetails',
  en: 'Open',
  translations: {'de': 'Öffnen', 'uk': 'Відкрити'},
);

const _texts = ImportRef.app('core/l10n/l10n.dart');

/// A role whose template has texts: it uses the localization role.
final _themeRole = TestRole<NoDsl>('app_theme', uses: {localizationRole});

/// The [texts] that the module [module] gives the localization role.
RoleData<Object> _of(String module, List<LocalizedText> texts) =>
    dataOf(localizationRole, TextsData(texts), module: module);

/// The [texts] that the template of [role] gives the localization role.
RoleData<Object> _ofTemplate(Role role, List<LocalizedText> texts) =>
    localizationRole
        .data(TextsData(texts))
        .withOrigin(RoleTemplateOrigin(role));

/// The [texts] that the variant of the module [module] for the provider
/// [variant] gives the localization role.
RoleData<Object> _ofVariant(
  String module,
  String variant,
  List<LocalizedText> texts,
) =>
    localizationRole.data(TextsData(texts)).withOrigin(
          ModuleOrigin(ModuleId(module), variant: ModuleId(variant)),
        );

/// The messages of [issues].
List<String> _messages(List<SmfIssue> issues) =>
    [for (final issue in issues) issue.message];

void main() {
  group('LocalizedText', () {
    test('is in English and in the languages of its translations', () {
      expect(_openDetails.languages, ['en', 'de', 'uk']);
      expect(_openDetails.textIn('en'), 'Open');
      expect(_openDetails.textIn('uk'), 'Відкрити');
      expect(_openDetails.textIn('fr'), isNull);
      expect(const LocalizedText('ok', en: 'OK').languages, ['en']);
      expect('$_openDetails', 'text openDetails');
    });

    test('has no problems with a name, an English text and translations', () {
      expect(_title.problems(), isEmpty);
      expect(_openDetails.problems(), isEmpty);
      // Quotes, percent signs and the like are text.
      expect(
        const LocalizedText('page2Title', en: "It's 100%").problems(),
        isEmpty,
      );
    });

    test('needs a lowerCamelCase name', () {
      for (final name in ['Title', 'open_details', '2nd', 'a-b', '', 'назва']) {
        expect(
          LocalizedText(name, en: 'Text').problems().single,
          'The text "$name" needs a name that is a lowerCamelCase '
          'identifier, such as title.',
        );
      }
    });

    test('needs an English text', () {
      expect(
        const LocalizedText('title', en: '', translations: {'uk': 'Назва'})
            .problems(),
        ['The text "title" has no English text.'],
      );
    });

    test('takes translations by the code of a language other than en', () {
      String notACode(String code) =>
          'The text "title" has a translation into "$code", which is not the '
          'code of a language: two or three lowercase letters, such as uk.';
      const english = 'The text "title" has a translation into en, but its '
          'English text is the text itself.';

      expect(
        const LocalizedText(
          'title',
          en: 'Title',
          translations: {
            'en': 'Title',
            'UK': 'Назва',
            'en_GB': 'Title',
            'ukr': 'Назва',
            'u': 'Назва',
            'ukra': 'Назва',
          },
        ).problems(),
        [
          english,
          notACode('UK'),
          notACode('en_GB'),
          notACode('u'),
          notACode('ukra'),
        ],
      );
    });

    test('has no empty translation', () {
      expect(
        const LocalizedText('title', en: 'Title', translations: {'uk': ''})
            .problems()
            .single,
        'The text "title" has an empty translation into uk; leave a language '
        'out to read the text in English there.',
      );
    });

    test('has no braces, which mark the parameters that it does not take', () {
      String brace(String language) =>
          'The text "greeting" has a brace in its text in $language; a text '
          'takes no parameters, so it has neither { nor }.';

      expect(
        const LocalizedText(
          'greeting',
          en: 'Hello, {name}',
          translations: {'uk': 'Вітаю}', 'de': 'Hallo'},
        ).problems(),
        [brace('en'), brace('uk')],
      );
    });
  });

  group('the localization role', () {
    test('requires the extension with the texts from its provider', () {
      expect(LocalizationRole.textsFile, 'lib/core/l10n/l10n.dart');
      expect(LocalizationRole.appTexts.path, LocalizationRole.textsFile);
      expect(LocalizationRole.appTexts.importRef, _texts);
      expect('${LocalizationRole.appTexts}', 'extension AppTexts');
      expect(localizationRole.interface.symbols, [LocalizationRole.appTexts]);
      expect(
        localizationRole.interface.files,
        [LocalizationRole.appLocaleFile],
      );

      // What code that knows only the role reads: context.l10n.
      List<String> problems(IndexedDeclaration declaration) => _messages(
            localizationRole.interface.checkSymbols({
              LocalizationRole.textsFile: DartFileIndex(
                path: LocalizationRole.textsFile,
                declarations: [declaration],
              ),
            }),
          );
      const where = 'extension AppTexts in lib/core/l10n/l10n.dart';

      expect(
        problems(
          const IndexedDeclaration(
            name: 'AppTexts',
            kind: DeclarationKind.extension,
            type: 'BuildContext',
            members: [IndexedMember('l10n', kind: MemberKind.getter)],
          ),
        ),
        isEmpty,
      );
      expect(
        problems(
          const IndexedDeclaration(
            name: 'AppTexts',
            kind: DeclarationKind.extension,
            type: 'State',
          ),
        ),
        [
          '$where must be on BuildContext, not on State.',
          '$where must declare the instance getter l10n.',
        ],
      );
    });

    test('takes the languages of the app from --locales', () {
      expect(
        [for (final option in localizationRole.options) option.name],
        ['locales'],
      );
      expect(LocalizationRole.localesOption.allowed, isNull);
    });

    test(
        'knows the languages in which Flutter has the texts of its own '
        'widgets, by the codes that a text names them with', () {
      const languages = LocalizationRole.supportedLanguages;

      // The languages that the Material, Cupertino and widgets delegates
      // of Flutter 3.44 all support.
      expect(languages, hasLength(81));
      expect(
        languages,
        containsAll(['en', 'uk', 'de', 'he', 'fil', 'gsw', 'nb', 'no', 'zh']),
      );
      // Each is a code that a text names a translation with.
      for (final language in languages.difference({'en'})) {
        expect(
          LocalizedText('title', en: 'Title', translations: {language: 'T'})
              .problems(),
          isEmpty,
          reason: language,
        );
      }
      // Pashto has no Cupertino texts, Maltese none at all; a code of three
      // letters where Flutter has two; and a code that Locale replaces, so
      // that no text of a provider would match it.
      for (final language in ['ps', 'mt', 'ukr', 'xx', 'iw', 'in', 'ji']) {
        expect(languages, isNot(contains(language)), reason: language);
      }
    });
  });

  group('the texts of an app', () {
    final data = [
      _of('home', const [_title, _openDetails]),
      // The variant of a module gives texts of the module.
      _ofVariant('firebase_core', 'bloc', const [
        LocalizedText('ok', en: 'OK'),
      ]),
      _ofTemplate(_themeRole, const [LocalizedText('mode', en: 'Theme')]),
    ];

    test('are those of the owners in order, each with its getter', () {
      final texts =
          localizationRole.textsIn(inputOf(localizationRole, data: data));

      expect(
        [for (final text in texts) '${text.getter}: $text'],
        [
          'homeTitle: text title of the module home',
          'homeOpenDetails: text openDetails of the module home',
          'firebaseCoreOk: text ok of the module firebase_core',
          'appThemeMode: text mode of the template of the app_theme role',
        ],
      );
      expect(
        [for (final text in texts) text.owner],
        [
          const ModuleOrigin(ModuleId('home')),
          const ModuleOrigin(ModuleId('home')),
          const ModuleOrigin(ModuleId('firebase_core')),
          RoleTemplateOrigin(_themeRole),
        ],
      );
      expect(texts.first.text, same(_title));
    });

    test('are read by the hooks of a role that uses the role', () {
      final input = inputOf(
        _themeRole,
        data: data,
        present: {localizationRole},
      );

      expect(localizationRole.textsIn(input), hasLength(4));
      expect(
        () => localizationRole.textsIn(inputOf(routerRole, data: data)),
        throwsArgumentError,
      );
    });

    test('are in every language of a text, English first', () {
      expect(
        localizationRole.localesIn(inputOf(localizationRole, data: data)),
        ['en', 'uk', 'de'],
      );
      expect(localizationRole.localesIn(inputOf(localizationRole)), ['en']);
    });

    test('are not in a language that no app can be in', () {
      final input = inputOf(
        localizationRole,
        data: [
          _of('home', const [
            LocalizedText(
              'title',
              en: 'Home',
              translations: {'mt': 'Dar', 'uk': 'Головна', 'ps': 'کور'},
            ),
          ]),
        ],
      );

      expect(localizationRole.localesIn(input), ['en', 'uk']);
      // The text keeps what its owner gave.
      expect(
        localizationRole.textsIn(input).single.text.languages,
        ['en', 'mt', 'uk', 'ps'],
      );
    });

    test('are in the languages that the template chose', () {
      expect(
        localizationRole.localesIn(
          inputOf(
            localizationRole,
            data: data,
            choice: const LocalizationChoice(['uk', 'en']),
          ),
        ),
        ['uk', 'en'],
      );
    });
  });

  group('the choice of the languages', () {
    final data = [
      _of('home', const [_title, _openDetails]),
      _of('feed', const [
        LocalizedText('empty', en: 'Nothing here'),
        LocalizedText('retry', en: 'Retry', translations: {'uk': 'Ще раз'}),
        LocalizedText('more', en: 'More'),
      ]),
    ];

    Future<Object?> choose(
      List<RoleData<Object>> data, {
      String? locales,
      SmfEnvironment? environment,
    }) =>
        localizationRole.template.choose(
          localizationRole.choiceContext(
            RoleChoiceRequest(
              data: data,
              presentRoles: {localizationRole},
              optionValues: {'locales': locales},
              environment: environment ?? FakeEnvironment(),
              context: testContext,
            ),
          ),
        );

    Matcher failsWith(String message) => throwsA(
          isA<SmfUsageException>().having((e) => e.message, 'message', message),
        );

    test('is every language of the texts, English first', () async {
      final environment = PromptingEnvironment();

      expect(
        await choose(data, environment: environment),
        const LocalizationChoice(['en', 'uk', 'de']),
      );
      expect(environment.asked, isEmpty);
      // An app whose modules have no texts speaks English, and has nothing
      // to warn of.
      expect(await choose(const []), const LocalizationChoice(['en']));
    });

    test('is the languages of --locales, in its order', () async {
      final environment = PromptingEnvironment();
      final choice = await choose(
        data,
        locales: ' uk, en ',
        environment: environment,
      );

      expect(choice, const LocalizationChoice(['uk', 'en']));
      expect(environment.asked, isEmpty);
      expect(
        () => (choice! as LocalizationChoice).locales.add('de'),
        throwsUnsupportedError,
      );
    });

    test('warns of the texts without a translation into a language', () async {
      final environment = PromptingEnvironment();

      await choose(data, environment: environment);

      expect(environment.warnings, hasLength(3));
      expect(
        environment.warnings[0],
        'No translation into uk of the texts empty, more of the module feed: '
        'the app shows them in English there.',
      );
      expect(
        environment.warnings[1],
        'No translation into de of the text title of the module home: the '
        'app shows it in English there.',
      );
      expect(
        environment.warnings[2],
        'No translation into de of the texts empty, retry, more of the '
        'module feed: the app shows them in English there.',
      );
    });

    test('warns only of the languages of the app', () async {
      final environment = PromptingEnvironment();

      await choose(data, locales: 'en', environment: environment);

      expect(environment.warnings, isEmpty);
    });

    test('needs codes with commas between them', () {
      for (final option in ['', 'en,', 'en,,uk', ' ']) {
        expect(
          () => choose(data, locales: option),
          failsWith(
            '--locales takes the codes of languages with commas between '
            'them, such as en,uk, not "$option". The app can be in en, uk, '
            'de.',
          ),
          reason: '"$option"',
        );
      }
    });

    test('takes only the languages that a text of the app is in', () {
      expect(
        () => choose(data, locales: 'en,fr,uk,pl'),
        failsWith(
          'No text of the app is in fr, pl, which --locales names. The app '
          'can be in en, uk, de.',
        ),
      );
    });

    group('with texts in a language that no app can be in', () {
      final data = [
        _of('home', const [
          LocalizedText(
            'title',
            en: 'Home',
            translations: {'mt': 'Dar', 'uk': 'Головна'},
          ),
          LocalizedText('back', en: 'Back', translations: {'mt': 'Lura'}),
        ]),
        _of('feed', const [
          LocalizedText(
            'empty',
            en: 'Nothing here',
            translations: {'uk': 'Порожньо', 'ps': 'هیڅ', 'mt': 'Xejn'},
          ),
        ]),
      ];

      test('leaves the language out, and tells whose texts are in it',
          () async {
        final environment = PromptingEnvironment();

        expect(
          await choose(data, environment: environment),
          const LocalizationChoice(['en', 'uk']),
        );
        expect(environment.warnings, hasLength(4));
        expect(
          environment.warnings[0],
          'The app is not in mt, which the texts title, back of the module '
          'home have translations into: Flutter has no texts for its own '
          'widgets in that language.',
        );
        expect(
          environment.warnings[1],
          'The app is not in ps, which the text empty of the module feed has '
          'a translation into: Flutter has no texts for its own widgets in '
          'that language.',
        );
        expect(
          environment.warnings[2],
          'The app is not in mt, which the text empty of the module feed has '
          'a translation into: Flutter has no texts for its own widgets in '
          'that language.',
        );
        // The module still works in the languages that the app is in.
        expect(
          environment.warnings[3],
          'No translation into uk of the text back of the module home: the '
          'app shows it in English there.',
        );
      });

      test('refuses the language in --locales', () {
        expect(
          () => choose(data, locales: 'en,mt,uk,ps'),
          failsWith(
            'The app cannot be in mt, ps, which --locales names: Flutter has '
            'no texts for its own widgets in such a language. The app can be '
            'in en, uk.',
          ),
        );
        // A language that no text is in comes first.
        expect(
          () => choose(data, locales: 'en,mt,fr'),
          failsWith(
            'No text of the app is in fr, which --locales names. The app can '
            'be in en, uk.',
          ),
        );
      });

      test('says nothing of it when --locales names the languages', () async {
        final environment = PromptingEnvironment();

        expect(
          await choose(data, locales: 'en', environment: environment),
          const LocalizationChoice(['en']),
        );
        expect(environment.warnings, isEmpty);
      });
    });

    test('takes a language once', () {
      expect(
        () => choose(data, locales: 'en,uk,en'),
        failsWith('--locales names a language twice: en,uk,en.'),
      );
    });

    test('needs English, the language of every text', () {
      expect(
        () => choose(data, locales: 'uk,de'),
        failsWith(
          '--locales needs en: the app shows a text in English wherever it '
          'has no translation.',
        ),
      );
    });

    test('equals a choice of the same languages in the same order', () {
      const choice = LocalizationChoice(['en', 'uk']);
      final same = LocalizationChoice(['en', 'uk'].toList());

      expect(choice, same);
      expect(choice.hashCode, same.hashCode);
      expect(choice, isNot(const LocalizationChoice(['uk', 'en'])));
      expect(choice, isNot(const LocalizationChoice(['en'])));
      expect(choice, isNot(const LocalizationChoice(['en', 'uk', 'de'])));
      expect(choice, isNot(['en', 'uk']));
      expect('$choice', 'the languages en, uk');
    });
  });

  group('the code that reads a text', () {
    const home = ModuleOrigin(ModuleId('home'));

    test('is its getter of context.l10n in an app with the role', () {
      final own = localizationRole.expressionOf(
        inputOf(localizationRole),
        home,
        _title,
      );
      final ofTemplate = localizationRole.expressionOf(
        inputOf(_themeRole, present: {localizationRole}),
        RoleTemplateOrigin(_themeRole),
        const LocalizedText('mode', en: 'Theme'),
      );

      expect(own.code, 'context.l10n.homeTitle');
      expect(own.imports, [_texts]);
      expect(ofTemplate.code, 'context.l10n.appThemeMode');
      expect(ofTemplate.imports, [_texts]);
    });

    test('is the English text in an app without the role', () {
      final fragment = localizationRole.expressionOf(
        inputOf(_themeRole),
        RoleTemplateOrigin(_themeRole),
        const LocalizedText(
          'mode',
          en: r"The app's $theme",
          translations: {'uk': 'Тема'},
        ),
      );

      expect(fragment.code, r"'The app\'s \$theme'");
      expect(fragment.imports, isEmpty);
    });

    test('is for a role that requires or uses the role, and for an owner', () {
      expect(
        () => localizationRole.expressionOf(inputOf(routerRole), home, _title),
        throwsArgumentError,
      );
      expect(
        () => localizationRole.expressionOf(
          inputOf(localizationRole),
          const PipelineOrigin(),
          _title,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'The pipeline gives the app no texts',
          ),
        ),
      );
    });
  });

  group('the code that reads a text with problems', () {
    const bad = LocalizedText('Label', en: 'Hello, {name}');
    const message = 'The text "Label" needs a name that is a lowerCamelCase '
        'identifier, such as title. '
        'The text "Label" has a brace in its text in en; a text takes no '
        'parameters, so it has neither { nor }.';

    test('is refused in an app with the role and in one without it', () {
      for (final input in [
        inputOf(_themeRole, present: {localizationRole}),
        inputOf(_themeRole),
        inputOf(localizationRole),
      ]) {
        expect(
          () => localizationRole.expressionOf(
            input,
            RoleTemplateOrigin(_themeRole),
            bad,
          ),
          throwsA(
            isA<ArgumentError>().having((e) => e.message, 'message', message),
          ),
        );
      }
    });
  });

  group('the variables of a brick that read the texts of a module', () {
    test('are named after the texts, and depend on the role', () {
      final vars = localizationRole.varsOf(
        const ModuleId('firebase_core'),
        const TextsData([
          _title,
          LocalizedText('openDetails', en: r"It's $5"),
        ]),
      );

      expect(vars.keys, ['text_title', 'text_open_details']);
      for (final variable in vars.values) {
        expect(variable.role, same(localizationRole));
      }
      final present = [
        for (final variable in vars.values) variable.present as Fragment,
      ];
      expect(
        [for (final fragment in present) fragment.code],
        [
          'context.l10n.firebaseCoreTitle',
          'context.l10n.firebaseCoreOpenDetails',
        ],
      );
      for (final fragment in present) {
        expect(fragment.imports, [_texts]);
      }
      expect(
        [for (final variable in vars.values) variable.absent],
        ["'Settings'", r"'It\'s \$5'"],
      );
      expect(
        localizationRole.varsOf(const ModuleId('home'), const TextsData([])),
        isEmpty,
      );
    });

    test('are not made of texts with problems', () {
      expect(
        () => localizationRole.varsOf(
          const ModuleId('home'),
          const TextsData([
            LocalizedText('Title', en: ''),
            _title,
            _title,
            LocalizedText('userId', en: 'Id'),
            LocalizedText('userID', en: 'ID'),
          ]),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'The text "Title" needs a name that is a lowerCamelCase '
                'identifier, such as title. '
                'The text "Title" has no English text. '
                'Two texts are named "title". '
                'The texts "userId" and "userID" differ only in case, so '
                'both would have the brick variable text_user_id.',
          ),
        ),
      );
    });
  });

  group('the rule localization.texts', () {
    List<SmfIssue> check(String module, List<RoleData<Object>> data) =>
        localizationRole.checkModule(
          ModuleRuleRequest(
            hook: RoleHookRequest(
              data: data,
              presentRoles: {localizationRole},
              context: testContext,
            ),
            module: ModuleDescriptor(
              id: ModuleId(module),
              description: module,
              kind: plainKind,
              uses: const {localizationRole},
            ),
            contributions: const [],
          ),
        );

    test('has the id and a description', () {
      final rule = localizationRole.moduleRules.single;

      expect(rule.id, 'localization.texts');
      expect(rule.description, isNotEmpty);
    });

    test('passes the texts of a module without problems', () {
      expect(
        check('home', [
          _of('home', const [_title, _openDetails]),
        ]),
        isEmpty,
      );
      expect(check('home', const []), isEmpty);
    });

    test('reports the problems of each text of the module', () {
      final issues = check('home', [
        _of('home', const [
          LocalizedText('Title', en: 'Title'),
          LocalizedText('empty', en: ''),
        ]),
        // The texts of another module are that module's to fix.
        _of('feed', const [LocalizedText('Other', en: '')]),
      ]);

      expect(issues, hasLength(2));
      expect(
        issues.first.message,
        'The text "Title" needs a name that is a lowerCamelCase identifier, '
        'such as title.',
      );
      expect(issues.last.message, 'The text "empty" has no English text.');
      expect(
        [for (final issue in issues) issue.origin],
        everyElement(const ModuleOrigin(ModuleId('home'))),
      );
    });

    test('reports two texts of one name, also of the variant', () {
      final issues = check('home', [
        _of('home', const [_title, LocalizedText('userId', en: 'Id')]),
        _ofVariant('home', 'bloc', const [
          LocalizedText('title', en: 'Other'),
          LocalizedText('userID', en: 'ID'),
        ]),
      ]);

      expect(issues, hasLength(2));
      expect(issues.first.message, 'Two texts are named "title".');
      expect(
        issues.last.message,
        'The texts "userId" and "userID" differ only in case, so both would '
        'have the brick variable text_user_id.',
      );
    });
  });

  group('the rule localization.texts, for the variables of the bricks', () {
    const home = ModuleId('home');
    const texts = TextsData([_title, _openDetails]);

    List<SmfIssue> check(
      List<RoleData<Object>> data,
      Map<String, Object?> vars,
    ) =>
        localizationRole.checkModule(
          ModuleRuleRequest(
            hook: RoleHookRequest(
              data: data,
              presentRoles: {localizationRole},
              context: testContext,
            ),
            module: const ModuleDescriptor(
              id: home,
              description: 'Home',
              kind: plainKind,
              uses: {localizationRole},
              dependsOn: {ModuleId('shared')},
            ),
            contributions: [
              BrickContribution(
                const MasonBundle(
                  name: 'home_screen',
                  description: 'home',
                  version: '0.1.0',
                ),
                vars: vars,
              ),
            ],
          ),
        );

    test('passes the variables of the texts that the module gave the role', () {
      expect(
        check(
          [
            _of('home', texts.texts),
          ],
          localizationRole.varsOf(home, texts),
        ),
        isEmpty,
      );
    });

    test('reports a variable whose text the module did not give the role', () {
      final issues = check(
        [
          _of('home', const [_title]),
        ],
        localizationRole.varsOf(home, texts),
      );

      expect(
        issues.single.message,
        'The variable text_open_details of the brick home_screen reads '
        'context.l10n.homeOpenDetails, but no text of the app has the getter '
        'homeOpenDetails.',
      );
      expect(issues.single.origin, const ModuleOrigin(home));
      expect(issues.single.hint, contains('localizationRole.data(texts)'));
    });

    test(
        'reports a variable whose English text differs from that of the '
        'text, so that the app would read otherwise without the role', () {
      final issues = check(
        [
          _of('home', const [
            LocalizedText('title', en: "The app's start"),
            _openDetails,
          ]),
        ],
        localizationRole.varsOf(home, texts),
      );

      expect(
        issues.single.message,
        "The variable text_title of the brick home_screen is 'Settings' in "
        'an app without the localization role, but the text title of the '
        r"module home is 'The app\'s start' in English.",
      );
      expect(issues.single.origin, const ModuleOrigin(home));
      expect(issues.single.hint, contains('localizationRole.varsOf()'));
    });

    test('compares a variable that reads the text of another module too', () {
      final data = [
        _of('home', const [_title]),
        _of('shared', const [LocalizedText('ok', en: 'OK')]),
      ];
      RoleVar reading(String english) => RoleVar(
            localizationRole,
            present: 'context.l10n.sharedOk',
            absent: english,
          );

      expect(check(data, {'ok': reading("'OK'")}), isEmpty);
      expect(
        check(data, {'ok': reading("'Fine'")}).single.message,
        "The variable ok of the brick home_screen is 'Fine' in an app "
        'without the localization role, but the text ok of the module shared '
        "is 'OK' in English.",
      );
    });

    test('leaves other variables alone', () {
      expect(
        check(
          [
            _of('home', const [_title]),
          ],
          {
            // Plain data, code of another role, and code of this role that
            // reads no text.
            'count': 3,
            'label': "'Home'",
            'zones': RoleVar(
              _themeRole,
              present: 'context.l10n.nothing',
              absent: "'None'",
            ),
            'picker': const RoleVar(
              localizationRole,
              present: Fragment('LanguagePicker()'),
              absent: 'SizedBox()',
            ),
            'upper': const RoleVar(
              localizationRole,
              present: 'context.l10n.homeTitle.toUpperCase()',
              absent: "'SETTINGS'",
            ),
          },
        ),
        isEmpty,
      );
    });
  });

  group('the template checks the texts of all owners', () {
    List<String> validate(List<RoleData<Object>> data) => [
          for (final issue in localizationRole.template
              .validate(inputOf(localizationRole, data: data)))
            '${issue.origin}: ${issue.message} ${issue.hint ?? ''}'.trim(),
        ];

    test('passes texts whose getters differ', () {
      expect(
        validate([
          _of('home', const [_title]),
          _of('feed', const [_title]),
          _ofTemplate(_themeRole, const [_title]),
        ]),
        isEmpty,
      );
    });

    test('reports the problems of the texts of a template of a role', () {
      final issues = validate([
        // The rule localization.texts reports those of a module.
        _of('home', const [LocalizedText('Title', en: '')]),
        _ofTemplate(_themeRole, const [
          LocalizedText('Mode', en: 'Theme'),
          LocalizedText('dark', en: 'Dark'),
          LocalizedText('dark', en: 'Dark'),
        ]),
      ]);

      expect(issues, hasLength(2));
      expect(
        issues.first,
        'role:app_theme: The text "Mode" needs a name that is a '
        'lowerCamelCase identifier, such as title.',
      );
      expect(issues.last, 'role:app_theme: Two texts are named "dark".');
    });

    test('names a text without a name after its owner alone', () {
      final data = [
        _of('home', const [LocalizedText('', en: 'Home')]),
      ];

      // The rule localization.texts tells the module of the name.
      expect(validate(data), isEmpty);
      expect(
        localizationRole
            .textsIn(inputOf(localizationRole, data: data))
            .single
            .getter,
        'home',
      );
    });

    test('reports two owners whose texts need one getter', () {
      final issues = validate([
        _of('home_screen', const [_title]),
        _of('home', const [LocalizedText('screenTitle', en: 'Home')]),
        _ofTemplate(
          TestRole<NoDsl>('home', uses: {localizationRole}),
          const [LocalizedText('screenTitle', en: 'Home')],
        ),
      ]);

      expect(issues, hasLength(2));
      expect(
        issues.first,
        'home: The text screenTitle of the module home and the text title of '
        'the module home_screen both need the getter homeScreenTitle. Rename '
        'one of the texts.',
      );
      expect(
        issues.last,
        'role:home: The text screenTitle of the template of the home role '
        'and the text title of the module home_screen both need the getter '
        'homeScreenTitle. Rename one of the texts.',
      );
    });

    test('reports a text whose getter is a member of every object', () {
      String reserved(String owner, String name, String getter) =>
          '$owner: The text $name of the module $owner would be read as '
          'context.l10n.$getter, which no getter of a text can be named. '
          'Rename the text.';

      expect(
        validate([
          _of('hash', const [LocalizedText('code', en: 'Code')]),
          _of('runtime', const [LocalizedText('type', en: 'Type')]),
          _of('to', const [LocalizedText('string', en: 'Text')]),
          _of('no', const [LocalizedText('suchMethod', en: 'None')]),
        ]),
        [
          reserved('hash', 'code', 'hashCode'),
          reserved('runtime', 'type', 'runtimeType'),
          reserved('to', 'string', 'toString'),
          reserved('no', 'suchMethod', 'noSuchMethod'),
        ],
      );
    });
  });

  group('the rule localization.text_access', () {
    const home = ModuleDescriptor(
      id: ModuleId('home'),
      description: 'Home',
      kind: plainKind,
      dependsOn: {ModuleId('shared')},
      uses: {localizationRole},
    );
    const shared = ModuleDescriptor(
      id: ModuleId('shared'),
      description: 'Shared',
      kind: plainKind,
      uses: {localizationRole},
    );
    const feed = ModuleDescriptor(
      id: ModuleId('feed'),
      description: 'Feed',
      kind: plainKind,
      requires: {localizationRole},
    );
    // A module without the role among its roles.
    const plain = ModuleDescriptor(
      id: ModuleId('plain'),
      description: 'Plain',
      kind: plainKind,
    );
    const provider = ModuleDescriptor(
      id: ModuleId('texts'),
      description: 'Texts',
      kind: plainKind,
      providers: [RoleProvider.plain(localizationRole)],
    );
    // A provider of another role, which uses the localization role.
    final settings = ModuleDescriptor(
      id: const ModuleId('settings'),
      description: 'Settings',
      kind: plainKind,
      providers: [RoleProvider.plain(_themeRole)],
    );
    final data = [
      _of('home', const [_title]),
      _of('shared', const [LocalizedText('ok', en: 'OK')]),
      _of('feed', const [LocalizedText('empty', en: 'Nothing here')]),
      _ofTemplate(_themeRole, const [LocalizedText('mode', en: 'Theme')]),
    ];

    /// The issues of an app whose file at `lib/file.dart`, generated by
    /// [owner], has [accesses] and [invocations].
    List<SmfIssue> check(
      ContributionOrigin? owner, {
      List<IndexedMemberAccess> accesses = const [],
      List<IndexedInvocation> invocations = const [],
    }) =>
        localizationRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: data,
              presentRoles: {localizationRole},
              context: testContext,
            ),
            files: {
              'lib/file.dart': DartFileIndex(
                path: 'lib/file.dart',
                memberAccesses: accesses,
                invocations: invocations,
              ),
            },
            // The provider renders every text, as the other rule of the
            // role asks.
            texts: const {
              LocalizationRole.textsFile:
                  'homeTitle sharedOk feedEmpty appThemeMode',
            },
            owners: {
              if (owner != null) 'lib/file.dart': owner,
              LocalizationRole.textsFile: const ModuleOrigin(ModuleId('texts')),
            },
            modules: [home, shared, feed, plain, provider, settings],
          ),
        );

    const ofHome = ModuleOrigin(ModuleId('home'));

    test('has the id, and a description that says what it does not see', () {
      final rule = localizationRole.structuralRules.first;

      expect(rule.id, 'localization.text_access');
      expect(
        rule.description,
        allOf(
          contains('context.l10n or from a variable called l10n'),
          contains('no text that it reads through another expression'),
        ),
      );
    });

    test('lets a module read its texts and those of its dependencies', () {
      expect(
        check(
          ofHome,
          accesses: const [
            IndexedMemberAccess('context.l10n', 'homeTitle'),
            IndexedMemberAccess('l10n', 'homeTitle'),
            IndexedMemberAccess('widget.context.l10n', 'sharedOk'),
            // Not the texts of the app.
            IndexedMemberAccess('context', 'l10n'),
            IndexedMemberAccess('context.nav', 'feed'),
            IndexedMemberAccess('al10n', 'feedEmpty'),
          ],
          invocations: const [
            IndexedInvocation('toUpperCase', target: 'context.l10n.homeTitle'),
            IndexedInvocation('of', target: 'Localizations'),
            IndexedInvocation('build'),
          ],
        ),
        isEmpty,
      );
    });

    test('lets the variant of a module read the texts of the module', () {
      expect(
        check(
          const ModuleOrigin(ModuleId('home'), variant: ModuleId('bloc')),
          accesses: const [IndexedMemberAccess('context.l10n', 'homeTitle')],
        ),
        isEmpty,
      );
    });

    test('reports a getter that no text of the app has', () {
      final issue = check(
        ofHome,
        accesses: const [IndexedMemberAccess('context.l10n', 'homeTitel')],
      ).single;

      expect(
        issue.message,
        'lib/file.dart reads context.l10n.homeTitel, but no text of the app '
        'has the getter homeTitel.',
      );
      expect(issue.origin, ofHome);
      expect(issue.path, 'lib/file.dart');
      expect(issue.hint, contains('settingsTitle'));
    });

    test('reports a module that reads the texts of another module', () {
      final issues = check(
        ofHome,
        accesses: const [
          IndexedMemberAccess('context.l10n', 'feedEmpty'),
          IndexedMemberAccess('l10n', 'appThemeMode'),
        ],
      );

      expect(issues, hasLength(2));
      expect(
        issues.first.message,
        'lib/file.dart reads context.l10n.feedEmpty, the text empty of the '
        'module feed, but the module home may only read its own texts and '
        'those of the modules it depends on.',
      );
      expect(
        issues.last.message,
        'lib/file.dart reads l10n.appThemeMode, the text mode of the template '
        'of the app_theme role, but the module home may only read its own '
        'texts and those of the modules it depends on.',
      );
      expect(issues.first.origin, ofHome);
      expect(issues.first.path, 'lib/file.dart');
      expect(issues.first.hint, 'Give the role a text of your own.');
    });

    test('lets the template of a role read only its own texts', () {
      final ofTheme = RoleTemplateOrigin(_themeRole);

      expect(
        check(
          ofTheme,
          accesses: const [IndexedMemberAccess('context.l10n', 'appThemeMode')],
        ),
        isEmpty,
      );
      expect(
        check(
          ofTheme,
          accesses: const [IndexedMemberAccess('context.l10n', 'homeTitle')],
        ).single.message,
        'lib/file.dart reads context.l10n.homeTitle, the text title of the '
        'module home, but the template of the app_theme role may only read '
        'its own texts.',
      );
      expect(
        check(
          const PipelineOrigin(),
          accesses: const [IndexedMemberAccess('context.l10n', 'homeTitle')],
        ).single.message,
        'lib/file.dart reads context.l10n.homeTitle, the text title of the '
        'module home, but the pipeline may only read its own texts.',
      );
    });

    test('reports a call on the texts, which are getters', () {
      final issues = check(
        ofHome,
        invocations: const [
          IndexedInvocation('homeTitle', target: 'context.l10n'),
          IndexedInvocation('toString', target: 'l10n'),
        ],
      );

      expect(issues, hasLength(2));
      expect(
        issues.first.message,
        'lib/file.dart calls context.l10n.homeTitle(), but the texts of the '
        'app are getters, each named by the role.',
      );
      expect(
        issues.last.message,
        'lib/file.dart calls l10n.toString(), but the texts of the app are '
        'getters, each named by the role.',
      );
      expect(issues.first.origin, ofHome);
      expect(issues.first.path, 'lib/file.dart');
      expect(issues.first.hint, isNotEmpty);
    });

    test('leaves the provider, which renders every text, alone', () {
      expect(
        check(
          const ModuleOrigin(ModuleId('texts')),
          accesses: const [
            IndexedMemberAccess('l10n', 'feedEmpty'),
            IndexedMemberAccess('l10n', 'delegate'),
          ],
          invocations: const [IndexedInvocation('load', target: 'l10n')],
        ),
        isEmpty,
      );
    });

    test('leaves a file that no one of the app generated alone', () {
      expect(
        check(
          null,
          accesses: const [IndexedMemberAccess('context.l10n', 'feedEmpty')],
        ),
        isEmpty,
      );
    });

    test(
        'leaves a module without the role among its roles alone, whose '
        'variable called l10n is something else', () {
      for (final module in ['plain', 'gone']) {
        expect(
          check(
            ModuleOrigin(ModuleId(module)),
            accesses: const [
              IndexedMemberAccess('l10n', 'name'),
              IndexedMemberAccess('context.l10n', 'homeTitle'),
            ],
            invocations: const [IndexedInvocation('load', target: 'l10n')],
          ),
          isEmpty,
          reason: module,
        );
      }
    });

    test(
        'leaves the template of a role alone that neither requires nor uses '
        'the role', () {
      expect(
        check(
          const RoleTemplateOrigin(routerRole),
          accesses: const [IndexedMemberAccess('l10n', 'name')],
        ),
        isEmpty,
      );
      // The template of the role itself reads its own texts.
      expect(
        check(
          const RoleTemplateOrigin(localizationRole),
          accesses: const [IndexedMemberAccess('context.l10n', 'homeTitle')],
        ).single.message,
        'lib/file.dart reads context.l10n.homeTitle, the text title of the '
        'module home, but the template of the localization role may only '
        'read its own texts.',
      );
    });

    test(
        'checks a module that provides another role, as it does any module '
        'with the role among its roles', () {
      expect(
        check(
          const ModuleOrigin(ModuleId('settings')),
          accesses: const [IndexedMemberAccess('context.l10n', 'homeTitle')],
        ).single.message,
        'lib/file.dart reads context.l10n.homeTitle, the text title of the '
        'module home, but the module settings may only read its own texts '
        'and those of the modules it depends on.',
      );
      // The module that requires the role is checked too.
      expect(
        check(
          const ModuleOrigin(ModuleId('feed')),
          accesses: const [IndexedMemberAccess('context.l10n', 'homeTitle')],
        ),
        hasLength(1),
      );
    });
  });

  group('the rule localization.texts_rendered', () {
    const provider = ModuleDescriptor(
      id: ModuleId('texts'),
      description: 'Texts',
      kind: plainKind,
      providers: [RoleProvider.plain(localizationRole)],
    );
    const home = ModuleDescriptor(
      id: ModuleId('home'),
      description: 'Home',
      kind: plainKind,
      uses: {localizationRole},
    );
    const ofProvider = ModuleOrigin(ModuleId('texts'));
    const ofHome = ModuleOrigin(ModuleId('home'));
    final data = [
      _of('home', const [_title, _openDetails]),
      _ofTemplate(_themeRole, const [LocalizedText('mode', en: 'Theme')]),
    ];

    /// The issues of an app with the text files [texts], by path, each
    /// generated by its owner among [owners].
    List<SmfIssue> check(
      Map<String, String> texts,
      Map<String, ContributionOrigin> owners, {
      List<ModuleDescriptor> modules = const [provider, home],
    }) =>
        localizationRole.checkStructure(
          StructuralRuleRequest(
            hook: RoleHookRequest(
              data: data,
              presentRoles: {localizationRole},
              context: testContext,
            ),
            files: const {},
            texts: texts,
            owners: owners,
            modules: modules,
          ),
        );

    test('has the id and a description', () {
      final rule = localizationRole.structuralRules.last;

      expect(rule.id, 'localization.texts_rendered');
      expect(rule.description, isNotEmpty);
      expect(localizationRole.structuralRules, hasLength(2));
    });

    test(
        'passes a provider whose files name the getter of every text, as '
        'the key of a file of translations or as a getter in code', () {
      expect(
        check(
          {
            'lib/l10n/app_en.arb': '{"homeTitle": "Settings", '
                '"appThemeMode": "Theme"}',
            LocalizationRole.textsFile: "String get homeOpenDetails => 'Open';",
          },
          {
            'lib/l10n/app_en.arb': ofProvider,
            LocalizationRole.textsFile: ofProvider,
          },
        ),
        isEmpty,
      );
    });

    test('reports each text that no file of the provider names', () {
      final issues = check(
        {
          // The getter is a part of a longer name, and a name of the text
          // of another owner.
          LocalizationRole.textsFile: 'String get homeTitleLong => "";\n'
              r'String get $homeOpenDetails => "";'
              '\nObject get l10n => const Object();',
          // A file of a module names the getters too.
          'lib/home.dart': 'context.l10n.homeTitle context.l10n.appThemeMode',
        },
        {LocalizationRole.textsFile: ofProvider, 'lib/home.dart': ofHome},
      );

      expect(issues, hasLength(3));
      expect(
        issues[0].message,
        'The provider of the localization role does not render the text '
        'title of the module home: none of its files names the getter '
        'homeTitle.',
      );
      expect(
        issues[1].message,
        'The provider of the localization role does not render the text '
        'openDetails of the module home: none of its files names the getter '
        'homeOpenDetails.',
      );
      expect(
        issues[2].message,
        'The provider of the localization role does not render the text '
        'mode of the template of the app_theme role: none of its files names '
        'the getter appThemeMode.',
      );
      expect(issues.first.origin, ofHome);
      expect(issues.last.origin, RoleTemplateOrigin(_themeRole));
      expect(issues.first.path, LocalizationRole.textsFile);
      expect(issues.first.hint, contains('LocalizationRole.textsIn()'));
    });

    test('has nothing to check without the descriptor of a provider', () {
      expect(check(const {}, const {}, modules: const [home]), isEmpty);
    });
  });

  group('the template', () {
    final data = [
      _of('home', const [_title, _openDetails]),
    ];

    test('gives the root its language, its languages and the delegates', () {
      final contributions = localizationRole.template.contribute(testContext);
      final sockets = contributions.whereType<SocketContribution>().toList();
      const appLocale = ImportRef.app('core/l10n/app_locale.dart');
      const flutterLocalizations = ImportRef(
        'package:flutter_localizations/flutter_localizations.dart',
      );

      final wrapper = sockets
          .singleWhere((socket) => socket.socket == AppEntryRole.rootWrappers)
          .fragment!;
      expect(wrapper.code, 'AppLocaleScope(notifier: appLocale, child: ');
      expect(wrapper.closing, ')');
      expect(wrapper.imports, [appLocale]);

      final args = [
        for (final socket in sockets)
          if (socket.socket == AppEntryRole.appArgs) socket,
      ];
      expect(
        [for (final arg in args) '${arg.argName}: ${arg.fragment!.code}'],
        [
          'locale: AppLocaleScope.of(context)',
          'supportedLocales: ...appLocales',
          'localizationsDelegates: GlobalMaterialLocalizations.delegate',
          'localizationsDelegates: GlobalWidgetsLocalizations.delegate',
          'localizationsDelegates: GlobalCupertinoLocalizations.delegate',
        ],
      );
      expect(
        [for (final arg in args) arg.fragment!.imports.single],
        [
          appLocale,
          appLocale,
          flutterLocalizations,
          flutterLocalizations,
          flutterLocalizations,
        ],
      );
      // The wrapper, the arguments of the root and the section of the
      // README.
      expect(sockets, hasLength(7));

      final package = contributions.whereType<PubspecDependency>().single;
      expect(package.package, 'flutter_localizations');
      expect(package.source, PubspecSource.sdk);
      expect(package.sdk, 'flutter');
      expect(package.dev, isFalse);
    });

    test('generates the languages of the app and what follows the choice',
        () async {
      final rendered = await renderTemplate(
        localizationRole,
        data: data,
        choice: const LocalizationChoice(['uk', 'en']),
      );

      expect(rendered.files.keys, [LocalizationRole.appLocaleFile]);
      final code = rendered.files[LocalizationRole.appLocaleFile]!;
      expectParses(code);
      final unit = parseString(content: code).unit;
      final variables = {
        for (final declaration
            in unit.declarations.whereType<TopLevelVariableDeclaration>())
          for (final variable in declaration.variables.variables)
            variable.name.lexeme: (
              keyword: declaration.variables.keyword?.lexeme,
              value: variable.initializer!.toSource(),
            ),
      };
      expect(variables, {
        'appLocales': (
          keyword: 'const',
          value: "<Locale>[Locale('uk'), Locale('en')]",
        ),
        'appLocale': (keyword: 'final', value: 'ValueNotifier<Locale?>(null)'),
      });

      final scope = unit.declarations.whereType<ClassDeclaration>().single;
      expect(scope.namePart.typeName.lexeme, 'AppLocaleScope');
      expect(
        scope.extendsClause!.superclass.toSource(),
        'InheritedNotifier<ValueNotifier<Locale?>>',
      );
    });

    test('generates the languages of the texts before a choice', () async {
      final rendered = await renderTemplate(localizationRole, data: data);

      expect(
        rendered.files[LocalizationRole.appLocaleFile],
        contains(
          "const appLocales = <Locale>[Locale('en'), Locale('uk'), "
          "Locale('de')];",
        ),
      );
    });

    test('names the languages of the app in the Info.plist of the iOS app',
        () async {
      final rendered = await renderTemplate(
        localizationRole,
        data: data,
        choice: const LocalizationChoice(['uk', 'en']),
      );

      final entry = rendered.elsewhere
          .singleWhere((socket) => socket.socket == AppEntryRole.infoPlist);
      expect(entry.entryKey, 'CFBundleLocalizations');
      expect(entry.entryValue, const PlistStringArray(['uk', 'en']));
    });

    test(
        'tells in the README of the app where its languages are, and each '
        'place that a new language goes into', () async {
      final section = localizationRole.template
          .contribute(testContext)
          .whereType<SocketContribution>()
          .singleWhere(
            (socket) => socket.socket == AppEntryRole.readmeSections,
          );
      final text = section.entryValue! as String;

      expect(LocalizationRole.readmeHeading, 'Languages');
      expect(section.entryKey, LocalizationRole.readmeHeading);
      expect(section.when, isEmpty);

      // What the template writes differently for an app with one more
      // language: the places that a new language goes into.
      Future<RenderedTemplate> appIn(List<String> languages) => renderTemplate(
            localizationRole,
            data: data,
            choice: LocalizationChoice(languages),
          );
      final english = await appIn(['en']);
      final german = await appIn(['en', 'de']);
      final files = [
        for (final MapEntry(key: path, value: code) in german.files.entries)
          if (english.files[path] != code) path,
      ];
      final entries = [
        for (final (index, entry) in german.elsewhere.indexed)
          if (entry.entryValue != english.elsewhere[index].entryValue) entry,
      ];
      expect(files, [LocalizationRole.appLocaleFile]);
      expect(
        german.files[LocalizationRole.appLocaleFile],
        contains("const appLocales = <Locale>[Locale('en'), Locale('de')];"),
      );
      expect(entries.single.socket, AppEntryRole.infoPlist);
      expect(entries.single.entryValue, const PlistStringArray(['en', 'de']));

      // The section names each of them, and what goes there.
      for (final named in [
        LocalizationRole.appLocaleFile,
        'appLocales',
        "Locale('de')",
        AppEntryRole.infoPlistFile,
        entries.single.entryKey!,
        'de',
      ]) {
        expect(text, contains('`$named`'), reason: named);
      }
    });
  });
}
