import 'package:flutter/material.dart';

import '../../core/auth/app_session.dart';
import 'sign_in_page.dart';
import 'sign_in_state.dart';
import 'sign_in_widgets.dart';

/// What the screen of the account shows: the email address of the account
/// that the user is signed in to, the button that signs out, and the
/// action that deletes the account, which asks first.
///
/// It keeps nothing of the calls themselves: the screen gives it the
/// address and the state of the calls, and takes what the user asks for.
/// So it is the same whichever way the app manages state.
class AccountView extends StatefulWidget {
  /// Creates the view.
  const AccountView({
    required this.email,
    required this.busy,
    required this.failure,
    required this.onSignOut,
    required this.onDeleteAccount,
    super.key,
  });

  /// The email address of the account, or `null` for an account without
  /// one, and once nobody is signed in to an account.
  final String? email;

  /// The action whose call is on its way, or `null` when none is.
  final AccountAction? busy;

  /// Why the last action failed, or `null` if none did.
  final AuthFailure? failure;

  /// Signs the user out.
  final VoidCallback onSignOut;

  /// Deletes the account, once the user has confirmed it.
  final VoidCallback onDeleteAccount;

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  /// The address that the page shows: that of the account, also once the
  /// user is signed out, since the page shows until the router closes it.
  late String? _email = widget.email;

  @override
  void didUpdateWidget(AccountView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.email != null) _email = widget.email;
  }

  /// Asks whether to delete the account, and deletes it on a yes. The
  /// sheet of the question is closed by then: once the account is deleted,
  /// the router closes this page, and the page closes nothing itself.
  Future<void> _delete() async {
    final confirmed = await confirmDeleteAccount(context);
    if (confirmed && mounted) widget.onDeleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;
    final idle = widget.busy == null;
    return AuthPage(
      title: {{{text_account_title}}},
      intro: email == null
          ? {{{text_signed_in}}}
          : {{{text_signed_in_as}}},
      children: [
        if (email != null) EmailAddress(email),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 28),
            FailureMessage(widget.failure),
            SubmitButton(
              label: {{{text_sign_out}}},
              busy: widget.busy == AccountAction.signOut,
              onPressed: idle ? widget.onSignOut : null,
            ),
            const SizedBox(height: 4),
            // Apart from the button, and in the colour of an error: it
            // cannot be undone.
            DestructiveAction(
              label: {{{text_delete_account}}},
              busy: widget.busy == AccountAction.delete,
              onPressed: idle ? _delete : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// Asks the user whether to delete the account, in a sheet over the page of
/// [context], as the settings of the app ask in sheets, and returns whether
/// the user said yes. The sheet is closed when it returns.
Future<bool> confirmDeleteAccount(BuildContext context) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    // Over the main navigation of the app too.
    useRootNavigator: true,
    showDragHandle: true,
    // As tall as what it shows, up to the height of the screen.
    isScrollControlled: true,
    builder: (context) => const _DeleteAccountSheet(),
  );
  return confirmed ?? false;
}

/// The sheet that asks whether to delete the account: what the deletion
/// means, the button that deletes, in the colours that the theme of the
/// app has for an error, and the way out. It scrolls where it does not fit,
/// as with a large text size on a small phone.
class _DeleteAccountSheet extends StatelessWidget {
  const _DeleteAccountSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              // As the title of a page, it grows only by half with the
              // text size of the device.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.5,
                child: Text(
                  {{{text_delete_title}}},
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              {{{text_delete_text}}},
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            // The label of each button is one word, which has the width of
            // the sheet. So at a large text size they grow only by half,
            // and no word breaks on a narrow phone.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onError,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      {{{text_delete}}},
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      {{{text_cancel}}},
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
