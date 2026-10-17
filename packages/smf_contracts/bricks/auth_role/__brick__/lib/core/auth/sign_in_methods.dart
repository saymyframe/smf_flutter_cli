import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'auth_service.dart' show SignInCredential;

/// A way to sign in with an identity provider, such as the account of the
/// user at another service: the label and the icon of its button, the
/// platforms that it works on, and the function that asks the identity
/// provider for a credential.
///
/// A screen of sign-in shows a button for each method of
/// [appSignInMethods] that [isAvailable]. On a tap, the state of the screen
/// calls [credential] and gives what it returns to `appSession.signInWith`
/// of `app_session.dart`.
final class SignInMethod {
  /// Creates a way to sign in with the identity provider [issuer].
  const SignInMethod({
    required this.label,
    required this.icon,
    required this.platforms,
    required this.credential,
    required this.issuer,
    this.revokesOnDeletion = false,
  });

  /// Returns the label of the button in the language of the app, for the
  /// context of the widget that shows it. That widget calls it each time it
  /// builds, so the text follows the language of the app.
  final String Function(BuildContext context) label;

  /// The icon of the button, a constant widget: an `Icon` takes the colour
  /// of the label, and an `Image` keeps its own colours.
  final Widget icon;

  /// The platforms that the way to sign in works on. On any other,
  /// [isAvailable] is false.
  final Set<TargetPlatform> platforms;

  /// Asks the identity provider for a credential, such as with a sheet of
  /// its own, and returns it, or `null` when the user closed the sheet,
  /// which is no failure. It fails only with an `AuthFailure`.
  ///
  /// The state of a screen calls it, and no code within a call of
  /// `appSession`: `appSession.deleteAccount()` calls it itself, for a
  /// method that [revokesOnDeletion].
  final Future<SignInCredential?> Function() credential;

  /// The identity provider: the issuer of its tokens, an https URL such as
  /// `https://accounts.example.com`. `AccountSession.issuers` of
  /// `app_session.dart` lists those of the user of an account.
  final String issuer;

  /// Whether the deletion of an account that signs in this way asks the
  /// identity provider for a credential again first, so that the provider
  /// of sign-in can revoke the tokens that the identity provider gave the
  /// app. `appSession.deleteAccount()` does it.
  final bool revokesOnDeletion;

  /// Whether the way to sign in works on the platform that the app runs on.
  bool get isAvailable => platforms.contains(defaultTargetPlatform);
}

/// The ways to sign in with an identity provider of the app, in the order
/// of their modules. An email address and a password are no such way:
/// `appSession.signIn` and `appSession.signUp` take them.
const List<SignInMethod> appSignInMethods = [
{{{methods}}}
];
{{{labels}}}
