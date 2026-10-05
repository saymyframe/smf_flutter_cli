part of '../localization.dart';

const _appLocale = ImportRef.app('core/l10n/app_locale.dart');

const _flutterLocalizations = ImportRef(
  'package:flutter_localizations/flutter_localizations.dart',
);

/// The delegates of Flutter's own localizations, which support every
/// language that Flutter's widgets are translated into.
const _flutterDelegates = [
  'GlobalMaterialLocalizations.delegate',
  'GlobalWidgetsLocalizations.delegate',
  'GlobalCupertinoLocalizations.delegate',
];

/// The key of the `Info.plist` of the iOS app with the languages of the
/// app.
const _plistLanguages = 'CFBundleLocalizations';

/// The section of the role in the README of the app: where the languages of
/// the app are, and each place that a new language goes into, whichever
/// module provides the role.
const _readmeSection = '''
The app is in the languages of `appLocales` in `${LocalizationRole.appLocaleFile}`. It shows its texts in the language that the device prefers among them, and in the first of the list when the device asks for none of them.

To add a language in which Flutter has the texts of its own widgets, such as German, add the texts of the app in German, and then:

1. Add `Locale('de')` to `appLocales`.
2. Add `de` to `$_plistLanguages` in `${AppEntryRole.infoPlistFile}`, which tells iOS the languages of the app.
''';

/// The note of the localization role in the guide for coding agents: how
/// code shows a text, where the languages of the app are, how code changes
/// the language, and what a new language needs, whichever module provides
/// the role.
const _agentNote = '''
- Show the user no text from a string literal. Read each text as `context.l10n.<name>`, with `${LocalizationRole.textsFile}` imported, where `context` is a `BuildContext` below the root of the app. Such an expression is no constant, so the widget around it cannot be `const`.
- `appLocales` in `${LocalizationRole.appLocaleFile}` lists the languages of the app. The app is in the one that the device prefers among them, and in the first of the list when the device asks for none of them.
- `appLocale` in that file holds the language that the user chose, or `null` while the app follows the device. Set `appLocale.value` to one of `appLocales`, or to `null`, and the root of the app rebuilds in that language. Pass no `locale` and no `supportedLocales` to the root `MaterialApp` anywhere else.
- Every delegate among the `localizationsDelegates` of the root has to support each language of `appLocales`. A new language, one in which Flutter has the texts of its own widgets, goes into that list, into `$_plistLanguages` in the Info.plist of the iOS app, and into the texts of the app.
''';

/// The template of the [LocalizationRole]: the languages of the app, the
/// language that the user chose, what the root of the app needs to follow
/// it, and the note of the role for coding agents.
final class _LocalizationTemplate extends RoleTemplate<TextsData> {
  const _LocalizationTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(localizationRoleBundle),
        const PubspecContribution.sdk('flutter_localizations'),
        const SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'AppLocaleScope(notifier: appLocale, child: ',
            ')',
            imports: [_appLocale],
          ),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'locale',
          Fragment('AppLocaleScope.of(context)', imports: [_appLocale]),
        ),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'supportedLocales',
          Fragment('...appLocales', imports: [_appLocale]),
        ),
        for (final delegate in _flutterDelegates)
          SocketContribution.arg(
            AppEntryRole.appArgs,
            'localizationsDelegates',
            Fragment(delegate, imports: const [_flutterLocalizations]),
          ),
        AppEntryRole.readmeSections.entry(
          LocalizationRole.readmeHeading,
          _readmeSection,
        ),
        AppEntryRole.agentSections.entry(
          localizationRole.description,
          AgentNote.ofRole(_agentNote),
        ),
      ];

  /// Checks what the module rule `localization.texts` cannot see from one
  /// module: the texts of the templates of roles, and the getters of the
  /// texts of all owners.
  @override
  List<SmfIssue> validate(RoleHookInput<TextsData> input) {
    final texts = localizationRole.textsIn(input);
    final ofTemplates = <ContributionOrigin, List<LocalizedText>>{};
    for (final text in texts) {
      if (text.owner is ModuleOrigin) continue;
      ofTemplates.putIfAbsent(text.owner, () => []).add(text.text);
    }
    final issues = <SmfIssue>[
      for (final MapEntry(key: owner, value: own) in ofTemplates.entries)
        for (final problem in _textProblems(own))
          SmfIssue(problem, origin: owner),
    ];

    // A getter joins the id of the owner and the name of the text, so texts
    // of different owners can need the same one.
    final byGetter = <String, AppText>{};
    for (final text in texts) {
      final getter = text.getter;
      if (_reservedGetters.contains(getter)) {
        issues.add(
          SmfIssue(
            'The $text would be read as context.l10n.$getter, which no '
            'getter of a text can be named.',
            hint: 'Rename the text.',
            origin: text.owner,
          ),
        );
      }
      final other = byGetter.putIfAbsent(getter, () => text);
      if (other.owner != text.owner) {
        issues.add(
          SmfIssue(
            'The $text and the $other both need the getter $getter.',
            hint: 'Rename one of the texts.',
            origin: text.owner,
          ),
        );
      }
    }
    return issues;
  }

  /// Chooses the languages of the app: those of `--locales`, or every
  /// language that a text of the app is in and that an app can be in (see
  /// [LocalizationRole.supportedLanguages]), English first. It asks
  /// nothing, and warns of the languages of the texts that it leaves out
  /// because no app can be in them, and of the texts that have no
  /// translation into a language of the app.
  @override
  Future<Object?> choose(RoleChoiceContext<TextsData> context) async {
    final texts = _textsOf(context.data);
    final available = _languagesOf(texts);
    final option = context.option(LocalizationRole.localesOption.name);
    final locales =
        option == null ? available : _chosen(option, available, texts);
    final warnings = [
      // With the option, the user chose the languages, and the option
      // takes none that an app cannot be in.
      if (option == null) ..._leftOut(texts),
      for (final language in locales) ..._untranslated(texts, language),
    ];
    if (warnings.isNotEmpty) {
      warnings.forEach(context.environment.logger.warn);
    }
    return LocalizationChoice(List.unmodifiable(locales));
  }

  /// The languages that [option], the value of `--locales`, names among
  /// the [available] ones, those of [texts] that an app can be in, in its
  /// order.
  List<String> _chosen(
    String option,
    List<String> available,
    List<AppText> texts,
  ) {
    const name = '--locales';
    final codes = [for (final code in option.split(',')) code.trim()];
    final languages = 'The app can be in ${available.join(', ')}.';
    if (codes.any((code) => code.isEmpty)) {
      throw SmfUsageException(
        '$name takes the codes of languages with commas between them, such '
        'as en,uk, not "$option". $languages',
      );
    }
    final ofTexts = {
      _english,
      for (final text in texts) ...text.text.translations.keys,
    };
    final unknown = [
      for (final code in codes)
        if (!ofTexts.contains(code)) code,
    ];
    if (unknown.isNotEmpty) {
      throw SmfUsageException(
        'No text of the app is in ${unknown.join(', ')}, which $name names. '
        '$languages',
      );
    }
    final unsupported = [
      for (final code in codes)
        if (!available.contains(code)) code,
    ];
    if (unsupported.isNotEmpty) {
      throw SmfUsageException(
        'The app cannot be in ${unsupported.join(', ')}, which $name names: '
        'Flutter has no texts for its own widgets in such a language. '
        '$languages',
      );
    }
    if (codes.toSet().length != codes.length) {
      throw SmfUsageException('$name names a language twice: $option.');
    }
    if (!codes.contains(_english)) {
      throw const SmfUsageException(
        '$name needs $_english: the app shows a text in English wherever it '
        'has no translation.',
      );
    }
    return codes;
  }

  /// A warning for each owner and each language of its texts among [texts]
  /// that no app can be in, which names the texts.
  List<String> _leftOut(List<AppText> texts) {
    final byOwner = <(ContributionOrigin, String), List<String>>{};
    for (final text in texts) {
      for (final language in text.text.translations.keys) {
        if (!LocalizationRole.supportedLanguages.contains(language)) {
          final key = (text.owner, language);
          byOwner.putIfAbsent(key, () => []).add(text.text.name);
        }
      }
    }
    String warning(
      ContributionOrigin owner,
      String language,
      List<String> names,
    ) =>
        'The app is not in $language, which '
        '${names.length == 1 ? 'the text' : 'the texts'} ${names.join(', ')} '
        'of ${_named(owner)} '
        '${names.length == 1 ? 'has a translation' : 'have translations'} '
        'into: Flutter has no texts for its own widgets in that language.';
    return [
      for (final MapEntry(key: (owner, language), value: names)
          in byOwner.entries)
        warning(owner, language, names),
    ];
  }

  /// A warning for each owner with texts among [texts] that have no
  /// translation into [language].
  List<String> _untranslated(List<AppText> texts, String language) {
    final byOwner = <ContributionOrigin, List<String>>{};
    for (final text in texts) {
      if (text.text.textIn(language) == null) {
        byOwner.putIfAbsent(text.owner, () => []).add(text.text.name);
      }
    }
    String warning(ContributionOrigin owner, List<String> names) =>
        'No translation into $language of '
        '${names.length == 1 ? 'the text' : 'the texts'} ${names.join(', ')} '
        'of ${_named(owner)}: the app shows '
        '${names.length == 1 ? 'it' : 'them'} in English there.';
    return [
      for (final MapEntry(key: owner, value: names) in byOwner.entries)
        warning(owner, names),
    ];
  }

  @override
  RoleOutput render(RoleHookInput<TextsData> input) {
    final locales = localizationRole.localesIn(input);
    return RoleOutput(
      vars: {
        'locales': [for (final code in locales) "Locale('$code')"].join(', '),
      },
      fragments: [
        // iOS shows the app in the languages that its bundle names.
        AppEntryRole.infoPlist.entry(
          _plistLanguages,
          PlistStringArray(locales),
        ),
      ],
    );
  }
}
