import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Firebase Authentication';

/// The path in the app of the file with the service of the module.
const serviceFile = 'lib/core/auth/firebase_auth_service.dart';

/// The section of the module in the README of the app, which also has the
/// section of the auth role, with the mode of the app: where the ways to
/// sign in are enabled in the Firebase project, which of them a mode needs,
/// what the app does until they are, where the message of a password reset
/// comes from, and what becomes of an anonymous user who signs in to an
/// account.
final String readmeSection = '''
The app signs in with [Firebase Authentication](https://firebase.google.com/docs/auth) through `firebase_auth`: `$serviceFile` implements the sign-in service of the app on it.

The ways to sign in are enabled in the Firebase project, not in the code. Open the project that the app is configured for in the [Firebase console](https://console.firebase.google.com/), then Authentication > Sign-in method, and enable:

- Email/Password, in every mode of the app;
- Anonymous, when the mode of the app is `${AuthMode.anonymous.name}` (see the section ${AuthRole.readmeHeading}).

Until they are enabled, signing in and signing up fail with the reason `notConfigured`, and the `developerHint` of the failure has the link to that page of the project. In the mode `${AuthMode.anonymous.name}`, the app also starts without a user.

Firebase sends the message with which a user sets a new password from a template of the project: Authentication > Templates.

When an anonymous user signs in to an account that exists already, the anonymous user stays in the project, and nobody can sign in as that user again. A project that is upgraded to Firebase Authentication with Identity Platform can delete anonymous users that are older than 30 days: Authentication > Settings > User actions.
''';
