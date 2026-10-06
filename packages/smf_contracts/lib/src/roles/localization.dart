import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/localization_role_bundle.dart';
import 'package:smf_contracts/bundles/localization_role_settings_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

part 'localization/localization_dsl.dart';
part 'localization/localization_rules.dart';
part 'localization/localization_template.dart';

/// The localization role; see [LocalizationRole].
const localizationRole = LocalizationRole._();

/// The role of the languages of the app: the texts that a user sees, in the
/// language of the device or in the one the user chose.
///
/// A module, or the template of a role, gives the role its texts as
/// [TextsData], each a [LocalizedText] with its English text and its
/// translations. The role names every text apart from those of other
/// owners (see [AppText.getter]), and code reads a text as
/// `context.l10n.<getter>`, a `String` in the language of `context`, which
/// is the `BuildContext` of a widget below the root `MaterialApp`.
///
/// The languages of the app are those of [localesIn]: every language that a
/// text of the app is in, English first, or those of the option
/// [localesOption]. English is always one of them, since a text reads in
/// English wherever it has no translation. An app can be only in a language
/// in which Flutter has the texts of its own widgets (see
/// [supportedLanguages]), so the role leaves any other language of a text
/// out of the app, and tells whose text it is.
///
/// The role's template generates [appLocaleFile], whichever provider is
/// selected, with:
/// - `appLocales`, the languages of the app as `Locale`s, the first of
///   which the app uses when the device asks for none of them;
/// - `appLocale`, which keeps the language that the user chose: its `value`
///   is one of `appLocales`, or `null` while the app follows the device,
///   and `choose()` changes it;
/// - `AppLocaleScope`, the widget around the root of the app through which
///   the root reads `appLocale`, so that it rebuilds in the new language
///   when the choice changes;
/// - `restoreAppLocale()`, the restorer of the choice.
///
/// It also gives the root `MaterialApp` its `locale`, its
/// `supportedLocales` and the delegates of Flutter's own localizations, and
/// names the languages of the app in the `Info.plist` of the iOS app. The
/// section [readmeHeading] of the README of the app, which the template
/// writes too, tells where the app keeps the list of its languages, how
/// the app comes to be in another of them, which it remembers, and each
/// place that a new language goes into; in an app with a settings screen,
/// the setting of the language is one of them. So a provider tells in a
/// section of its own only where its texts are, how to add one, and what
/// its texts need for a new language. In the guide for coding agents of
/// the app, the template writes the note of the role under its
/// description: how code reads a text, where the languages of the app are,
/// how code changes the language, and what a new language needs. In an app
/// with a settings screen, a second note tells where the setting of the
/// language takes the name of a language from. A provider adds what holds
/// with its tool under the same heading.
///
/// The app remembers the language that the user chose, so the role requires
/// the [PreferencesRole]. `appLocale.choose()` takes one of `appLocales`, or
/// a locale of the language of one of them, which then is the choice, and
/// refuses a locale of another language with an [ArgumentError]. A choice
/// is saved under [localeKey] as the code of the language, and removed when
/// the app follows the device again. The template gives the preferences
/// `restoreAppLocale()` as a restorer, which reads the saved choice before
/// the first frame; a code that is none of the languages of the app counts
/// as nothing saved. A choice before the app opened its preferences changes
/// only memory.
///
/// The language changes before the choice is saved. So when the preferences
/// fail to save it, the future of `choose()` completes with their error,
/// the app stays in the new language while it runs, and its next launch
/// starts with what was saved before; choosing the language again saves it
/// again. Code that does not await the future leaves the error to the
/// handlers of the errors of the app, such as its crash reporting, as the
/// setting of the language does.
///
/// In an app with a settings screen, which the role uses (see
/// [SettingsScreenRole]), the template adds [languageSettingFile] with
/// `LanguageSetting`, an entry of the settings screen that shows the choice
/// and lets the user change it: one of the languages of the app, or the
/// languages of the device. It reads the choice from `AppLocaleScope` and
/// changes it with `appLocale.choose()`. The texts of the entry,
/// [languageSettingTitle] and [languageOfDevice], are texts of the template
/// of the role, which it gives the role only in such an app.
///
/// The entry shows a language by its name in that language when the role
/// has one, which it has for the languages of [languageNames], English and
/// Ukrainian, and any other language of the app by its code. The choice of
/// the languages warns of each such language of an app with a settings
/// screen: the developer of the app adds its name to `_names` in
/// [languageSettingFile].
///
/// A provider generates [textsFile] with the extension [appTexts], whose
/// getter `l10n` returns an object with a `String` getter for each text of
/// [textsIn], named by its [AppText.getter]. Such a getter returns the text
/// in the language of the context, or in English when the text has no
/// translation into that language. The provider renders the texts in the
/// languages of [localesIn] only, each under the name of its getter in a
/// file of its own, and its texts follow the locale of the root of the
/// app: `context.l10n` works in every context below the root, in the
/// language that the root is in, also once that language changes. How its
/// texts get there is the provider's choice. One that loads them with a
/// delegate, written by hand or by a tool, adds the delegate to the
/// `localizationsDelegates` of the root, and one that reads the locale of
/// the context itself needs none.
///
/// Every delegate among the `localizationsDelegates` of the root supports
/// each language of the app, and the `supportedLocales` of the root are
/// those of the role alone: the argument takes the items of one
/// contributor, so the pipeline reports a module that gives the root a
/// locale of its own in an app with the role as a conflict with the role.
/// So a module gives its texts to the role: it brings no delegate of texts
/// of its own, which would have to know the languages of the app, and adds
/// no language to the root.
///
/// A module that only uses the role reads a text through a variable of
/// [varsOf], and the template of a role through a fragment of
/// [expressionOf]: either is `context.l10n.<getter>` in an app with the
/// role, and the English text as a literal in an app without it.
///
/// The data that a module gives another role may have texts too, such as
/// the label of a destination of the main navigation in its routes (see
/// [DataWithTexts]). The template of that role reads such a text with
/// [expressionOf] as well, as a text of the module. A module that lists
/// this role among its roles gives it each of these texts too, among its
/// [TextsData], and the app shows them in its language. The texts of a
/// module that does not are in English in every app, so they take no
/// translations (see [dataTextProblems]).
final class LocalizationRole extends Role<TextsData> {
  const LocalizationRole._();

  /// The path of the file with `appLocales`, `appLocale` and
  /// `AppLocaleScope`.
  static const appLocaleFile = 'lib/core/l10n/app_locale.dart';

  /// The path of the provider's file with [appTexts].
  static const textsFile = 'lib/core/l10n/l10n.dart';

  /// The heading of the section of the README of the app in which the
  /// template tells where the languages of the app are and how to add one.
  /// The section of a provider on its texts can refer to it.
  static const readmeHeading = 'Languages';

  /// The path of the file with `LanguageSetting`, the entry of the settings
  /// screen, which the template generates only in an app with a settings
  /// screen.
  static const languageSettingFile = 'lib/core/l10n/language_setting.dart';

  /// The key of the preferences of the app under which the app saves the
  /// language that the user chose, as the code of the language, such as
  /// `uk`, as text. Nothing is saved under it while the app follows the
  /// languages of the device. The file of the role keeps the key to itself,
  /// so a test of an app takes it from here.
  static const localeKey = 'localization.locale';

  /// The title of the setting of the language, a text of the template of
  /// the role in an app with a settings screen.
  static const languageSettingTitle = LocalizedText(
    'language',
    en: 'Language',
    translations: {'uk': 'Мова'},
  );

  /// The option of the setting of the language with which the app follows
  /// the languages of the device, which the setting also shows while the
  /// app does; a text of the template of the role in an app with a settings
  /// screen.
  static const languageOfDevice = LocalizedText(
    'system',
    en: 'System',
    translations: {'uk': 'Як у системі'},
  );

  /// The names of the languages that the setting of the language can name,
  /// each in that language, by the code of the language. The setting shows
  /// any other language of the app by its code, until the developer of the
  /// app adds its name to `_names` in [languageSettingFile].
  static const languageNames = {'en': 'English', 'uk': 'Українська'};

  /// The extension on `BuildContext` that every provider generates, whose
  /// getter `l10n` gives the texts of the app in the language of the
  /// context: `context.l10n.settingsTitle`.
  ///
  /// Import it with [RequiredSymbol.importRef].
  static const appTexts = RequiredExtension(
    'AppTexts',
    path: textsFile,
    on: 'BuildContext',
    getters: ['l10n'],
  );

  /// The codes of the languages that an app can be in: those in which
  /// Flutter has the texts of its own widgets. The template of the role
  /// gives the root of the app the three delegates of those texts, and in a
  /// language that one of them lacks the Material widgets that need their
  /// texts throw.
  ///
  /// It is the set of Flutter 3.44, the oldest Flutter that SMF generates
  /// apps for: the languages that `kMaterialSupportedLanguages`,
  /// `kCupertinoSupportedLanguages` and `kWidgetsSupportedLanguages` of its
  /// `flutter_localizations` all have. A later Flutter has each of them
  /// too. `Locale` keeps the code of each as it is, which it does not for a
  /// code that it replaces, such as `iw`, which it reads as `he`.
  static const Set<String> supportedLanguages = {
    'af', 'am', 'ar', 'as', 'az', 'be', 'bg', 'bn', 'bo', 'bs', 'ca', 'cs', //
    'cy', 'da', 'de', 'el', 'en', 'es', 'et', 'eu', 'fa', 'fi', 'fil', 'fr',
    'ga', 'gl', 'gsw', 'gu', 'he', 'hi', 'hr', 'hu', 'hy', 'id', 'is', 'it',
    'ja', 'ka', 'kk', 'km', 'kn', 'ko', 'ky', 'lo', 'lt', 'lv', 'mk', 'ml',
    'mn', 'mr', 'ms', 'my', 'nb', 'ne', 'nl', 'no', 'or', 'pa', 'pl', 'pt',
    'ro', 'ru', 'si', 'sk', 'sl', 'sq', 'sr', 'sv', 'sw', 'ta', 'te', 'th',
    'tl', 'tr', 'ug', 'uk', 'ur', 'uz', 'vi', 'zh', 'zu',
  };

  /// `--locales`, the codes of the languages of the app with commas between
  /// them, such as `en,uk`.
  static const localesOption = RoleOption(
    name: 'locales',
    valueHelp: 'codes',
    help: 'The languages of the app among those of the texts of its modules, '
        'such as en,uk: the first is the one the app uses when the device '
        'asks for none of them. All of them by default, English first.',
  );

  @override
  String get id => 'localization';

  @override
  String get description => 'Localization';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get requires => const {preferencesRole};

  @override
  Set<Role> get uses => const {settingsScreenRole};

  @override
  RoleInterface get interface => const RoleInterface(
        files: [appLocaleFile],
        symbols: [appTexts],
      );

  @override
  List<RoleOption> get options => const [localesOption];

  @override
  RoleTemplate<TextsData> get template => const _LocalizationTemplate();

  @override
  List<ModuleRule<TextsData>> get moduleRules => const [
        ModuleRule(
          id: 'localization.texts',
          description: 'The texts of a module have lowerCamelCase names that '
              'differ, an English text, translations by the code of their '
              'language, and no braces. A variable of a brick of the module '
              'that reads a text of the app reads one that the app has, and '
              'is its English text in an app without the role. A text that '
              'the module gives another role in its data, such as the label '
              'of a destination, is one of the texts that it gives the role.',
          check: _checkTexts,
        ),
      ];

  @override
  List<StructuralRule<TextsData>> get structuralRules => const [
        StructuralRule(
          id: 'localization.text_access',
          description: 'Code of a module with the role among its roles '
              'reads only its own texts and those of the modules it depends '
              'on, each through its getter. Code of the template of a role '
              'that requires or uses the role reads its own texts and, of '
              'the texts of the modules, those that the modules give in '
              'their data to its role or to a role that its role requires '
              'or uses, such as the label of a destination. The rule does '
              'not tell a read that a template of a brick has in its own '
              'code from one that a render hook wrote for that data, so a '
              'template that names such a text of a module passes in an '
              'app with the module; in an app without it, the app lacks the '
              'text and the rule reports the read. The rule sees a text '
              'that code reads from context.l10n or from a variable called '
              'l10n, and no text that it reads through another expression.',
          check: _checkTextAccess,
        ),
        StructuralRule(
          id: 'localization.texts_rendered',
          description: 'A file of the provider of the role names the getter '
              'of every text of the app.',
          check: _checkTextsRendered,
        ),
      ];

  /// The texts of the app in [input], the input of a hook of this role, of
  /// its provider, or of a role that requires or uses this role: those of
  /// the modules, in the order the modules were selected, and then those of
  /// the templates of roles. The texts of one owner keep its order.
  List<AppText> textsIn(RoleHookInput<Object> input) => _textsOf(dataIn(input));

  /// The codes of the languages of the app in [input], the input of a hook
  /// of this role or of its provider, such as `en` and `uk`: the languages
  /// that the template chose, or, before the choice, every language of
  /// [supportedLanguages] that a text of the app is in, English first.
  List<String> localesIn(RoleHookInput<TextsData> input) =>
      switch (input.choice) {
        LocalizationChoice(:final locales) => locales,
        _ => _languagesOf(textsIn(input)),
      };

  /// The text of the app in [input], the input of a hook of this role or
  /// of a role that requires or uses this role, that [owner] gave this role
  /// under the name of [text], or `null` if it gave none: as in an app
  /// without this role, and as a module that does not list this role among
  /// its roles.
  ///
  /// So the app shows [text] of [owner] in its language when this returns a
  /// text, and in English in every language when it returns `null`.
  AppText? appTextOf(
    RoleHookInput<Object> input,
    ContributionOrigin owner,
    LocalizedText text,
  ) {
    final of = _ownerOf(owner);
    for (final given in textsIn(input)) {
      if (given.owner == of && given.text.name == text.name) return given;
    }
    return null;
  }

  /// The code that reads [text] of [owner], for [input], the input of a
  /// hook of this role or of a role that requires or uses this role:
  /// `context.l10n.<getter>`, with the import of [textsFile], or the
  /// English text as a literal.
  ///
  /// The template of a role gives its brick the code as a fragment variable
  /// of its render hook, where its brick has a `BuildContext context` below
  /// the root `MaterialApp`, and not inside a `const` expression, since the
  /// code of an app with the role is no constant. Which of the two the code
  /// is depends on whose text it is:
  /// - A text of the template itself, which [owner] then is, reads from the
  ///   texts of the app in every app with this role. The template gives
  ///   this role the text as data too, or the provider has no getter for
  ///   it, which the rule `localization.text_access` reports.
  /// - A text of a module, which the module gave the role of the template
  ///   in its data (see [DataWithTexts]), such as the label of a
  ///   destination, reads from the texts of the app only when the module
  ///   gave this role the text too (see [appTextOf]). The text of a module
  ///   that does not list this role among its roles is the literal in
  ///   every app, so the app never reads a text that it lacks.
  ///
  /// In an app without this role, the code is the literal for both.
  ///
  /// Throws an [ArgumentError] if the role of [input] neither requires nor
  /// uses this role, if [owner] is the pipeline, which has no texts, or
  /// with the problems of [text], if it has any, so that the hook fails in
  /// every app, with or without this role.
  Fragment expressionOf(
    RoleHookInput<Object> input,
    ContributionOrigin owner,
    LocalizedText text,
  ) {
    final problems = text.problems();
    if (problems.isNotEmpty) throw ArgumentError(problems.join(' '));
    final getter = _getterOf(owner, text.name);
    final reads = switch (owner) {
      ModuleOrigin() => appTextOf(input, owner, text) != null,
      _ => input.has(this),
    };
    return reads ? _read(getter) : Fragment(SmfNames.dartString(text.en));
  }

  /// The problems of [text], a text that the module [module] gives another
  /// role in its data (see [DataWithTexts]), for the module rule of that
  /// role: those of the text itself, and translations that no app would
  /// show, since [module] does not list this role among its roles, so that
  /// its texts are in English in every app.
  ///
  /// A module that lists this role gives it the text too, which the rule
  /// `localization.texts` of this role checks in every app with this role.
  List<String> dataTextProblems(ModuleDescriptor module, LocalizedText text) {
    final problems = text.problems();
    final languages = text.translations.keys;
    if (languages.isEmpty || module.roles.contains(this)) return problems;
    final one = languages.length == 1;
    problems.add(
      'The text "${text.name}" has '
      '${one ? 'a translation' : 'translations'} into '
      '${languages.join(', ')}, but the module ${module.id} does not list '
      'the $this among its roles, so every app would show the text in '
      'English. Add the role to the uses of the module and give it the text '
      'among the texts of the module, or leave the '
      '${one ? 'translation' : 'translations'} out.',
    );
    return problems;
  }

  /// The variables that read the [texts] of [module] in a brick of the
  /// module: for each text, `text_<name>` with the name in snake_case, such
  /// as `text_open_details` for `openDetails`.
  ///
  /// Each is a [RoleVar] of this role: `context.l10n.<getter>` with the
  /// import of [textsFile] in an app with the role, and the English text as
  /// a literal in an app without it. So a template reads `{{{text_title}}}`
  /// where its code has a `BuildContext context` below the root
  /// `MaterialApp`, as in `Text({{{text_title}}})`, outside mustache
  /// sections and not inside a `const` expression, since the code of an app
  /// with the role is no constant. The module lists this role among its
  /// roles and gives it the same [texts] as data: the rule
  /// `localization.texts` reports a variable whose text the app lacks, or
  /// whose English text differs from that of the data.
  ///
  /// Throws an [ArgumentError] with the problems of [texts], if they have
  /// any, so that the module fails to contribute in every app, with or
  /// without this role.
  Map<String, RoleVar> varsOf(ModuleId module, TextsData texts) {
    final problems = _textProblems(texts.texts);
    if (problems.isNotEmpty) throw ArgumentError(problems.join(' '));
    final owner = ModuleOrigin(module);
    return {
      for (final text in texts.texts)
        _variableOf(text.name): RoleVar(
          this,
          present: _read(_getterOf(owner, text.name)),
          absent: SmfNames.dartString(text.en),
        ),
    };
  }
}

/// The code that reads the text of [getter] from the texts of the app.
Fragment _read(String getter) => Fragment(
      'context.l10n.$getter',
      imports: [LocalizationRole.appTexts.importRef],
    );
