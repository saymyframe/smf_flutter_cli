// A test that continuous integration runs in the apps whose modules give
// the auth role a way to sign in with an identity provider, whichever
// modules provide the role and the ways to sign in: the service of the
// provider keeps the contract of AuthService for credentials, with each
// issuer of the ways to sign in of the app. Signing in with the credential
// of a new identity creates its user, whom signing in with it again finds,
// in place of whoever is signed in. linkWith gives the anonymous user who
// is signed in the identity, and the user keeps the id. linkWith of an
// identity that another user has fails with credentialInUse and changes
// nothing, and signInWith takes the identical credential then. For an
// identity whose email address has an account that signs in with a
// password, linkWith fails with accountExistsWithOtherMethod, and
// signInWith fails so too or signs in to that account. A call for the user
// who is signed in fails when nobody is. And deleteAccount with a fresh
// credential deletes the user whom a start found on the device, and one of
// another user fails with invalidCredentials and deletes nothing.
//
// It knows only the role, and calls the service itself, through
// createAuthService(), as the test of the service of the role does. It
// builds test tokens of identities of its own for each issuer of the app
// (see auth_methods.dart), which the provider takes in the tests of an app.
// The start-up of the app runs first, as on a device, with the mocks of the
// platform side of every module of the app, which the matrix sets up before
// the tests of each test file (flutter_test_config.dart). Each test signs
// out first, and uses identities and email addresses of its own. Each
// expectation gives its reason, which a provider of the role with a known
// bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';

import '../auth_role/auth_role.dart';
import 'auth_methods.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  test('the app has a way to sign in with an identity provider', () {
    expect(
      issuersOfApp,
      isNotEmpty,
      reason: 'The matrix adds the test to the apps whose modules give the '
          'auth role a way to sign in, which appSignInMethods lists.',
    );
  });

  testWidgets(
    'signing in with the credential of a new identity creates its user, and '
    'signing in with it again finds that user, in place of whoever is signed '
    'in',
    (tester) async {
      await startUp(tester);
      // For each issuer of the app: the user that the first sign-in
      // created, and the id of the user after each later sign-in.
      final created = <String, AuthUser?>{};
      final later = <String, List<String?>>{};

      await inRealTime(tester, 'signing in with credentials', () async {
        final service = createAuthService();
        for (final (index, issuer) in issuersOfApp.indexed) {
          final credential = credentialOf(issuer, 'sign-in-$index');
          await service.signOut();
          await service.signInWith(credential);
          created[issuer] = service.currentUser;
          await service.signOut();
          await service.signInWith(credential);
          final again = service.currentUser?.uid;
          await service.signUp(
            email: addressOf('methods-password-$index'),
            password: password,
          );
          await service.signInWith(credential);
          final afterAccount = service.currentUser?.uid;
          await service.signOut();
          await service.signInAnonymously();
          await service.signInWith(credential);
          later[issuer] = [again, afterAccount, service.currentUser?.uid];
        }
      });

      expect(
        {
          for (final MapEntry(key: issuer, value: user) in created.entries)
            issuer: (userWithIssuers(user), user?.uid.isNotEmpty),
        },
        {
          for (final issuer in issuersOfApp) issuer: (accountWith(issuer), true)
        },
        reason: 'When signInWith() of the credential of a new identity '
            'completes, the user of the service is the new user of that '
            'identity, who has an id, is not anonymous and lists the issuer '
            'of the credential.',
      );
      expect(
        {
          for (final MapEntry(key: issuer, value: uids) in later.entries)
            issuer: uids,
        },
        {
          for (final issuer in issuersOfApp)
            issuer: List.filled(3, created[issuer]?.uid),
        },
        reason: 'signInWith() of the credential of an identity that has a '
            'user signs in to that user, with the same id, also in place of '
            'the user of another account and of an anonymous user.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'linkWith gives the anonymous user who is signed in the identity, and '
    'the user keeps the id',
    (tester) async {
      await startUp(tester);
      // For each issuer of the app: the anonymous user, the user once the
      // link completed, and the user of a sign-in with the identity after a
      // sign-out.
      final anonymous = <String, AuthUser?>{};
      final linked = <String, AuthUser?>{};
      final again = <String, AuthUser?>{};

      await inRealTime(tester, 'linking credentials', () async {
        final service = createAuthService();
        for (final (index, issuer) in issuersOfApp.indexed) {
          final credential = credentialOf(issuer, 'linked-$index');
          await service.signOut();
          await service.signInAnonymously();
          anonymous[issuer] = service.currentUser;
          await service.linkWith(credential);
          linked[issuer] = service.currentUser;
          await service.signOut();
          await service.signInWith(credential);
          again[issuer] = service.currentUser;
        }
      });

      expect(
        {
          for (final issuer in issuersOfApp)
            issuer: userWithIssuers(anonymous[issuer]),
        },
        {for (final issuer in issuersOfApp) issuer: 'an anonymous user'},
        reason: 'signInAnonymously() signs in as an anonymous user.',
      );
      expect(
        {
          for (final issuer in issuersOfApp)
            issuer: (
              userWithIssuers(linked[issuer]),
              linked[issuer]?.uid == anonymous[issuer]?.uid,
            ),
        },
        {
          for (final issuer in issuersOfApp) issuer: (accountWith(issuer), true)
        },
        reason: 'linkWith keeps the id of the anonymous user: the user who is '
            'signed in gets the identity of the credential, is no longer '
            'anonymous and lists its issuer.',
      );
      expect(
        {
          for (final issuer in issuersOfApp)
            issuer: (
              userWithIssuers(again[issuer]),
              again[issuer]?.uid == anonymous[issuer]?.uid,
            ),
        },
        {
          for (final issuer in issuersOfApp) issuer: (accountWith(issuer), true)
        },
        reason: 'The identity that an anonymous user got is the identity of '
            'that user: signing in with it again finds the same id.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'linkWith of an identity that another user has fails with '
    'credentialInUse and changes nothing, and signInWith of the identical '
    'credential signs in to that user then',
    (tester) async {
      await startUp(tester);
      // For each issuer of the app: what the link failed with and the user
      // after it, as the anonymous user who asked, and what the sign-in
      // after it ended with and the user after it, as the user of the
      // identity.
      final links = <String, (String, String, bool)>{};
      final signIns = <String, (String, String, bool)>{};

      await inRealTime(tester, 'linking credentials in use', () async {
        final service = createAuthService();
        for (final (index, issuer) in issuersOfApp.indexed) {
          final credential = credentialOf(issuer, 'in-use-$index');
          await service.signOut();
          await service.signInWith(credential);
          final owner = service.currentUser?.uid;
          await service.signOut();
          await service.signInAnonymously();
          final guest = service.currentUser?.uid;
          final link = await errorOf(() => service.linkWith(credential));
          links[issuer] = (
            outcomeOf(link),
            userWithIssuers(service.currentUser),
            service.currentUser?.uid == guest,
          );
          final signIn = await errorOf(() => service.signInWith(credential));
          signIns[issuer] = (
            outcomeOf(signIn),
            userWithIssuers(service.currentUser),
            service.currentUser?.uid == owner,
          );
        }
      });

      expect(
        links,
        {
          for (final issuer in issuersOfApp)
            issuer: (
              AuthFailureReason.credentialInUse.name,
              'an anonymous user',
              true,
            ),
        },
        reason: 'linkWith() of an identity that another user has fails with '
            'credentialInUse, and the anonymous user stays signed in, with '
            'the same id.',
      );
      expect(
        signIns,
        {
          for (final issuer in issuersOfApp)
            issuer: ('completed', accountWith(issuer), true),
        },
        reason: 'signInWith() takes the identical credential that linkWith() '
            'refused just before, and signs in to the user of its identity.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'for an identity whose email address has an account that signs in with a '
    'password, linkWith fails with accountExistsWithOtherMethod, and '
    'signInWith fails so too or signs in to that account',
    (tester) async {
      await startUp(tester);
      // For each issuer of the app: what the link failed with and the user
      // after it, and what became of the sign-in after it.
      final links = <String, (String, String, bool)>{};
      final signIns = <String, String>{};

      await inRealTime(tester, 'linking credentials of an address', () async {
        final service = createAuthService();
        for (final (index, issuer) in issuersOfApp.indexed) {
          final email = addressOf('methods-other-$index');
          await service.signOut();
          await service.signUp(email: email, password: password);
          final account = service.currentUser?.uid;
          await service.signOut();
          await service.signInAnonymously();
          final guest = service.currentUser?.uid;
          final credential = credentialOf(
            issuer,
            'other-method-$index',
            email: email,
          );
          final link = await errorOf(() => service.linkWith(credential));
          links[issuer] = (
            outcomeOf(link),
            userWithIssuers(service.currentUser),
            service.currentUser?.uid == guest,
          );
          final signIn = await errorOf(() => service.signInWith(credential));
          final user = service.currentUser;
          signIns[issuer] = switch (signIn) {
            null when user?.uid == account =>
              'signed in to the account of the address',
            AuthFailure(
              reason: AuthFailureReason.accountExistsWithOtherMethod,
            )
                when user?.uid == guest =>
              'failed with accountExistsWithOtherMethod, and left the '
                  'anonymous user',
            _ => 'ended with ${outcomeOf(signIn)}, and left '
                '${userWithIssuers(user)}',
          };
        }
      });

      expect(
        links,
        {
          for (final issuer in issuersOfApp)
            issuer: (
              AuthFailureReason.accountExistsWithOtherMethod.name,
              'an anonymous user',
              true,
            ),
        },
        reason: 'linkWith() of an identity whose email address has an '
            'account of another user fails with accountExistsWithOtherMethod, '
            'and the anonymous user stays signed in, with the same id.',
      );
      for (final issuer in issuersOfApp) {
        expect(
          signIns[issuer],
          anyOf(
            'signed in to the account of the address',
            'failed with accountExistsWithOtherMethod, and left the anonymous '
                'user',
          ),
          reason: 'signInWith() of an identity whose email address has an '
              'account that signs in in another way fails with '
              'accountExistsWithOtherMethod, and leaves whoever is signed in, '
              'or signs in to that account, as the backend of the provider '
              'decides ($issuer).',
        );
      }
    },
    timeout: timeout,
  );

  testWidgets(
    'a call with a credential for the user who is signed in fails with '
    'recentSignInRequired when nobody is signed in',
    (tester) async {
      await startUp(tester);
      final calls = <String, (String, String, String)>{};

      await inRealTime(tester, 'calling without a user', () async {
        final service = createAuthService();
        for (final (index, issuer) in issuersOfApp.indexed) {
          final credential = credentialOf(issuer, 'nobody-$index');
          await service.signOut();
          final link = await errorOf(() => service.linkWith(credential));
          final deletion = await errorOf(
            () => service.deleteAccount(fresh: credential),
          );
          calls[issuer] = (
            outcomeOf(link),
            outcomeOf(deletion),
            userWithIssuers(service.currentUser),
          );
        }
      });

      expect(
        calls,
        {
          for (final issuer in issuersOfApp)
            issuer: (
              AuthFailureReason.recentSignInRequired.name,
              AuthFailureReason.recentSignInRequired.name,
              'nobody',
            ),
        },
        reason: 'linkWith() and deleteAccount() with a fresh credential fail '
            'with recentSignInRequired when nobody is signed in, and sign '
            'nobody in.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'deleteAccount with a fresh credential deletes the user whom a start '
    'found on the device, and one of another user fails with '
    'invalidCredentials and deletes nothing',
    (tester) async {
      await startUp(tester);
      // For each issuer of the app: what the deletion with the credential
      // of another user ended with and the user after it, what the deletion
      // with the credential of the user ended with and the user after it,
      // and whether a sign-in with the identity of the deleted user then
      // creates another user.
      final wrong = <String, (String, String, bool)>{};
      final right = <String, (String, String)>{};
      final gone = <String, bool>{};

      await inRealTime(tester, 'deleting users after a start', () async {
        for (final (index, issuer) in issuersOfApp.indexed) {
          final other = credentialOf(issuer, 'other-user-$index');
          final mine = credentialOf(issuer, 'deleted-$index');
          var service = createAuthService();
          await service.signOut();
          await service.signInWith(other);
          await service.signOut();
          await service.signInWith(mine);
          final uid = service.currentUser?.uid;
          // The next start of the app, which finds the user on the device,
          // and loses that the user signed in a short while ago.
          await initAuth();
          service = createAuthService();
          final ofOther = await errorOf(
            () => service.deleteAccount(fresh: other),
          );
          wrong[issuer] = (
            outcomeOf(ofOther),
            userWithIssuers(service.currentUser),
            service.currentUser?.uid == uid,
          );
          final ofUser = await errorOf(
            () => service.deleteAccount(fresh: mine),
          );
          right[issuer] = (
            outcomeOf(ofUser),
            userWithIssuers(service.currentUser),
          );
          await service.signInWith(mine);
          gone[issuer] = service.currentUser?.uid != uid;
          // What the deletion of that user ends with, the expectations
          // below tell.
          await errorOf(() => service.deleteAccount(fresh: mine));
        }
      });

      expect(
        wrong,
        {
          for (final issuer in issuersOfApp)
            issuer: (
              AuthFailureReason.invalidCredentials.name,
              accountWith(issuer),
              true,
            ),
        },
        reason: 'deleteAccount() with a fresh credential of another user '
            'fails with invalidCredentials and deletes nothing: the user stays '
            'signed in.',
      );
      expect(
        right,
        {for (final issuer in issuersOfApp) issuer: ('completed', 'nobody')},
        reason: 'deleteAccount() with a fresh credential of the user signs the '
            'user in again first, so it deletes a user whom a start found on '
            'the device, and nobody is signed in when it completes.',
      );
      expect(
        gone,
        {for (final issuer in issuersOfApp) issuer: true},
        reason: 'The deletion takes the identity with the user: signing in '
            'with it again creates another user.',
      );
    },
    timeout: timeout,
  );
}
