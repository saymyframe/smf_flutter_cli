import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/sign_in_methods.dart';
import 'session_provider.dart';
import 'sign_in_state.dart';

/// The state of the screen that creates an account, which lasts as long as
/// the screen does.
///
/// A provider is one for the app, where a cubit would be one for each page:
/// two pages of this screen that are open at once, as a leaving one and a
/// new one during a transition, show the same state.
final signUpProvider =
    NotifierProvider.autoDispose<SignUpNotifier, AuthActionState>(
      SignUpNotifier.new,
    );

/// Signs up through the session of the app, or signs in with a way to sign
/// in of the app, and tells whether a call is on its way and why the last
/// one failed.
class SignUpNotifier extends Notifier<AuthActionState> {
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

  /// Creates an account for [email] with [password] and signs in to it.
  ///
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy for as long as the session has the account.
  Future<void> signUp({required String email, required String password}) =>
      _run((session) async {
        await session.signUp(email: email, password: password);
        return true;
      });

  /// Signs in with [method], a way to sign in of the app: asks its identity
  /// provider for a credential, with a sheet of its own, and gives it to
  /// the session.
  ///
  /// When the user closes the sheet, the state is again as it was before.
  /// Once the user is signed in, the router leaves the screen, so the state
  /// stays busy for as long as the session has the account.
  Future<void> continueWith(SignInMethod method) => _run(
    (session) => continueWithMethod(session, method),
    method: method,
  );

  /// Makes [call], the call of [method] or of the form, unless a call is on
  /// its way. [call] returns whether it signed in: `false` when the user
  /// closed the sheet of a way to sign in, and the state is again as it
  /// was before then.
  Future<void> _run(
    Future<bool> Function(AppSessionController session) call, {
    SignInMethod? method,
  }) async {
    if (state.busy) return;
    final session = ref.read(appSessionProvider);
    final before = state;
    _calling = true;
    state = AuthActionState(busy: true, method: method);
    final bool signedIn;
    try {
      signedIn = await call(session);
    } on AuthFailure catch (failure) {
      _calling = false;
      // The user may have left the screen while the call was on its way.
      if (ref.mounted) {
        state = AuthActionState(failure: failure, method: method);
      }
      return;
    }
    _calling = false;
    if (!ref.mounted) return;
    if (!signedIn) {
      state = before;
    } else if (!session.hasAccount.value) {
      // The user may be signed out again already.
      state = const AuthActionState();
    }
  }
}
