import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';
import 'session_provider.dart';
import 'sign_in_state.dart';

/// The state of the screen of the sign-in, which lasts as long as the
/// screen does.
final signInProvider =
    NotifierProvider.autoDispose<SignInNotifier, AuthActionState>(
      SignInNotifier.new,
    );

/// Signs in through the session of the app, and tells whether the sign-in
/// is on its way and why the last one failed.
class SignInNotifier extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();

  /// Signs in to the account of [email] with [password].
  ///
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy until then.
  Future<void> signIn({required String email, required String password}) async {
    if (state.busy) return;
    final session = ref.read(appSessionProvider);
    state = const AuthActionState(busy: true);
    try {
      await session.signIn(email: email, password: password);
    } on AuthFailure catch (failure) {
      // The user may have left the screen while the call was on its way.
      if (ref.mounted) state = AuthActionState(failure: failure);
    }
  }
}
