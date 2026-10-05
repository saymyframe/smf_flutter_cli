// The probe of the localization role, whichever module provides it, which
// the start check runs on a device once the first screen of the app
// settled, and whose checks the tests of the role run too (the files of
// test/localization_role): the root of the app supports the languages of
// the app and no other; for each of them, the root has a delegate of each
// kind of localizations that supports it; each text of the app reads in
// the language that the app is in, or in English when the text has no
// translation into it, while the app follows the device and once the user
// chose a language.
//
// It uses no test framework. The matrix writes texts.dart next to it, with
// the languages and the texts of the app from the data of its localization
// role. A choice of the language is saved in the preferences of the app,
// which on a device are the real ones, so the probe puts back the choice
// that it found.
import 'package:flutter/widgets.dart';
import 'package:{{app_name}}/core/l10n/app_locale.dart';

import 'texts.dart';

/// The probe of the start check: what is wrong with the languages of the
/// root of the app ([problemsOfSupportedLocales] and [problemsOfDelegates]),
/// or else what is wrong with the texts of the app in the language that the
/// probe finds the app in ([problemsOfTexts]), and then, once the user
/// chose each of the languages of [probedLanguages] in turn and the screen
/// settled with [settle], what is wrong with the app in that language
/// ([problemsOfLanguage]) and what Flutter reported on the way.
///
/// It goes through the first languages of the app only, those that the
/// matrix lists, since the screen settles once for each and the probes of
/// an app share their time. It does not put the app into a language while
/// the root cannot be in each of them, which would only throw. The errors
/// that Flutter reports while it goes through the languages come to it; it
/// puts back the handler of the errors of Flutter that it found, and the
/// choice of the user, when it is done, and tells when the app is then not
/// in the language that it found it in.
Future<List<String>> probeLanguages(Future<void> Function() settle) async {
  final ofRoot = [...problemsOfSupportedLocales(), ...problemsOfDelegates()];
  if (ofRoot.isNotEmpty) return ofRoot;

  // The language of the device, or of an earlier choice of the user.
  final found = languageOnScreen();
  final problems = [if (found != null) ...problemsOfTexts(found)];
  final reported = <String>[];
  final chosen = appLocale.value;
  final onError = FlutterError.onError;
  FlutterError.onError =
      (details) => reported.add(_firstLine(details.exceptionAsString()));
  try {
    for (final locale in appLocales) {
      if (!probedLanguages.contains(locale.languageCode)) continue;
      reported.clear();
      await appLocale.choose(locale);
      await settle();
      problems
        ..addAll(problemsOfLanguage(locale))
        ..addAll([
          for (final error in reported)
            'In ${locale.languageCode}, Flutter reported $error',
        ]);
    }
  } finally {
    FlutterError.onError = onError;
    await appLocale.choose(chosen);
    await settle();
  }
  final back = languageOnScreen();
  if (back != found) {
    problems.add(
      'The app is in ${back ?? 'no language'} rather than '
      '${found ?? 'no language'}, which the probe found it in, once the '
      'choice of the user is put back.',
    );
  }
  return problems;
}

/// What is wrong with the locales that the root of the app supports: they
/// are not the languages of the app, `appLocales`, or those are not the
/// languages that the localization role chose for the app, in their order.
List<String> problemsOfSupportedLocales() {
  final root = _rootOfApp();
  if (root == null) return [_noRoot];
  final ofApp = [for (final locale in appLocales) '$locale'];
  final supported = [for (final locale in root.supportedLocales) '$locale'];
  return [
    if (!_same(ofApp, appLanguages))
      'The languages of the app are $ofApp rather than those that the '
          'localization role chose, $appLanguages.',
    if (!_same(supported, ofApp))
      'The root of the app supports $supported rather than the languages of '
          'the app, $ofApp.',
  ];
}

/// The languages of the app that the root cannot be in, each with a kind
/// of localizations that no delegate of the root supports it for, as
/// Flutter loads them: for each kind, the first delegate that supports the
/// locale. So a root may have a delegate that does not support a language,
/// as the ones that `MaterialApp` adds for English, behind one of the same
/// kind that does.
List<String> problemsOfDelegates() {
  final root = _rootOfApp();
  if (root == null) return [_noRoot];
  final delegates = [...?root.localizationsDelegates];
  return [
    for (final locale in appLocales)
      for (final type in {for (final delegate in delegates) delegate.type})
        if (!delegates.any(
          (delegate) => delegate.type == type && delegate.isSupported(locale),
        ))
          'No delegate of $type of the root of the app supports $locale.',
  ];
}

/// What is wrong on the screen once the user chose [locale], one of the
/// languages of the app, and the screen settled: the app is in another
/// language, or a text of the app does not read as the localization role
/// has it in that language ([problemsOfTexts]).
List<String> problemsOfLanguage(Locale locale) {
  final language = locale.languageCode;
  final shown = languageOnScreen();
  return [
    if (shown != language)
      'The app is in ${shown ?? 'no language'} once the user chose $language.',
    ...problemsOfTexts(language),
  ];
}

/// The texts of the app that do not read on the screen as the localization
/// role has them in [language], the code of the language that the app is
/// in: each with what it reads, or what reading it throws.
List<String> problemsOfTexts(String language) {
  final context = _contextOnScreen();
  if (context == null) return [_noRoot];
  final problems = <String>[];
  for (final text in appTextChecks) {
    final problem = _problemOf(text, context, language);
    if (problem != null) problems.add(problem);
  }
  return problems;
}

/// The code of the language that the app is in where the user sees it, or
/// `null` if nothing is on the screen.
String? languageOnScreen() => switch (_contextOnScreen()) {
      null => null,
      final context => Localizations.maybeLocaleOf(context)?.languageCode,
    };

/// What is wrong with [text] read at [context] in [language], or `null`.
String? _problemOf(AppTextCheck text, BuildContext context, String language) {
  final expected = text.expected[language];
  final String read;
  try {
    read = text.read(context);
  } on Object catch (error) {
    return 'Reading the ${text.name} in $language threw ${_firstLine(error)}.';
  }
  return read == expected
      ? null
      : 'The ${text.name} reads "$read" in $language rather than "$expected".';
}

/// The problem that the app has no root on the screen.
const _noRoot = 'No root of the app is on the screen.';

/// The widget at the root of the app that takes its locales and the
/// delegates of its localizations, which `MaterialApp` and `CupertinoApp`
/// build, or `null` if none is on the screen.
WidgetsApp? _rootOfApp() {
  WidgetsApp? root;
  _visitOnScreen((element, depth) {
    if (root == null && element.widget is WidgetsApp) {
      root = element.widget as WidgetsApp;
    }
  });
  return root;
}

/// The element on the screen that is nested deepest, which is below the
/// root of the app and its localizations, or `null` if nothing is on the
/// screen.
BuildContext? _contextOnScreen() {
  Element? innermost;
  var deepest = -1;
  _visitOnScreen((element, depth) {
    if (depth > deepest) {
      innermost = element;
      deepest = depth;
    }
  });
  return innermost;
}

/// Calls [visit] with each element on the screen, the onstage ones, and its
/// depth in the tree, parents first.
void _visitOnScreen(void Function(Element element, int depth) visit) {
  void walk(Element element, int depth) {
    visit(element, depth);
    element.debugVisitOnstageChildren((child) => walk(child, depth + 1));
  }

  if (WidgetsBinding.instance.rootElement case final root?) walk(root, 0);
}

/// Whether [a] and [b] have the same items in the same order.
bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// The first line of the text of [error].
String _firstLine(Object error) => '$error'.trim().split('\n').first;
