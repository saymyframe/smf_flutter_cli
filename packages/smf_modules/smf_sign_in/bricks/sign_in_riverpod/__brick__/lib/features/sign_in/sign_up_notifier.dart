import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';
import 'session_provider.dart';
import 'sign_in_state.dart';

/// The state of the screen that creates an account, which lasts as long as
/// the screen does.
final signUpProvider =
    NotifierProvider.autoDispose<SignUpNotifier, AuthActionState>(
      SignUpNotifier.new,
    );

/// Signs up through the session of the app, and tells whether the sign-up
/// is on its way and why the last one failed.
class SignUpNotifier extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();

  /// Creates an account for [email] with [password] and signs in to it.
  ///
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy until then.
  Future<void> signUp({required String email, required String password}) async {
    if (state.busy) return;
    final session = ref.read(appSessionProvider);
    state = const AuthActionState(busy: true);
    try {
      await session.signUp(email: email, password: password);
    } on AuthFailure catch (failure) {
      // The user may have left the screen while the call was on its way.
      if (ref.mounted) state = AuthActionState(failure: failure);
    }
  }
}
