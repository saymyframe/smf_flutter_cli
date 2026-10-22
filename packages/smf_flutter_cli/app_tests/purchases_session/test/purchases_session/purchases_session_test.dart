// A test that continuous integration runs in the apps with the purchases
// role and the auth role, whichever modules provide them, in each mode of
// the auth role: appPurchases follows the session of the app, so the
// purchases belong to its user, as the purchases role says. A user without
// an account who buys a plan keeps the premium access after a sign-up: in
// the modes required and guest the new account takes over the purchases of
// the user of the device, and in the mode anonymous it keeps the id of the
// anonymous user who bought. After a sign-out, the next user of the
// device has none of the purchases of the user who signed out, whose
// account has them again after a sign-in. The user without an account keeps
// what it bought at the next start of the app: the user of the device in
// the modes required and guest, and the anonymous user in the mode
// anonymous. And a sign-in to an account that exists already leaves the
// purchases with the user of the device, while the next user of the device
// after that account signs out is a new one, with nothing bought.
//
// It knows only the two roles, and reads the mode of the app from authMode.
// The start-up of the app runs first, as on a device, since it starts the
// session and then the purchases, which follow it, with the mocks of the
// platform side of every module of the app, which the matrix sets up before
// the tests of each test file (flutter_test_config.dart). The mocks of a
// module may have signed a user up before the start-up, or bought a plan,
// so each test first makes the user of the device a new one, with nothing
// bought, and uses email addresses of its own. It uses the helpers of the
// test of the purchases role, which runs in every app with the role, and
// the convention of the mocks of every provider of that role
// (purchases_role.dart). Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/purchases/app_purchases.dart';

import '../purchases_role/purchases_role.dart';

/// The password of the accounts of the tests.
const String _password = 'Purchases-session-2468';

/// How many email addresses the tests of the file made.
int _addresses = 0;

/// An email address that only the tests of the purchases with sign-in use,
/// and only once: that of [name], with the time and a number of its own.
String _addressOf(String name) =>
    '$name-${DateTime.now().microsecondsSinceEpoch}-${++_addresses}'
    '@purchases-session-tests.example.com';

/// Runs [call] of the session, which [what] names, in real time, and waits
/// until appPurchases has done what the change of the user set off: a call
/// of appPurchases takes its turn after it. Returns what [call] failed
/// with, or `null`.
Future<Object?> _step(
  WidgetTester tester,
  String what,
  Future<void> Function() call,
) async {
  Object? failure;
  await inRealTime(tester, what, () async {
    failure = await errorOf(call);
    await appPurchases.plans();
  });
  return failure;
}

/// Makes the user of the device a new one with nothing bought, in every
/// mode: signs a throwaway account up, which takes over what the user of
/// the device bought, and signs out. The next user follows the user of an
/// account, so it is a new user of the device, or in the mode anonymous a
/// new anonymous user.
Future<void> _newUserOfDevice(WidgetTester tester) async {
  await _step(tester, 'a sign-out', appSession.signOut);
  await _step(
    tester,
    'a throwaway sign-up',
    () =>
        appSession.signUp(email: _addressOf('throwaway'), password: _password),
  );
  await _step(tester, 'the sign-out of the throwaway', appSession.signOut);
}

/// Buys the first plan of the offer for the user of the app, in real time,
/// and returns what the purchase failed with, or `null`.
Future<Object?> _buy(WidgetTester tester) async {
  Object? failure;
  await inRealTime(tester, 'buying a plan', () async {
    final plans = await appPurchases.plans();
    failure = await errorOf(() => appPurchases.purchase(plans.first));
    // A change of the access that the provider tells of a moment later
    // shows too.
    await aMoment();
  });
  return failure;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'a user without an account who buys a plan keeps the premium access '
    'after a sign-up, in every mode',
    (tester) async {
      await startUp(tester);
      await _newUserOfDevice(tester);
      final before = describe(appPurchases.value);
      final uidBefore = appSession.value.uid;
      final failure = await _buy(tester);
      final bought = describe(appPurchases.value);
      final signUp = await _step(
        tester,
        'a sign-up',
        () =>
            appSession.signUp(email: _addressOf('buyer'), password: _password),
      );
      final after = describe(appPurchases.value);

      expect(
        before,
        'no access',
        reason: 'After a sign-out, the user of the device is a new one, with '
            'nothing bought, and in the mode anonymous so is the next '
            'anonymous user.',
      );
      expect(
        (failure, signUp, bought.startsWith('premium access')),
        (null, null, true),
        reason: 'A purchase by a user without premium access succeeds, and so '
            'does a sign-up.',
      );
      expect(
        after,
        bought,
        reason: 'A user without an account who buys a plan keeps the premium '
            'access after a sign-up: in the modes required and guest the new '
            'account takes over the purchases of the user of the device, as '
            'a user that no identification named before, and in the mode '
            'anonymous the account keeps the id of the anonymous user.',
      );
      if (authMode == AuthMode.anonymous) {
        expect(
          appSession.value.uid,
          uidBefore,
          reason: 'In the mode anonymous, a sign-up gives the anonymous user '
              'who bought the account: the user keeps the id.',
        );
      }
    },
    timeout: timeout,
  );

  testWidgets(
    'after a sign-out, the next user of the device has none of the purchases '
    'of the user who signed out, and a sign-in to the account gives them '
    'back',
    (tester) async {
      await startUp(tester);
      await _newUserOfDevice(tester);
      final email = _addressOf('account');
      final signUp = await _step(
        tester,
        'a sign-up',
        () => appSession.signUp(email: email, password: _password),
      );
      final ofAccount = describe(appPurchases.value);
      final failure = await _buy(tester);
      final bought = describe(appPurchases.value);
      await _step(tester, 'a sign-out', appSession.signOut);
      final ofNextUser = describe(appPurchases.value);
      final signIn = await _step(
        tester,
        'a sign-in',
        () => appSession.signIn(email: email, password: _password),
      );
      final backToAccount = describe(appPurchases.value);

      expect(
        ofNextUser,
        'no access',
        reason: 'Without a restore, the next user of the device never gets '
            'the purchases of the one who signed out: after a sign-out the '
            'user of the device is a new one, with nothing bought, and in '
            'the mode anonymous so is the next anonymous user.',
      );
      expect(
        (signUp, ofAccount, failure, signIn),
        (null, 'no access', null, null),
        reason: 'A new account of a user of the device without purchases has '
            'nothing bought, and its purchase, the sign-out and the sign-in '
            'succeed.',
      );
      expect(
        (bought.startsWith('premium access'), backToAccount),
        (true, bought),
        reason: 'The purchases of an account stay with it: a sign-in to the '
            'account gives its premium access back.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the user without an account keeps what it bought at the next start of '
    'the app, in every mode',
    (tester) async {
      await startUp(tester);
      await _newUserOfDevice(tester);
      final failure = await _buy(tester);
      final bought = describe(appPurchases.value);
      await inRealTime(tester, 'initPurchases()', initPurchases);
      final next = describe(appPurchases.value);

      expect(
        next,
        bought,
        reason: 'The store keeps what the user without an account bought, and '
            'the device keeps that user from one launch of the app to the '
            'next, so the next start has its premium access: the user of the '
            'device in the modes required and guest, and the anonymous user '
            'in the mode anonymous.',
      );
      expect(
        (failure, bought.startsWith('premium access')),
        (null, true),
        reason: 'A purchase by a user without premium access succeeds, and '
            'gives that user premium access.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a sign-in to an account that exists already leaves the purchases with '
    'the user of the device, and the next user of the device after a '
    'sign-out of that account has none of them',
    (tester) async {
      await startUp(tester);
      await _newUserOfDevice(tester);
      final email = _addressOf('existing');
      await _step(
        tester,
        'a sign-up',
        () => appSession.signUp(email: email, password: _password),
      );
      await _step(tester, 'a sign-out', appSession.signOut);
      final failure = await _buy(tester);
      final bought = describe(appPurchases.value);
      final signIn = await _step(
        tester,
        'a sign-in',
        () => appSession.signIn(email: email, password: _password),
      );
      final ofAccount = describe(appPurchases.value);
      await _step(tester, 'the sign-out of the account', appSession.signOut);
      final ofNextUser = describe(appPurchases.value);

      expect(
        ofNextUser,
        'no access',
        reason: 'After the sign-out of an account, the next user of the device '
            'is a new one, with nothing bought, and not the user of the '
            'device who bought before the sign-in, whose purchases come back '
            'only through a restore. In the mode anonymous, so is the next '
            'anonymous user.',
      );
      expect(
        ofAccount,
        'no access',
        reason: 'A sign-in to an account that exists already leaves the '
            'purchases with the user of the device, or in the mode anonymous '
            'with the anonymous user who bought.',
      );
      expect(
        (failure, signIn, bought.startsWith('premium access')),
        (null, null, true),
        reason: 'A purchase by a user without premium access succeeds, and so '
            'does a sign-in.',
      );
    },
    timeout: timeout,
  );
}
