import 'package:smf_contracts/smf_contracts.dart';

/// An identity provider whose credentials the service of the module takes:
/// its name among the sign-in methods of the Firebase console, its id in
/// Firebase Authentication, and what a way to sign in with it may need of
/// the Firebase project, which the script of the app sets up there.
typedef IdentityProvider = ({
  String name,
  String id,
  Set<SignInNeed> needs,
});

/// The identity providers whose credentials the service of the module
/// takes, by the issuer of their ID tokens: Google and Apple. The service
/// in `lib/core/auth/firebase_auth_service.dart` of the app has them in the
/// same form.
///
/// For Google, the script of the app registers the SHA of the debug key in
/// the Firebase project, downloads the Firebase files of the app again once
/// they have the clients of Google, the client of the iOS app and the
/// client of the server, and writes the URL scheme of the iOS app. Apple
/// needs none of these, and the module sets up nothing of a way to sign in
/// with Apple that needs one.
const Map<String, IdentityProvider> identityProviders = {
  'https://accounts.google.com': (
    name: 'Google',
    id: 'google.com',
    needs: {
      SignInNeed.androidCertificate,
      SignInNeed.iosClient,
      SignInNeed.serverClient,
    },
  ),
  'https://appleid.apple.com': (name: 'Apple', id: 'apple.com', needs: {}),
};
