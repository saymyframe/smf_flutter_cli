import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/app_session.dart';
import 'sign_in_state.dart';

/// The state of the screen of the sign-in: it signs in through the session
/// of the app, and tells whether the sign-in is on its way and why the last
/// one failed.
class SignInCubit extends Cubit<AuthActionState> {
  /// Creates the cubit that signs in through [_session].
  SignInCubit(this._session) : super(const AuthActionState());

  final AppSessionController _session;

  /// Signs in to the account of [email] with [password].
  ///
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy until then.
  Future<void> signIn({required String email, required String password}) async {
    if (state.busy) return;
    emit(const AuthActionState(busy: true));
    try {
      await _session.signIn(email: email, password: password);
    } on AuthFailure catch (failure) {
      // The user may have left the screen while the call was on its way.
      if (!isClosed) emit(AuthActionState(failure: failure));
    }
  }
}
