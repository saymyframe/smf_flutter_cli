/// The identity providers whose credentials the service of the module
/// takes, by the issuer of their ID tokens, each with its name among the
/// sign-in methods of the Firebase console: Google and Apple. The service
/// in `lib/core/auth/firebase_auth_service.dart` of the app has them in the
/// same form.
const identityProviders = {
  'https://accounts.google.com': 'Google',
  'https://appleid.apple.com': 'Apple',
};
