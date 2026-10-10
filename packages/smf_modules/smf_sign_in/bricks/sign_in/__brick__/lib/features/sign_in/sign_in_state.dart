import 'package:flutter/foundation.dart';

import '../../core/auth/app_session.dart';

/// The state of a form of the sign-in that makes one call, such as the
/// sign-in itself: whether the call is on its way, and why the last one
/// failed.
@immutable
final class AuthActionState {
  /// Creates the state.
  const AuthActionState({this.busy = false, this.failure});

  /// Whether the call is on its way.
  ///
  /// It stays so once the call succeeded. The user is signed in then, and
  /// what comes next is up to the router, which leaves the screen: the
  /// screen neither navigates nor shows its form again. A failure ends it.
  final bool busy;

  /// Why the last call failed, or `null` if none did.
  final AuthFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is AuthActionState &&
      other.busy == busy &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(busy, failure);
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
