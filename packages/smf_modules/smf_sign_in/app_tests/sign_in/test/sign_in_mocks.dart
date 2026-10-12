// What the tests that continuous integration runs in an app with the
// sign-in module need of the module, whichever module they test: the
// guards of the routes of the sign-in let them through. Without it, an app
// that asks for an account shows the sign-in when a test starts it, as on
// its first launch, in place of the screen that the test expects. The
// matrix sets it up before the tests of every module of such an app
// (MatrixAppTest.mocks).
//
// The account goes through the session of the app, so it is an account of
// whichever module provides the sign-in, whose own mocks keep the accounts
// of the tests in memory. A test that needs the app without that account
// signs out first, as the tests of the sign-in itself do, but for the one
// of the first launch, which tells the mocks to sign nobody up
// (signInIsUnderTest).
import 'dart:async';

import 'package:{{app_name}}/core/auth/app_session.dart';

/// The email address of the account that [signUpTestAccount] signs up.
const String testAccountEmail = 'test-account@sign-in-tests.example.com';

/// The password of that account.
const String testAccountPassword = 'Sign-in-tests-2468';

/// Whether [signUpTestAccount] leaves the app as its first launch finds
/// it, with nobody signed in.
///
/// A test file of the sign-in sets it while its main() declares its tests,
/// which is before the matrix sets up the mocks of the app for them.
bool signInIsUnderTest = false;

/// Signs an account up before the app starts, unless the test file is the
/// one of the first launch of the sign-in itself.
///
/// The session of the app has not started yet, so the call waits for the
/// start-up of the app, which is over once the account is signed in: the
/// first frame of the app has its user. In an app that signs an anonymous
/// user in when it starts, that user gets the account. A test file that
/// never starts the app leaves the call waiting, which harms nothing.
void signUpTestAccount() {
  if (signInIsUnderTest) return;
  unawaited(
    appSession.signUp(email: testAccountEmail, password: testAccountPassword),
  );
}
