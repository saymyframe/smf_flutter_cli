import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/app_session.dart';
import 'sign_in_state.dart';

/// The state of the screen of the account: it signs out and deletes the
/// account through the session of the app, and tells which of the two is
/// on its way and why the last one failed.
class AccountCubit extends Cubit<AccountState> {
  /// Creates the cubit that acts through [_session].
  AccountCubit(this._session) : super(const AccountState()) {
    _session.hasAccount.addListener(_follow);
  }

  final AppSessionController _session;

  /// Whether a call of this cubit is on its way.
  var _calling = false;

  /// Signs the user out.
  Future<void> signOut() => _run(AccountAction.signOut, _session.signOut);

  /// Deletes the account of the user.
  Future<void> deleteAccount() =>
      _run(AccountAction.delete, _session.deleteAccount);

  /// Makes [call], the call of [action], unless a call is on its way.
  ///
  /// Once it succeeded, the user has no account, and the router leaves the
  /// screen, so the state stays busy for as long as the session has no
  /// account.
  Future<void> _run(AccountAction action, Future<void> Function() call) async {
    if (state.busy != null) return;
    _calling = true;
    emit(AccountState(busy: action));
    try {
      await call();
    } on AuthFailure catch (failure) {
      _calling = false;
      // The user may have left the screen while the call was on its way.
      if (!isClosed) emit(AccountState(failure: failure));
      return;
    }
    _calling = false;
    _follow();
  }

  /// Ends the busy state that a call left once the session has an account:
  /// the user got one again before the router took the screen away, as by
  /// code of the app that signs a user in, and the screen is back.
  void _follow() {
    if (_calling || isClosed || state.busy == null) return;
    if (_session.hasAccount.value) emit(const AccountState());
  }

  @override
  Future<void> close() {
    _session.hasAccount.removeListener(_follow);
    return super.close();
  }
}
