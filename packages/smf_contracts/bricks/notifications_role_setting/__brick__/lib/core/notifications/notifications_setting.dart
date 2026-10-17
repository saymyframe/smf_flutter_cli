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
        final state = Text(
          permission == NotificationPermission.granted
              ? {{{text_on}}}
              : {{{text_off}}},
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        );
        final arrow = Icon(Icons.chevron_right, color: muted);
        // At a large text size, the state goes below the title, where it
        // has the width of the row.
        final below = MediaQuery.textScalerOf(context).scale(10) > 13;
        return ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text({{{text_title}}}),
          subtitle: below ? state : null,
          trailing: below
              ? arrow
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [state, const SizedBox(width: 4), arrow],
                ),
          onTap: permission == NotificationPermission.notAsked
              ? appNotifications.request
              : appNotifications.openSettings,
        );
      },
    );
  }
}
