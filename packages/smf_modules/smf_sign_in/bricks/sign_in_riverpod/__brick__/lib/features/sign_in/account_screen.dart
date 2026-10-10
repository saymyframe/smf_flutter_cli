import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';
import 'account_notifier.dart';
import 'account_view.dart';
import 'session_provider.dart';

/// The screen of the account: the [AccountView] with the state of
/// [accountProvider], and the address of the account from
/// [sessionProvider].
///
/// It neither closes itself nor navigates once the user is signed out or
/// the account is deleted: the router leaves the screen then.
{{{smf_router__screen_annotations__sign_in__account_screen}}}
class AccountScreen extends ConsumerWidget {
  /// Creates the screen.
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountProvider);
    final session = ref.watch(sessionProvider);
    return AccountView(
      email: session is AccountSession ? session.email : null,
      busy: state.busy,
      failure: state.failure,
      onSignOut: ref.read(accountProvider.notifier).signOut,
      onDeleteAccount: ref.read(accountProvider.notifier).deleteAccount,
    );
  }
}
