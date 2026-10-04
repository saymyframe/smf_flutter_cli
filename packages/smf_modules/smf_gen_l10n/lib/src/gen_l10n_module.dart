import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_gen_l10n/bundles/gen_l10n_bundle.dart';

/// The module that keeps the texts of the app in ARB files, from which
/// gen-l10n of Flutter generates the code that reads them, and so provides
/// the localization role.
///
/// The template of the role generates the languages of the app and the
/// language that the user chose, and gives the root of the app its locale,
/// its supported locales and the delegates of Flutter's own localizations.
/// This module adds:
/// - `l10n.yaml`, the options of gen-l10n, and `generate: true` in the
///   pubspec, with which `flutter pub get` and `flutter run` generate the
///   `AppLocalizations` class in [arbDirectory];
/// - an ARB file in [arbDirectory] for each language of the app: the
///   template, [templateArbFile], with every text of the app in English,
///   and the file of each other language with the texts that have a
///   translation into it, so that a text without one reads in English;
/// - `lib/core/l10n/l10n.dart` with the extension that the role requires,
///   whose getter `l10n` returns the `AppLocalizations` of a context;
/// - the delegate of `AppLocalizations` among the `localizationsDelegates`
///   of the root of the app;
/// - a section of the README of the app that tells how to add a text and a
///   language.
///
/// The ARB files come from the render hook of the module, since the app
/// has one for each of its languages. SMF never writes the code that reads
/// them: `smf create` runs `flutter pub get` in the new app, which
/// generates it.
final class GenL10nModule extends SmfModule {
  /// Creates the module.
  const GenL10nModule();

  /// The id of the module.
  static const id = ModuleId('gen_l10n');

  /// The directory of the ARB files of the app, in which gen-l10n writes
  /// the code it generates from them.
  static const arbDirectory = 'lib/l10n';

  /// The path of the ARB file with every text of the app in English, the
  /// template of gen-l10n.
  static const templateArbFile = '$arbDirectory/app_en.arb';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Texts in ARB files with gen-l10n of Flutter',
        kind: ModuleKinds.infrastructure,
        providers: [_GenL10nProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(genL10nBundle),
        const PubspecContribution.flutter(generate: true),
        // The code that gen-l10n generates imports intl, in the version
        // that flutter_localizations of the Flutter SDK pins.
        const PubspecContribution.hosted('intl', 'any'),
        const SocketContribution.arg(
          AppEntryRole.appArgs,
          'localizationsDelegates',
          Fragment(
            'AppLocalizations.delegate',
            imports: [ImportRef.app('l10n/app_localizations.dart')],
          ),
        ),
        AppEntryRole.readmeSections.entry('Languages', _readmeSection),
      ];
}

/// The section of the module in the README of the app: where the texts of
/// the app are, and how to add a text and a language.
const _readmeSection = '''
The texts of the app are in the ARB files of `${GenL10nModule.arbDirectory}`, one for each language. `${GenL10nModule.templateArbFile}` has every text in English, and the file of another language, such as `app_uk.arb`, has the translations into it. `flutter pub get` and `flutter run` generate the `AppLocalizations` class from these files with [gen-l10n](https://docs.flutter.dev/ui/internationalization), as `l10n.yaml` says. Code reads a text as `context.l10n.<name>` with `${LocalizationRole.textsFile}` imported, where `context` is a `BuildContext` below the root of the app.

To add a text, add it to `${GenL10nModule.templateArbFile}` under a name of its own, and its translations under the same name to the files of the other languages. A text without a translation into a language reads in English there.

To add a language in which Flutter has the texts of its own widgets, such as German:

1. Add `${GenL10nModule.arbDirectory}/app_de.arb` with `"@@locale": "de"` and the translations.
2. Add `Locale('de')` to `appLocales` in `${LocalizationRole.appLocaleFile}`.
3. Add `de` to `CFBundleLocalizations` in `${AppEntryRole.infoPlistFile}`, which tells iOS the languages of the app.
''';

/// The members that gen-l10n declares in `AppLocalizations`, which no text
/// can be named after: the class would declare the name twice.
const _membersOfAppLocalizations = {
  'localeName',
  'of',
  'delegate',
  'localizationsDelegates',
  'supportedLocales',
};

final class _GenL10nProvider extends RoleProvider<TextsData> {
  const _GenL10nProvider();

  @override
  Role<TextsData> get role => localizationRole;

  @override
  List<SmfIssue> validate(RoleHookInput<TextsData> input) => [
        for (final text in localizationRole.textsIn(input))
          if (_membersOfAppLocalizations.contains(text.getter))
            SmfIssue(
              'The $text would be read as context.l10n.${text.getter}, but '
              'the class that gen-l10n generates for the texts of the app '
              'has a member ${text.getter} of its own.',
              hint: 'Rename the text.',
              origin: text.owner,
            ),
      ];

  @override
  RoleOutput render(RoleHookInput<TextsData> input) {
    final texts = localizationRole.textsIn(input);
    return RoleOutput(
      files: {
        for (final language in localizationRole.localesIn(input))
          '${GenL10nModule.arbDirectory}/app_$language.arb':
              _arbOf(language, texts),
      },
    );
  }
}

/// The ARB file of [language]: its locale, and each of [texts] that is in
/// that language, by the name of its getter, in their order.
String _arbOf(String language, List<AppText> texts) {
  final messages = <String, String>{
    '@@locale': language,
    for (final text in texts)
      if (text.text.textIn(language) case final translation?)
        text.getter: translation,
  };
  return '${const JsonEncoder.withIndent('  ').convert(messages)}\n';
}
