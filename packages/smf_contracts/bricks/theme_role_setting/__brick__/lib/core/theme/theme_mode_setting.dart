// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'theme_mode.dart';

/// The setting of the theme mode of the app, an entry of the settings
/// screen: it shows the mode that the user selected, and lets the user
/// select whether the app is light, dark, or follows the device.
///
/// The entry does not wait until a choice is saved. If the preferences fail
/// to save it, the app shows the selected mode while it runs, its next
/// launch has the mode that was saved before, and the error is one that
/// nothing here catches: it reaches the handlers of the uncaught errors of
/// the app.
class ThemeModeSetting extends StatelessWidget {
  /// Creates the setting.
  const ThemeModeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                // At a large text size the title wraps in the entry between
                // its words.
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.bodyLarge,
                  child: _WholeWords({{{text_title}}}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // The names of the modes share the width of the entry, so at a
          // large text size they grow only by half.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                ),
              ),
              segments: [
                for (final (mode, icon, name) in [
                  (
                    ThemeMode.system,
                    Icons.brightness_auto_outlined,
                    {{{text_system}}},
                  ),
                  (
                    ThemeMode.light,
                    Icons.light_mode_outlined,
                    {{{text_light}}},
                  ),
                  (
                    ThemeMode.dark,
                    Icons.dark_mode_outlined,
                    {{{text_dark}}},
                  ),
                ])
                  ButtonSegment(
                    value: mode,
                    // The icon above the name, so that a long name of a
                    // mode has the width of its segment.
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(height: 4),
                        // On one line, and scaled down where it is wider
                        // than its segment.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(name, maxLines: 1, softWrap: false),
                        ),
                      ],
                    ),
                  ),
              ],
              selected: {AppThemeModeScope.of(context)},
              onSelectionChanged: (modes) => appThemeMode.choose(modes.single),
            ),
          ),
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
