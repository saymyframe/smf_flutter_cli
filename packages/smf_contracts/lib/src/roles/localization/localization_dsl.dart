part of '../localization.dart';

/// The code of English, the language of every text.
const _english = 'en';

final RegExp _textName = RegExp(r'^[a-z][a-zA-Z0-9]*$');

final RegExp _languageCode = RegExp(r'^[a-z]{2,3}$');

/// The texts that a module, or the template of a role, gives the app: the
/// data of the [LocalizationRole].
///
/// ```dart
/// localizationRole.data(
///   const TextsData([
///     LocalizedText(
///       'title',
///       en: 'Settings',
///       translations: {'uk': 'Налаштування'},
///     ),
///   ]),
/// )
/// ```
@immutable
final class TextsData {
  /// Creates the data with the [texts] of one owner.
  const TextsData(this.texts);

  /// The texts, each with a name of its own among them.
  final List<LocalizedText> texts;
}

/// The data of a role other than the [LocalizationRole] with texts that a
/// user sees, such as the routes of a module, whose destinations of the
/// main navigation have labels.
///
/// The role that takes such data requires or uses the [LocalizationRole],
/// and its template reads each text with [LocalizationRole.expressionOf],
/// as a text of the module that gave the data. A module that lists the
/// [LocalizationRole] among its roles gives that role each of these texts
/// too, among its [TextsData], and the app then shows the text in its
/// language: the rule `localization.texts` reports a text of such data that
/// the module did not give the role, or gave it otherwise. The texts of a
/// module that does not list the role are in English in every app, so they
/// have no translations: the module rule of the role of the data reports
/// one that has, with [LocalizationRole.dataTextProblems].
abstract interface class DataWithTexts {
  /// The texts of the data that a user sees.
  Iterable<LocalizedText> get shownTexts;
}

/// A text of the app that a user sees, in English and in the other
/// languages of its owner.
///
/// It has no parameters and no plural forms, so neither its English text
/// nor a translation has a `{` or a `}`, which mark a parameter in the
/// formats of translations. A text of nothing but spaces is no text.
@immutable
final class LocalizedText {
  /// Creates the text [name] that reads [en] in English.
  const LocalizedText(
    this.name, {
    required this.en,
    this.translations = const {},
  });

  /// The name of the text among those of its owner, a lowerCamelCase
  /// identifier such as `title`.
  ///
  /// Names that differ only in case, such as `userId` and `userID`, are
  /// one name: they would have one brick variable (see
  /// [LocalizationRole.varsOf]).
  final String name;

  /// The text in English, which the app shows in every language that the
  /// text has no translation into, and in an app without the
  /// [LocalizationRole].
  final String en;

  /// The text in other languages, by the code of each: two or three
  /// lowercase letters, such as `uk`, without a region.
  ///
  /// An app is in a language only if Flutter has the texts of its own
  /// widgets in it (see [LocalizationRole.supportedLanguages]), so the role
  /// leaves a translation into any other language out of the app.
  final Map<String, String> translations;

  /// The codes of the languages that the text is in, English first.
  List<String> get languages => [_english, ...translations.keys];

  /// The text in the language of the code [language], or `null` if it has
  /// no translation into it.
  String? textIn(String language) =>
      language == _english ? en : translations[language];

  /// Describes what is wrong with the text, or returns an empty list.
  List<String> problems() {
    final what = 'The text "$name"';
    final problems = <String>[];
    if (!_textName.hasMatch(name)) {
      problems.add(
        '$what needs a name that is a lowerCamelCase identifier, such as '
        'title.',
      );
    }
    if (en.trim().isEmpty) problems.add('$what has no English text.');
    for (final language in translations.keys) {
      if (language == _english) {
        problems.add(
          '$what has a translation into en, but its English text is the '
          'text itself.',
        );
      } else if (!_languageCode.hasMatch(language)) {
        problems.add(
          '$what has a translation into "$language", which is not the code '
          'of a language: two or three lowercase letters, such as uk.',
        );
      }
      if (translations[language]!.trim().isEmpty) {
        problems.add(
          '$what has an empty translation into $language; leave a language '
          'out to read the text in English there.',
        );
      }
    }
    for (final language in languages) {
      if (textIn(language)!.contains(RegExp('[{}]'))) {
        problems.add(
          '$what has a brace in its text in $language; a text takes no '
          'parameters, so it has neither { nor }.',
        );
      }
    }
    return problems;
  }

  @override
  String toString() => 'text $name';
}

/// A text of the app: a [LocalizedText] with its owner, and the getter that
/// reads it.
///
/// Obtain the texts of an app with [LocalizationRole.textsIn].
@immutable
final class AppText {
  const AppText._(this.owner, this.text);

  /// Who gave the app the text: a module, also for a text of its variant,
  /// or the template of a role.
  final ContributionOrigin owner;

  /// The text.
  final LocalizedText text;

  /// The name of the getter that reads the text, as in
  /// `context.l10n.settingsTitle`: the id of the owner in lowerCamelCase,
  /// followed by the name of the text with its first letter in upper case.
  ///
  /// The ids of modules and roles differ, so the texts of two owners have
  /// one getter only when the id of one continues in the name of its text
  /// to the getter of the other, as `title` of `home_screen` and
  /// `screenTitle` of `home` do; the template of the role reports it.
  String get getter => _getterOf(owner, text.name);

  @override
  String toString() => '$text of ${_named(owner)}';
}

/// What the template of the [LocalizationRole] decides before rendering:
/// the languages of the app.
///
/// It is the result of the `choose` hook of the role; read it with
/// [LocalizationRole.localesIn].
@immutable
final class LocalizationChoice {
  /// Creates the choice of the languages with the codes [locales].
  const LocalizationChoice(this.locales);

  /// The codes of the languages of the app, such as `en` and `uk`: the app
  /// uses the first when the device asks for none of them.
  final List<String> locales;

  @override
  bool operator ==(Object other) =>
      other is LocalizationChoice &&
      other.locales.length == locales.length &&
      [
        for (final (index, locale) in locales.indexed)
          other.locales[index] == locale,
      ].every((same) => same);

  @override
  int get hashCode => Object.hashAll(locales);

  @override
  String toString() => 'the languages ${locales.join(', ')}';
}

/// The texts of [data], the data of the [LocalizationRole] in the order of
/// its owners, each with its owner.
List<AppText> _textsOf(Iterable<RoleData<TextsData>> data) => [
      for (final entry in data)
        for (final text in entry.value.texts)
          // Every data that a hook gets has an origin.
          AppText._(_ownerOf(entry.origin!), text),
    ];

/// Who owns the texts that [origin] gave: a variant of a module gives the
/// texts of its module.
ContributionOrigin _ownerOf(ContributionOrigin origin) => switch (origin) {
      ModuleOrigin(:final module) => ModuleOrigin(module),
      _ => origin,
    };

/// How a message names [owner], who gave the app a text or generated a
/// file that reads one.
String _named(ContributionOrigin owner) => switch (owner) {
      ModuleOrigin(:final module) => 'the module $module',
      RoleTemplateOrigin(:final role) => 'the template of the $role',
      PipelineOrigin() => 'the $owner',
    };

/// The name of the getter of the text [name] of [owner]; see
/// [AppText.getter].
///
/// Throws an [ArgumentError] for the pipeline, which has no texts.
String _getterOf(ContributionOrigin owner, String name) {
  final id = switch (owner) {
    ModuleOrigin(:final module) => module.value,
    RoleTemplateOrigin(:final role) => role.id,
    PipelineOrigin() => throw ArgumentError.value(
        owner,
        'owner',
        'The pipeline gives the app no texts',
      ),
  };
  // A text without a name has the problem that its owner is told of.
  final capitalized =
      name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}';
  return '${SmfNames.lowerCamelCase(id)}$capitalized';
}

/// The name of the brick variable that reads the text [name]; see
/// [LocalizationRole.varsOf].
String _variableOf(String name) => 'text_${SmfNames.snakeCaseOf(name)}';

/// The codes of the languages that [texts] are in and that an app can be in
/// (see [LocalizationRole.supportedLanguages]): English first, and then the
/// others in the order the texts name them.
List<String> _languagesOf(Iterable<AppText> texts) => {
      _english,
      for (final text in texts)
        for (final language in text.text.translations.keys)
          if (LocalizationRole.supportedLanguages.contains(language)) language,
    }.toList();

/// The problems of [texts], the texts of one owner: those of each text, two
/// texts of one name, and two whose names differ only in case, which would
/// have one brick variable.
List<String> _textProblems(List<LocalizedText> texts) {
  final problems = <String>[];
  final names = <String>{};
  final variables = <String, String>{};
  for (final text in texts) {
    problems.addAll(text.problems());
    if (!names.add(text.name)) {
      problems.add('Two texts are named "${text.name}".');
    } else if (_textName.hasMatch(text.name)) {
      final variable = _variableOf(text.name);
      final other = variables.putIfAbsent(variable, () => text.name);
      if (other != text.name) {
        problems.add(
          'The texts "$other" and "${text.name}" differ only in case, so '
          'both would have the brick variable $variable.',
        );
      }
    }
  }
  return problems;
}
