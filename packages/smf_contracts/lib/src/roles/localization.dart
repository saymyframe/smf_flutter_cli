import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/localization_role_bundle.dart';
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
/// - `appLocale`, the language that the user chose, or `null` while the app
///   follows the device, as a `ValueNotifier<Locale?>`;
/// - `AppLocaleScope`, the widget around the root of the app through which
///   the root reads `appLocale`, so that it rebuilds in the new language
///   when the choice changes.
///
/// It also gives the root `MaterialApp` its `locale`, its
/// `supportedLocales` and the delegates of Flutter's own localizations, and
/// names the languages of the app in the `Info.plist` of the iOS app. The
/// section [readmeHeading] of the README of the app, which the template
/// writes too, tells where the app keeps the list of its languages and
/// each place that a new language goes into. So a provider tells in a
/// section of its own only where its texts are, how to add one, and what
/// its texts need for a new language. In the guide for coding agents of
/// the app, the template writes the note of the role under its
/// description: how code reads a text, where the languages of the app are,
/// how code changes the language, and what a new language needs. A
/// provider adds what holds with its tool under the same heading.
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
/// those of the role alone. So a module gives its texts to the role: it
/// brings no delegate of texts of its own, which would have to know the
/// languages of the app, and adds no language to the root.
///
/// A module that only uses the role reads a text through a variable of
/// [varsOf], and the template of a role through a fragment of
/// [expressionOf]: either is `context.l10n.<getter>` in an app with the
/// role, and the English text as a literal in an app without it.
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
              'is its English text in an app without the role.',
          check: _checkTexts,
        ),
      ];

  @override
  List<StructuralRule<TextsData>> get structuralRules => const [
        StructuralRule(
          id: 'localization.text_access',
          description: 'Code of a module with the role among its roles '
              'reads only its own texts and those of the modules it depends '
              'on, and code of the template of a role that requires or uses '
              'the role only the texts of that template, each through its '
              'getter. The rule sees a text that code reads from context.l10n '
              'or from a variable called l10n, and no text that it reads '
              'through another expression.',
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

  /// The code that reads [text] of [owner], a module or the template of a
  /// role, for [input], the input of a hook of this role or of a role that
  /// requires or uses this role: `context.l10n.<getter>`, with the import
  /// of [textsFile], in an app with this role, and the English text as a
  /// literal in an app without it.
  ///
  /// The template of a role gives its brick the code as a fragment variable
  /// of its render hook, where its brick has a `BuildContext context` below
  /// the root `MaterialApp`, and not inside a `const` expression, since the
  /// code of an app with the role is no constant. The owner gives the role
  /// the text as data too, or the provider has no getter for it.
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
    return input.has(this)
        ? _read(getter)
        : Fragment(SmfNames.dartString(text.en));
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
