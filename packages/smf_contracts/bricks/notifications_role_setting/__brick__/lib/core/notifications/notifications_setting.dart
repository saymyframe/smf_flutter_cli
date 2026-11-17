import 'package:flutter/material.dart';

import 'app_notifications.dart';

/// The setting of the notifications of the app, an entry of the settings
/// screen: it shows whether the app may show notifications. A tap asks for
/// the permission while the app has not asked, and opens the settings of
/// the system after that, where the user turns the notifications on or off.
///
/// It follows the permission, also when the user changed it in the settings
/// of the system and came back to the app.
///
/// The entry does not wait for what a tap starts. If the preferences fail
/// to save that the app asked, or the service of the provider fails,
/// nothing here catches the error: it reaches the handlers of the uncaught
/// errors of the app.
class NotificationsSetting extends StatelessWidget {
  /// Creates the setting.
  const NotificationsSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ValueListenableBuilder<NotificationPermission>(
      valueListenable: appNotifications.permission,
      builder: (context, permission, _) {
        final state = permission == NotificationPermission.granted
            ? {{{text_on}}}
            : {{{text_off}}};
        final style = theme.textTheme.bodyMedium?.copyWith(color: muted);
        final arrow = Icon(Icons.chevron_right, color: muted);
        // At a large text size, the state goes below the title, where it
        // has the width of the row, and the two wrap between their words.
        final below = MediaQuery.textScalerOf(context).scale(10) > 13;
        return ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: _WholeWords({{{text_title}}}),
          subtitle: below
              ? DefaultTextStyle.merge(style: style, child: _WholeWords(state))
              : null,
          trailing: below
              ? arrow
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state, style: style),
                    const SizedBox(width: 4),
                    arrow,
                  ],
                ),
          onTap: permission == NotificationPermission.notAsked
              ? appNotifications.request
              : appNotifications.openSettings,
        );
      },
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
