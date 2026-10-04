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
/// English wherever it has no translation.
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
/// names the languages of the app in the `Info.plist` of the iOS app.
///
/// A provider generates [textsFile] with the extension [appTexts], whose
/// getter `l10n` returns an object with a `String` getter for each text of
/// [textsIn], named by its [AppText.getter]. Such a getter returns the text
/// in the language of the context, or in English when the text has no
/// translation into that language. The provider renders the texts in the
/// languages of [localesIn] only, and adds the delegate of its texts to the
/// `localizationsDelegates` of the root.
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
              'language, and no braces.',
          check: _checkTexts,
        ),
      ];

  @override
  List<StructuralRule<TextsData>> get structuralRules => const [
        StructuralRule(
          id: 'localization.text_access',
          description: 'Code of a module reads only its own texts and those '
              'of the modules it depends on, and code of the template of a '
              'role only the texts of that template, each through its '
              'getter.',
          check: _checkTextAccess,
        ),
      ];

  /// The texts of the app in [input], the input of a hook of this role, of
  /// its provider, or of a role that requires or uses this role: those of
  /// the modules, in the order the modules were selected, and then those of
  /// the templates of roles. The texts of one owner keep its order.
  List<AppText> textsIn(RoleHookInput<Object> input) => _textsOf(dataIn(input));

  /// The codes of the languages of the app in [input], the input of a hook
  /// of this role or of its provider, such as `en` and `uk`: the languages
  /// that the template chose, or, before the choice, every language that a
  /// text of the app is in, English first.
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
  /// the root `MaterialApp`. The owner gives the role the text as data too,
  /// or the provider has no getter for it.
  ///
  /// Throws an [ArgumentError] if the role of [input] neither requires nor
  /// uses this role, or if [owner] is the pipeline, which has no texts.
  Fragment expressionOf(
    RoleHookInput<Object> input,
    ContributionOrigin owner,
    LocalizedText text,
  ) {
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
  /// sections. The module lists this role among its roles and gives it the
  /// same [texts] as data.
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
