import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';
import 'session_provider.dart';
import 'sign_in_state.dart';

/// The state of the screen that resets a password, which lasts as long as
/// the screen does.
final resetPasswordProvider =
    NotifierProvider.autoDispose<ResetPasswordNotifier, ResetPasswordState>(
      ResetPasswordNotifier.new,
    );

/// Sends the message with the link through the session of the app, and
/// tells whether the message is on its way, why it was not sent, and the
/// address that it went to.
class ResetPasswordNotifier extends Notifier<ResetPasswordState> {
  @override
  ResetPasswordState build() => const ResetPasswordState();

  /// Sends the message with which the owner of the account of [email] sets
  /// a new password.
  Future<void> send(String email) async {
    if (state.busy) return;
    final session = ref.read(appSessionProvider);
    state = const ResetPasswordState(busy: true);
    try {
      await session.sendPasswordReset(email);
      // The user may have left the screen while the call was on its way.
      if (ref.mounted) state = ResetPasswordState(sentTo: email);
    } on AuthFailure catch (failure) {
      if (ref.mounted) state = ResetPasswordState(failure: failure);
    }
  }
}
