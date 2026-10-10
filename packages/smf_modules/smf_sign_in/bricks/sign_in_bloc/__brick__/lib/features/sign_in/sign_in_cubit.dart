import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/app_session.dart';
import 'sign_in_state.dart';

/// The state of the screen of the sign-in: it signs in through the session
/// of the app, and tells whether the sign-in is on its way and why the last
/// one failed.
class SignInCubit extends Cubit<AuthActionState> {
  /// Creates the cubit that signs in through [_session].
  SignInCubit(this._session) : super(const AuthActionState()) {
    _session.hasAccount.addListener(_follow);
  }

  final AppSessionController _session;

  /// Whether a call of this cubit is on its way.
  var _calling = false;

  /// Signs in to the account of [email] with [password].
  ///
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy for as long as the session has the account.
  Future<void> signIn({required String email, required String password}) async {
    if (state.busy) return;
    _calling = true;
    emit(const AuthActionState(busy: true));
    try {
      await _session.signIn(email: email, password: password);
    } on AuthFailure catch (failure) {
      _calling = false;
      // The user may have left the screen while the call was on its way.
      if (!isClosed) emit(AuthActionState(failure: failure));
      return;
    }
    _calling = false;
    _follow();
  }

  /// Ends the busy state that a call left once the session has no account:
  /// the user was signed out again before the router took the screen away,
  /// as by code of the app that turns a user away, and the form is back.
  void _follow() {
    if (_calling || isClosed || !state.busy) return;
    if (!_session.hasAccount.value) emit(const AuthActionState());
  }

  @override
  Future<void> close() {
    _session.hasAccount.removeListener(_follow);
    return super.close();
  }
}
