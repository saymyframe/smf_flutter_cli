import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/app_session.dart';
import 'sign_in_state.dart';

/// The state of the screen that creates an account: it signs up through
/// the session of the app, and tells whether the sign-up is on its way and
/// why the last one failed.
class SignUpCubit extends Cubit<AuthActionState> {
  /// Creates the cubit that signs up through [_session].
  SignUpCubit(this._session) : super(const AuthActionState());

  final AppSessionController _session;

  /// Creates an account for [email] with [password] and signs in to it.
  ///
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy until then.
  Future<void> signUp({required String email, required String password}) async {
    if (state.busy) return;
    emit(const AuthActionState(busy: true));
    try {
      await _session.signUp(email: email, password: password);
    } on AuthFailure catch (failure) {
      // The user may have left the screen while the call was on its way.
      if (!isClosed) emit(AuthActionState(failure: failure));
    }
  }
}
