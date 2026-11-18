// ignore: deprecated_member_use
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
    final choice = chosen == null ? {{{text_system}}} : _nameOf(chosen);
    final style = theme.textTheme.bodyMedium?.copyWith(color: muted);
    final arrow = Icon(Icons.chevron_right, color: muted);
    // At a large text size, the choice goes below the title, where it has
    // the width of the row, and the two wrap between their words.
    final below = MediaQuery.textScalerOf(context).scale(10) > 13;
    return ListTile(
      leading: const Icon(Icons.language),
      title: _WholeWords({{{text_language}}}),
      subtitle: below
          ? DefaultTextStyle.merge(style: style, child: _WholeWords(choice))
          : null,
      trailing: below
          ? arrow
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(choice, style: style),
                const SizedBox(width: 4),
                arrow,
              ],
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
              child: DefaultTextStyle.merge(
                style: theme.textTheme.headlineSmall,
                child: _WholeWords({{{text_language}}}),
              ),
            ),
          ),
          for (final Locale? locale in [null, ...appLocales])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 4,
              ),
              // Larger than the text of a row of the screen, and so the
              // name of a language wraps between its words too.
              title: DefaultTextStyle.merge(
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 19),
                child: _WholeWords(
                  locale == null ? {{{text_system}}} : _nameOf(locale),
                ),
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

/// A text that keeps its words whole: it breaks between its words and never
/// inside one. A space, a tab or a line break parts two words, and a
/// no-break space keeps the two words around it together as one.
///
/// It grows with the text size of the device. Where its longest word would
/// still not fit the width that the text has, as on a narrow phone with a
/// large text size, the text is as large as that word allows.
class _WholeWords extends StatelessWidget {
  const _WholeWords(this.text);

  /// The text.
  final String text;

  @override
  Widget build(BuildContext context) {
    // The style in which a Text paints: that of the text around it, and
    // bold for a user who asks for bold text.
    var style = DefaultTextStyle.of(context).style;
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        );
        // The words of the text, between its white spaces, where a line may
        // break: every one but a no-break space, which keeps the words
        // around it together.
        final words = text.split(RegExp(r'[^\S\u00A0\u2007\u202F]+'));
        // How wide the longest word is in a font of [size].
        double widestAt(double size) {
          var widest = 0.0;
          for (final word in words) {
            painter
              ..text = TextSpan(
                text: word,
                style: style.copyWith(fontSize: size),
              )
              ..layout();
            if (painter.width > widest) widest = painter.width;
          }
          return widest;
        }

        // The size of a text of Flutter whose style gives none.
        var size = style.fontSize ?? 14;
        var widest = widestAt(size);
        // In a few steps: the text size of a device may grow a small font
        // by more than a large one.
        for (var step = 0; step < 4 && widest > room && room > 0; step++) {
          // A little smaller than the width allows, so that the rounding of
          // the layout breaks no word.
          size *= room / widest * 0.98;
          widest = widestAt(size);
        }
        painter.dispose();
        return Text(
          text,
          style: style.copyWith(fontSize: size),
          textScaler: scaler,
        );
      },
    );
  }
}
