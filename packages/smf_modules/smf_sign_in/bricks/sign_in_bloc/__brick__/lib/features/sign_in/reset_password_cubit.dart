import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth/app_session.dart';
import 'sign_in_state.dart';

/// The state of the screen that resets a password: it sends the message
/// with the link through the session of the app, and tells whether the
/// message is on its way, why it was not sent, and the address that it
/// went to.
class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  /// Creates the cubit that sends the message through [_session].
  ResetPasswordCubit(this._session) : super(const ResetPasswordState());

  final AppSessionController _session;

  /// Sends the message with which the owner of the account of [email] sets
  /// a new password.
  Future<void> send(String email) async {
    if (state.busy) return;
    emit(const ResetPasswordState(busy: true));
    try {
      await _session.sendPasswordReset(email);
      // The user may have left the screen while the call was on its way.
      if (!isClosed) emit(ResetPasswordState(sentTo: email));
    } on AuthFailure catch (failure) {
      if (!isClosed) emit(ResetPasswordState(failure: failure));
    }
  }
}
