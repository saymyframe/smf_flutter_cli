import 'package:flutter/material.dart';

import 'app_locale.dart';

/// The names of the languages of the app, each in its own language, by the
/// code of the language. The setting shows a language of the app without a
/// name here by its code: add the name of such a language.
const _names = <String, String>{
{{{locale_names}}}
};

/// The setting of the language of the app, an entry of the settings screen:
/// it shows the language that the user chose, and lets the user choose one
/// of the languages of the app, or follow the languages of the device.
///
/// The entry does not wait until a choice is saved. If the preferences fail
/// to save it, the app is in the chosen language while it runs, its next
/// launch starts with what was saved before, and the error is one that
/// nothing here catches: it reaches the handlers of the uncaught errors of
/// the app.
class LanguageSetting extends StatelessWidget {
  /// Creates the setting.
  const LanguageSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final chosen = AppLocaleScope.of(context);
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text({{{text_language}}}),
      subtitle: Text(chosen == null ? {{{text_system}}} : _nameOf(chosen)),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => const _LanguageDialog(),
      ),
    );
  }
}

/// The name of the language of [locale] in that language, or its code.
String _nameOf(Locale locale) =>
    _names[locale.languageCode] ?? locale.languageCode;

/// The choice between the languages of the app and those of the device.
class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context) {
    final chosen = AppLocaleScope.of(context);
    return SimpleDialog(
      title: Text({{{text_language}}}),
      children: [
        for (final Locale? locale in [null, ...appLocales])
          ListTile(
            title: Text(locale == null ? {{{text_system}}} : _nameOf(locale)),
            selected: locale == chosen,
            trailing: locale == chosen ? const Icon(Icons.check) : null,
            onTap: () async {
              Navigator.of(context).pop();
              await appLocale.choose(locale);
            },
          ),
      ],
    );
  }
}
