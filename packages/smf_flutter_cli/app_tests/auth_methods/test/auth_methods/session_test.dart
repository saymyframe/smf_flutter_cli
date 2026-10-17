// A test that continuous integration runs in the apps whose modules give
// the auth role a way to sign in with an identity provider, whichever
// modules provide the role and the ways to sign in, in each mode of the
// role: the session of the app signs in with the credential of each way to
// sign in of the app, which the function of the way to sign in returns. An
// anonymous user gets the identity and keeps the id. A later anonymous user
// signs in to the account of that identity, and so does a sign-in without a
// user. The next start of the app finds that account on the device, and
// appSession.deleteAccount() deletes it: for a way to sign in that
// revokesOnDeletion, it asks the way to sign in for a credential again and
// gives it to the service, which signs the user in again with it, so the
// deletion needs no recent sign-in. And once the account is deleted, the
// next sign-in with the identity creates another user.
//
// It knows only the role. It calls the function of each way to sign in
// with the platform of the app set to one that the way to sign in works on,
// under the mocks of the module of the way to sign in, which the matrix
// sets up before the tests of each test file (flutter_test_config.dart):
// they return a credential of one identity of their own, the same each
// time (see auth_methods.dart). An anonymous user comes from the service,
// through createAuthService(), in the modes in which the session signs in
// none itself. The start-up of the app runs first, as on a device. Each
// expectation gives its reason, which a provider of the role with a known
// bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/sign_in_methods.dart';

import '../auth_role/auth_role.dart';
import 'auth_methods.dart';

/// Waits in real time, for two seconds at most, until [holds].
Future<void> _until(bool Function() holds) async {
  for (var turn = 0; turn < 200 && !holds(); turn++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Signs the user out, and in as an anonymous user unless the session did
/// so itself, as it does in the mode anonymous, and returns the id of that
/// user, once the session has it.
Future<String?> _anonymousUser() async {
  await appSession.signOut();
  if (appSession.value is! AnonymousSession) {
    await createAuthService().signInAnonymously();
  }
  await _until(() => appSession.value is AnonymousSession);
  return appSession.value.uid;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the session signs in with each way to sign in of the app: an anonymous '
    'user gets the identity and keeps the id, a later user signs in to its '
    'account, and once the account is deleted the identity has a new user',
    (tester) async {
      await startUp(tester);
      // For each issuer of the app: what the function of its way to sign in
      // returned, whether the later anonymous user was another one, and
      // after each step what the step ended with, what the session says and
      // whether its user is the first anonymous user.
      final credentials = <String, String>{};
      final laterIsAnother = <String, bool>{};
      final steps = <String, Map<String, (String, String, bool)>>{};

      for (final method in appSignInMethods) {
        final issuer = method.issuer;
        final ofMethod = steps[issuer] = {};
        // The function of the way to sign in, and the session when it
        // deletes an account, ask the platform of the app.
        debugDefaultTargetPlatformOverride = method.platforms.first;
        try {
          await inRealTime(tester, 'signing in with $issuer', () async {
            Future<(String, String, bool)> step(
              String? first,
              Future<void> Function() call,
            ) async {
              final error = await errorOf(call);
              return (
                outcomeOf(error),
                sessionWithIssuers(),
                appSession.value.uid == first,
              );
            }

            Future<void> signIn() async {
              final credential = await method.credential();
              if (credential == null) {
                throw StateError('The function returned no credential.');
              }
              await appSession.signInWith(credential);
            }

            final credential = await method.credential();
            credentials[issuer] = switch (credential) {
              IdTokenCredential(issuer: final of) when of == issuer =>
                'a credential of its issuer',
              _ => '$credential',
            };
            final first = await _anonymousUser();
            ofMethod['link'] = await step(first, signIn);
            final second = await _anonymousUser();
            laterIsAnother[issuer] = second != null && second != first;
            ofMethod['a later anonymous user'] = await step(first, signIn);
            // The provider signs the user out, so the session signs nobody
            // in, in the mode anonymous too.
            await createAuthService().signOut();
            await _until(() => appSession.value is SignedOutSession);
            ofMethod['without a user'] = await step(first, signIn);
            // The next start of the app, which finds the user of the account
            // on the device, and loses that the user signed in a short while
            // ago. A way to sign in that revokesOnDeletion is asked for a
            // credential again, with which the provider signs the user in
            // again, so the deletion needs no recent sign-in. Without it, the
            // provider may ask for one.
            await initAuth();
            ofMethod['the deletion'] = await step(first, () async {
              final error = await errorOf(appSession.deleteAccount);
              if (error
                  case AuthFailure(
                    reason: AuthFailureReason.recentSignInRequired,
                  ) when !method.revokesOnDeletion) {
                await signIn();
                await appSession.deleteAccount();
              } else if (error != null) {
                throw error;
              }
            });
            ofMethod['after the deletion'] = await step(first, signIn);
            // What the deletion of that user ends with, the expectations
            // below tell.
            await errorOf(appSession.deleteAccount);
          });
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }

      expect(
        credentials,
        {
          for (final issuer in issuersOfApp)
            issuer: 'a credential of its issuer',
        },
        reason: 'Under the mocks of its module, the function of a way to sign '
            'in returns a credential of its issuer.',
      );
      Map<String, (String, String, bool)> each(String name) => {
            for (final MapEntry(key: issuer, value: ofMethod) in steps.entries)
              issuer: ofMethod[name] ?? ('no step', '', false),
          };
      Map<String, (String, String, bool)> ofAccount({required bool first}) => {
            for (final issuer in issuersOfApp)
              issuer: ('completed', accountWith(issuer), first),
          };
      expect(
        each('link'),
        ofAccount(first: true),
        reason: 'An anonymous user who signs in with a way to sign in keeps '
            'the id: the session gives that user the identity with linkWith, '
            'and the user is no longer anonymous.',
      );
      expect(
        laterIsAnother,
        {for (final issuer in issuersOfApp) issuer: true},
        reason: 'After a sign-out, another anonymous user uses the app.',
      );
      expect(
        each('a later anonymous user'),
        ofAccount(first: true),
        reason: 'Another anonymous user who signs in with an identity that has '
            'an account signs in to that account: the link fails, and the '
            'session signs in with the identical credential.',
      );
      expect(
        each('without a user'),
        ofAccount(first: true),
        reason: 'Without a user, the session signs in with the credential at '
            'once, to the account of its identity.',
      );
      // What the session says without an account: an anonymous user in the
      // mode anonymous, who is a new one, and nobody in the other modes.
      final withoutAccount =
          authMode == AuthMode.anonymous ? 'an anonymous user' : 'nobody';
      expect(
        each('the deletion'),
        {
          for (final issuer in issuersOfApp)
            issuer: ('completed', withoutAccount, false),
        },
        reason: 'appSession.deleteAccount() deletes the account of a way to '
            'sign in that a start found on the device: for a way to sign in '
            'that revokesOnDeletion, it asks the way to sign in for a '
            'credential again and gives it to the service, which signs the '
            'user in again with it. The session then has no account, as after '
            'a sign-out.',
      );
      expect(
        each('after the deletion'),
        ofAccount(first: false),
        reason: 'The deletion takes the identity with the account: the next '
            'sign-in with it creates another user.',
      );
    },
    timeout: timeout,
  );
}
