import 'package:flutter/material.dart';

/// What the entry of the subscription on the settings screen shows: a row,
/// as the other entries of the screen are, which tells whether the user has
/// premium access and leads to the screen of the subscription.
///
/// It keeps nothing: the entry gives it whether the user has the access and
/// takes the tap. So it is the same whichever way the app manages state.
class SubscriptionSettingRow extends StatelessWidget {
  /// Creates the row.
  const SubscriptionSettingRow({
    required this.active,
    required this.onTap,
    super.key,
  });

  /// Whether the user has premium access.
  final bool active;

  /// Shows the screen of the subscription, or the paywall first for a user
  /// without premium access.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Icon(
        active ? Icons.workspace_premium : Icons.workspace_premium_outlined,
        color: active ? theme.colorScheme.secondary : null,
      ),
      title: Text({{{text_setting_title}}}),
      subtitle: Text(
        active ? {{{text_setting_active}}} : {{{text_setting_inactive}}},
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      ),
      trailing: Icon(Icons.chevron_right, color: muted),
      onTap: onTap,
    );
  }
}
