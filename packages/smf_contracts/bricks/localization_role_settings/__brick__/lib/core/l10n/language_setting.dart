import 'package:flutter/material.dart';

import 'app_locale.dart';

/// The names of the languages of the app, each in its own language, by the
/// code of the language. The setting shows a language of the app without a
/// name here by its code: add the name of such a language.
const _names = <String, String>{
{{{locale_names}}}
};

/// The setting of the language of the app, an entry of the settings screen:
/// it shows the language that the user chose, and opens a sheet in which
/// the user chooses one of the languages of the app, or follows the
/// languages of the device.
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final chosen = AppLocaleScope.of(context);
    final choice = Text(
      chosen == null ? {{{text_system}}} : _nameOf(chosen),
      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
    );
    final arrow = Icon(Icons.chevron_right, color: muted);
    // At a large text size, the choice goes below the title, where it has
    // the width of the row.
    final below = MediaQuery.textScalerOf(context).scale(10) > 13;
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text({{{text_language}}}),
      subtitle: below ? choice : null,
      trailing: below
          ? arrow
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [choice, const SizedBox(width: 4), arrow],
            ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        // Over the main navigation of the app too.
        useRootNavigator: true,
        showDragHandle: true,
        builder: (context) => const _LanguageSheet(),
      ),
    );
  }
}

/// The name of the language of [locale] in that language, or its code.
String _nameOf(Locale locale) =>
    _names[locale.languageCode] ?? locale.languageCode;

/// The sheet of the setting: the choice between the languages of the app
/// and those of the device. It scrolls where its options do not fit.
class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = AppLocaleScope.of(context);
    return SafeArea(
      child: ListView(
        // A drag of options that fit closes the sheet, as a drag of its
        // handle does.
        primary: false,
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Semantics(
              header: true,
              child: Text(
                {{{text_language}}},
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),
          for (final Locale? locale in [null, ...appLocales])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 4,
              ),
              title: Text(
                locale == null ? {{{text_system}}} : _nameOf(locale),
                // Larger than the text of a row of the screen.
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 19),
              ),
              selected: locale == chosen,
              trailing: locale == chosen
                  ? Icon(
                      Icons.check_rounded,
                      color: theme.colorScheme.secondary,
                    )
                  : null,
              onTap: () async {
                Navigator.of(context).pop();
                await appLocale.choose(locale);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
