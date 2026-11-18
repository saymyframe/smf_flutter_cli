import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'app_feedback.dart';

/// The entry of the settings screen through which the user writes to the
/// developer of the app: a tap opens the way of the provider of the feedback
/// role, such as a new mail in the mail app.
///
/// It shows nothing of its own: where the way cannot open, the provider
/// shows its own way to reach the developer. It has no arrow and no icon of
/// mail, since a provider may also show a form inside the app. A second tap
/// while the first is on its way does nothing.
class FeedbackSetting extends StatelessWidget {
  /// Creates the setting.
  const FeedbackSetting({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.chat_bubble_outline_rounded),
        // At a large text size the title wraps in the row between its words.
        title: _WholeWords({{{text_title}}}),
        onTap: () => unawaited(appFeedback.open(context)),
      );
}

/// Whether the settings screen shows [FeedbackSetting]: only while the
/// provider has what it needs, such as an address. It reads nothing else, so
/// the row is there whatever the user did with the review dialog of a store.
bool feedbackSettingShows() => appFeedback.available;

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
