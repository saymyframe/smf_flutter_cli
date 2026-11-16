import 'package:flutter/material.dart';

import 'app_review.dart';

/// The entry of the settings screen that opens the page of the app in its
/// store, on which the user writes a review: on Android its Google Play
/// page, on iOS its App Store page, which takes the App Store ID in `.env`.
///
/// It never asks for the review dialog of the store: Google Play forbids
/// the dialog from a button and points a button to the page. When no app of
/// the device opens the page, a snack bar says so.
class ReviewSetting extends StatelessWidget {
  /// Creates the setting.
  const ReviewSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      leading: const Icon(Icons.star_outline_rounded),
      // At a large text size the title wraps in the row between its words.
      title: _WholeWords({{{text_title}}}),
      // The page opens outside the app. The icon is a little smaller than
      // the arrow of the other entries, in a box of the same size, so that
      // the two have one centre.
      trailing: SizedBox.square(
        dimension: 24,
        child: Icon(Icons.open_in_new_rounded, size: 20, color: muted),
      ),
      onTap: () async {
        // Read before the await, while the entry is surely on the screen.
        final failed = {{{text_failed}}};
        final messenger = ScaffoldMessenger.of(context);
        if (await appReview.openStorePage(review: true)) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failed)));
      },
    );
  }
}

/// Whether the settings screen shows [ReviewSetting]: only where the app has
/// a page in its store, which on iOS takes the App Store ID in `.env`.
bool reviewSettingShows() => appReview.hasStorePage;

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
        final words = text.split(RegExp(r'[^\S   ]+'));
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
