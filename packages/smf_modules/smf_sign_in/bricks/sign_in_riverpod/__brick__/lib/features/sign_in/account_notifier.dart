import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';
import 'session_provider.dart';
import 'sign_in_state.dart';

/// The state of the screen of the account, which lasts as long as the
/// screen does.
///
/// A provider is one for the app, where a cubit would be one for each page:
/// two pages of this screen that are open at once, as a leaving one and a
/// new one during a transition, show the same state.
final accountProvider =
    NotifierProvider.autoDispose<AccountNotifier, AccountState>(
      AccountNotifier.new,
    );

/// Signs out and deletes the account through the session of the app, and
/// tells which of the two is on its way and why the last one failed.
class AccountNotifier extends Notifier<AccountState> {
  /// Whether a call of this notifier is on its way.
  var _calling = false;

  @override
  AccountState build() {
    final session = ref.watch(appSessionProvider);
    // Ends the busy state that a call left once the session has an
    // account: the user got one again before the router took the screen
    // away, as by code of the app that signs a user in, and the screen is
    // back.
    void follow() {
      if (_calling || state.busy == null) return;
      if (session.hasAccount.value) state = const AccountState();
    }

    session.hasAccount.addListener(follow);
    ref.onDispose(() => session.hasAccount.removeListener(follow));
    return const AccountState();
  }

  /// Signs the user out.
  Future<void> signOut() =>
      _run(AccountAction.signOut, (session) => session.signOut());

  /// Deletes the account of the user.
  Future<void> deleteAccount() =>
      _run(AccountAction.delete, (session) => session.deleteAccount());

  /// Makes [call], the call of [action], unless a call is on its way.
  ///
  /// Once it succeeded, the user has no account, and the router leaves the
  /// screen, so the state stays busy for as long as the session has no
  /// account.
  Future<void> _run(
    AccountAction action,
    Future<void> Function(AppSessionController session) call,
  ) async {
    if (state.busy != null) return;
    final session = ref.read(appSessionProvider);
    _calling = true;
    state = AccountState(busy: action);
    try {
      await call(session);
    } on AuthFailure catch (failure) {
      _calling = false;
      // The user may have left the screen while the call was on its way.
      if (ref.mounted) state = AccountState(failure: failure);
      return;
    }
    _calling = false;
    // The user may have an account again already.
    if (ref.mounted && session.hasAccount.value) {
      state = const AccountState();
    }
  }
}
