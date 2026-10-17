import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../auth/app_session.dart';

/// The issuer of the ID tokens of Apple.
const String _issuer = '{{{issuer}}}';

/// Asks Apple for a credential with the sheet of Sign in with Apple, and
/// returns it, or `null` when the user closed the sheet.
///
/// The request asks for the email address and the full name of the user,
/// with the SHA-256 hash of a new random nonce, which Apple writes into the
/// ID token. The credential has the nonce itself, with which the provider
/// of sign-in checks the token, and the authorization code of this request,
/// with which the provider can revoke the tokens that Apple gave the app
/// when the account is deleted. Apple gives the name of the user only the
/// first time that the user signs in to the app, so a later credential has
/// none.
///
/// It works on iOS only. On another platform it fails with
/// `notConfigured` without asking Apple. Apple answers an app without the
/// capability Sign in with Apple with an unknown error, which fails with
/// `notConfigured` too, and with a hint at the section of the README of the
/// app on it, "{{{readme}}}". Any other error fails with `unknown`.
Future<SignInCredential?> appleCredential() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    throw AuthFailure(
      AuthFailureReason.notConfigured,
      developerHint:
          'Sign in with Apple works on iOS only, and the app runs on '
          '${defaultTargetPlatform.name}.',
    );
  }
  final rawNonce = generateNonce();
  final AuthorizationCredentialAppleID apple;
  try {
    apple = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
  } on SignInWithAppleAuthorizationException catch (error) {
    switch (error.code) {
      case AuthorizationErrorCode.canceled:
        return null;
      case AuthorizationErrorCode.unknown:
        throw AuthFailure(
          AuthFailureReason.notConfigured,
          developerHint:
              'Apple answered with an unknown error (${error.message}). It '
              'does so when the app is not signed with the capability Sign '
              'in with Apple, which needs a team of the paid Apple Developer '
              'Program, and may do so on a device without an Apple Account. '
              'See the section "{{{readme}}}" of the README of the app.',
        );
      default:
        throw AuthFailure(AuthFailureReason.unknown, developerHint: '$error');
    }
  } on Object catch (error) {
    throw AuthFailure(AuthFailureReason.unknown, developerHint: '$error');
  }
  final idToken = apple.identityToken;
  if (idToken == null) {
    throw const AuthFailure(
      AuthFailureReason.unknown,
      developerHint: 'Apple gave no identity token.',
    );
  }
  return IdTokenCredential(
    issuer: _issuer,
    idToken: idToken,
    rawNonce: rawNonce,
    authorizationCode: apple.authorizationCode,
    givenName: apple.givenName,
    familyName: apple.familyName,
  );
}

/// The icon of the button of Sign in with Apple: the Apple logo of the
/// Material icons, which takes the colour of the label of the button.
///
/// Apple asks a custom button of Sign in with Apple for its own logo
/// artwork, which Apple Design Resources has, and App Review checks every
/// such button: see the section of the README of the app on it,
/// "{{{readme}}}".
class AppleSignInIcon extends StatelessWidget {
  /// Creates the icon.
  const AppleSignInIcon({super.key});

  @override
  Widget build(BuildContext context) => const Icon(Icons.apple);
}
