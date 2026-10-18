import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/sign_in_methods.dart';
import 'sign_in_state.dart';

/// The state of the screen of the sign-in: it signs in through the session
/// of the app, with the email address and the password of the form or with
/// a way to sign in of the app, and tells whether a call is on its way and
/// why the last one failed.
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
  Future<void> signIn({required String email, required String password}) =>
      _run(() async {
        await _session.signIn(email: email, password: password);
        return true;
      });

  /// Signs in with [method], a way to sign in of the app: asks its identity
  /// provider for a credential, with a sheet of its own, and gives it to
  /// the session.
  ///
  /// When the user closes the sheet, the state is again as it was before.
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy for as long as the session has the account.
  Future<void> continueWith(SignInMethod method) =>
      _run(() => continueWithMethod(_session, method), method: method);

  /// Makes [call], the call of [method] or of the form, unless a call is on
  /// its way. [call] returns whether it signed in: `false` when the user
  /// closed the sheet of a way to sign in, and the state is again as it
  /// was before then.
  Future<void> _run(
    Future<bool> Function() call, {
    SignInMethod? method,
  }) async {
    if (state.busy) return;
    final before = state;
    _calling = true;
    emit(AuthActionState(busy: true, method: method));
    final bool signedIn;
    try {
      signedIn = await call();
    } on AuthFailure catch (failure) {
      _calling = false;
      // The user may have left the screen while the call was on its way.
      if (!isClosed) emit(AuthActionState(failure: failure, method: method));
      return;
    }
    _calling = false;
    if (!signedIn) {
      if (!isClosed) emit(before);
      return;
    }
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
