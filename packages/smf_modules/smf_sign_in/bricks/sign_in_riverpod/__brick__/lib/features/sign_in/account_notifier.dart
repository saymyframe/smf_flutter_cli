import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';
import 'session_provider.dart';
import 'sign_in_state.dart';

/// The state of the screen of the account, which lasts as long as the
/// screen does.
final accountProvider =
    NotifierProvider.autoDispose<AccountNotifier, AccountState>(
      AccountNotifier.new,
    );

/// Signs out and deletes the account through the session of the app, and
/// tells which of the two is on its way and why the last one failed.
class AccountNotifier extends Notifier<AccountState> {
  @override
  AccountState build() => const AccountState();

  /// Signs the user out.
  Future<void> signOut() =>
      _run(AccountAction.signOut, (session) => session.signOut());

  /// Deletes the account of the user.
  Future<void> deleteAccount() =>
      _run(AccountAction.delete, (session) => session.deleteAccount());

  /// Makes [call], the call of [action], unless a call is on its way.
  ///
  /// Once it succeeded, the user has no account, and the router leaves the
  /// screen, so the state stays busy until then.
  Future<void> _run(
    AccountAction action,
    Future<void> Function(AppSessionController session) call,
  ) async {
    if (state.busy != null) return;
    final session = ref.read(appSessionProvider);
    state = AccountState(busy: action);
    try {
      await call(session);
    } on AuthFailure catch (failure) {
      // The user may have left the screen while the call was on its way.
      if (ref.mounted) state = AccountState(failure: failure);
    }
  }
}
