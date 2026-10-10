import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';
import 'session_provider.dart';
import 'sign_in_state.dart';

/// The state of the screen of the sign-in, which lasts as long as the
/// screen does.
///
/// A provider is one for the app, where a cubit would be one for each page:
/// two pages of this screen that are open at once, as a leaving one and a
/// new one during a transition, show the same state.
final signInProvider =
    NotifierProvider.autoDispose<SignInNotifier, AuthActionState>(
      SignInNotifier.new,
    );

/// Signs in through the session of the app, and tells whether the sign-in
/// is on its way and why the last one failed.
class SignInNotifier extends Notifier<AuthActionState> {
  /// Whether a call of this notifier is on its way.
  var _calling = false;

  @override
  AuthActionState build() {
    final session = ref.watch(appSessionProvider);
    // Ends the busy state that a call left once the session has no
    // account: the user was signed out again before the router took the
    // screen away, as by code of the app that turns a user away, and the
    // form is back.
    void follow() {
      if (_calling || !state.busy) return;
      if (!session.hasAccount.value) state = const AuthActionState();
    }

    session.hasAccount.addListener(follow);
    ref.onDispose(() => session.hasAccount.removeListener(follow));
    return const AuthActionState();
  }

  /// Signs in to the account of [email] with [password].
  ///
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy for as long as the session has the account.
  Future<void> signIn({required String email, required String password}) async {
    if (state.busy) return;
    final session = ref.read(appSessionProvider);
    _calling = true;
    state = const AuthActionState(busy: true);
    try {
      await session.signIn(email: email, password: password);
    } on AuthFailure catch (failure) {
      _calling = false;
      // The user may have left the screen while the call was on its way.
      if (ref.mounted) state = AuthActionState(failure: failure);
      return;
    }
    _calling = false;
    // The user may be signed out again already.
    if (ref.mounted && !session.hasAccount.value) {
      state = const AuthActionState();
    }
  }
}
