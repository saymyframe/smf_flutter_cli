import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../auth/app_session.dart';

/// The issuer of the ID tokens of Google.
const String _issuer = '{{{issuer}}}';

/// The logo of Google, the "G", an image that `pubspec.yaml` declares among
/// the assets of the app. Flutter takes the file of the same name in
/// `2.0x/` and `3.0x/` next to it for a screen with more pixels.
const String _logo = '{{{logo}}}';

/// The start of google_sign_in, which [googleCredential] waits for: the
/// package is started once, before its first sign-in.
Future<void>? _started;

/// Asks Google for a credential with the sheet of Google sign-in, and
/// returns it, or `null` when the user closed the sheet.
///
/// The first call starts google_sign_in with `GoogleSignIn.instance
/// .initialize()`, without the ids of the clients of Google, so the package
/// finds them in the files of the app where the provider of sign-in puts
/// them. The credential is the ID token of the Google account that the user
/// chose.
///
/// A client of Google that is missing in the app, or a Google project that
/// does not know the app, fails with `notConfigured`, with a hint at the
/// section of the README of the app on it, "{{{readme}}}". Any other error
/// fails with `unknown`. On iOS, the Google Sign-In SDK stops the app
/// instead when the app has no iOS client of Google or not its URL scheme,
/// since the package does not catch what the SDK throws then.
Future<SignInCredential?> googleCredential() async {
  final GoogleSignInAccount account;
  try {
    await (_started ??= GoogleSignIn.instance.initialize());
    account = await GoogleSignIn.instance.authenticate();
  } on GoogleSignInException catch (error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return null;
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        throw _notConfigured(error.description ?? error.code.name);
      // Credential Manager on Android answers so when the Google project
      // has no Android client with the name of the package and the SHA-1
      // of the key that signed the app.
      case GoogleSignInExceptionCode.unknownError
          when error.description?.contains('[28444]') ?? false:
        throw _notConfigured(error.description!);
      default:
        throw AuthFailure(AuthFailureReason.unknown, developerHint: '$error');
    }
  } on Object catch (error) {
    throw AuthFailure(AuthFailureReason.unknown, developerHint: '$error');
  }
  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw const AuthFailure(
      AuthFailureReason.unknown,
      developerHint: 'Google gave no ID token.',
    );
  }
  return IdTokenCredential(issuer: _issuer, idToken: idToken);
}

/// The failure of a sign-in with Google that the app or the Google project
/// is not set up for, with [message], what Google answered.
AuthFailure _notConfigured(String message) => AuthFailure(
      AuthFailureReason.notConfigured,
      developerHint:
          'Google sign-in is not set up for the app ($message). See the '
          'section "{{{readme}}}" of the README of the app.',
    );

/// The icon of the button of Google sign-in: the "G" of Google in its own
/// colours, at the size of the icons of the button, as the branding
/// guidelines of Google ask of a custom button.
class GoogleSignInIcon extends StatelessWidget {
  /// Creates the icon.
  const GoogleSignInIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size;
    // The label of the button names Google.
    return Image.asset(
      _logo,
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}
