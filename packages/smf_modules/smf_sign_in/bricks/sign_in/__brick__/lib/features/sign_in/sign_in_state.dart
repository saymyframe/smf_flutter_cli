import 'package:flutter/foundation.dart';

import '../../core/auth/app_session.dart';
import '../../core/auth/sign_in_methods.dart';

/// The state of a screen of the sign-in whose form makes one call, such as
/// the sign-in itself, and whose buttons continue with the ways to sign in
/// of the app: whether a call is on its way, which one, and why the last
/// one failed.
@immutable
final class AuthActionState {
  /// Creates the state.
  const AuthActionState({this.busy = false, this.failure, this.method});

  /// Whether the call is on its way.
  ///
  /// It stays so once the call succeeded, for as long as the session has
  /// the account. The user is signed in then, and what comes next is up to
  /// the router, which leaves the screen: the screen neither navigates nor
  /// shows its form again. A failure ends it, and so does a session that
  /// has no account any more, as when code of the app signs the user out
  /// before the router took the screen away.
  final bool busy;

  /// Why the last call failed, or `null` if none did.
  final AuthFailure? failure;

  /// The way to sign in whose call is on its way or failed last, or `null`
  /// for the call of the form. So the screen shows the failure of a call
  /// where the user made it: below the buttons of the ways to sign in, or
  /// above the button of the form.
  final SignInMethod? method;

  @override
  bool operator ==(Object other) =>
      other is AuthActionState &&
      other.busy == busy &&
      other.failure == failure &&
      other.method == method;

  @override
  int get hashCode => Object.hash(busy, failure, method);
}

/// Signs in with [method] through [session]: asks the identity provider of
/// the way to sign in for a credential, with a sheet of its own, and gives
/// the credential to the session, which gives an anonymous user the
/// identity with the same id.
///
/// Returns `false` when the user closed the sheet, which is no failure: the
/// session gets no call then. It fails only with an [AuthFailure]. A way to
/// sign in fails so too, and an error of another kind becomes a failure
/// with the reason [AuthFailureReason.unknown], as the session does with
/// the errors of its calls.
Future<bool> continueWithMethod(
  AppSessionController session,
  SignInMethod method,
) async {
  final SignInCredential? credential;
  try {
    credential = await method.credential();
  } on AuthFailure {
    rethrow;
  } on Object catch (error, stackTrace) {
    Error.throwWithStackTrace(
      AuthFailure(AuthFailureReason.unknown, developerHint: '$error'),
      stackTrace,
    );
  }
  if (credential == null) return false;
  await session.signInWith(credential);
  return true;
}

/// The state of the form that sends the message to reset a password.
@immutable
final class ResetPasswordState {
  /// Creates the state.
  const ResetPasswordState({this.busy = false, this.failure, this.sentTo});

  /// Whether the call is on its way.
  final bool busy;

  /// Why the last call failed, or `null` if none did.
  final AuthFailure? failure;

  /// The address that the message was sent to, or `null` before it is
  /// sent.
  final String? sentTo;

  @override
  bool operator ==(Object other) =>
      other is ResetPasswordState &&
      other.busy == busy &&
      other.failure == failure &&
      other.sentTo == sentTo;

  @override
  int get hashCode => Object.hash(busy, failure, sentTo);
}

/// An action of the screen of the account.
enum AccountAction {
  /// Signing the user out.
  signOut,

  /// Deleting the account.
  delete,
}

/// The state of the screen of the account: which of its two actions is on
/// its way, and which one failed last and why.
@immutable
final class AccountState {
  /// Creates the state.
  const AccountState({this.busy, this.failure, this.failedAction});

  /// The action whose call is on its way, or `null` when none is. While it
  /// is, the screen takes no other action.
  ///
  /// It stays so once the call succeeded, for as long as the session has
  /// no account. What comes next is up to the router, which leaves the
  /// screen: the screen neither closes itself nor navigates. A failure
  /// ends it, and so does a session that has an account again before the
  /// router took the screen away.
  final AccountAction? busy;

  /// Why the last action failed, or `null` if none did.
  final AuthFailure? failure;

  /// The action that failed with [failure], or `null` if none did. The
  /// screen tells of a failed deletion in words of its own.
  final AccountAction? failedAction;

  @override
  bool operator ==(Object other) =>
      other is AccountState &&
      other.busy == busy &&
      other.failure == failure &&
      other.failedAction == failedAction;

  @override
  int get hashCode => Object.hash(busy, failure, failedAction);
}
