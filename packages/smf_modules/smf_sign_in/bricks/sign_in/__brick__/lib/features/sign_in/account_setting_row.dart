import 'package:flutter/material.dart';

/// What the entry of the account on the settings screen shows: a row, as
/// the other entries of the screen are, with the email address of the
/// account that the user is signed in to, or that nobody is, which leads to
/// the screen of the account.
///
/// It keeps nothing: the entry gives it who is signed in and takes the tap.
/// So it is the same whichever way the app manages state.
class AccountSettingRow extends StatelessWidget {
  /// Creates the row.
  const AccountSettingRow({
    required this.signedIn,
    required this.email,
    required this.onTap,
    super.key,
  });

  /// Whether the user is signed in to an account.
  final bool signedIn;

  /// The email address of the account, or `null` for an account without
  /// one, and for a user without an account.
  final String? email;

  /// Shows the screen of the account.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final signedInText = {{{text_setting_signed_in}}};
    final notSignedInText = {{{text_not_signed_in}}};
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text({{{text_account_title}}}),
      // Below the title, where an address has the width of the row.
      subtitle: Text(
        signedIn ? email ?? signedInText : notSignedInText,
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      ),
      trailing: Icon(Icons.chevron_right, color: muted),
      onTap: onTap,
    );
  }
}
