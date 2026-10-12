// What the tests of the auth role share, in the apps with the role,
// whichever module provides it: the mode that the role chose for the app,
// the start-up of the app, which runs once for the tests of a file, what
// runs a call in real time and returns what it failed with, and what tells
// who the session of the app says uses it.
//
// It knows only the role. The matrix fills in the mode, from the choice of
// the role for the app.
//
// An app may have a module whose mocks sign a user in before the app
// starts, such as a module with a guard that asks for an account, which
// opens the guard for the tests of the other modules. The first start-up
// of a test file then ends with that account signed in. So no test here
// expects anything of who is signed in right after the start-up: each
// signs out first, and uses email addresses of its own (addressOf).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';

/// The mode that the auth role chose for the app when it was generated, as
/// the matrix read it from the choice of the role: the name of an
/// [AuthMode].
const String chosenMode = '{{auth_mode}}';

/// The password of the accounts of the tests.
const String password = 'Auth-role-tests-2468';

/// Another password, which no account of the tests has.
const String wrongPassword = 'Auth-role-tests-1357';

/// An email address that only the tests of the auth role use: the one of
/// [name], which each test gives another one, so that no test finds the
/// account of another.
String addressOf(String name) => '$name@auth-role-tests.example.com';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the provider, does not
/// wait for the fake time of the test. An error of [action] fails the
/// test, which tester.runAsync would only report to the handler of the
/// errors of Flutter.
Future<void> inRealTime(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  Object? error;
  StackTrace? stackTrace;
  await tester.runAsync(() async {
    try {
      await action();
    } on Object catch (thrown, stack) {
      error = thrown;
      stackTrace = stack;
    }
  });
  if (error != null) fail('$what threw $error\n$stackTrace');
}

/// The problem of the start-up of the app, which runs once for the tests of
/// a file: `null` before it runs, and empty if it passed.
String? _startUpProblem;

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, unless a test of the file ran it already, and
/// fails the test if it failed. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the widget
/// of an error go back to those of the test once it returns.
Future<void> startUp(WidgetTester tester) async {
  if (_startUpProblem == null) {
    final onError = FlutterError.onError;
    final onPlatformError = PlatformDispatcher.instance.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    try {
      _startUpProblem = '';
      await inRealTime(tester, 'bootstrap()', bootstrap);
    } on TestFailure catch (failure) {
      _startUpProblem = failure.message ?? 'bootstrap() failed';
    } finally {
      FlutterError.onError = onError;
      PlatformDispatcher.instance.onError = onPlatformError;
      ErrorWidget.builder = errorWidgetBuilder;
    }
  }
  if (_startUpProblem case final problem? when problem.isNotEmpty) {
    fail(problem);
  }
}

/// What [call] failed with, or `null` if it completed.
Future<Object?> errorOf(Future<void> Function() call) async {
  try {
    await call();
    return null;
  } on Object catch (error) {
    return error;
  }
}

/// Matches what a call of sign-in fails with for [reason]: an [AuthFailure]
/// with that reason.
Matcher failsWith(AuthFailureReason reason) => isA<AuthFailure>().having(
      (failure) => failure.reason,
      'reason',
      reason,
    );

/// Waits in real time until [holds], for two seconds at most: for what
/// happens a moment after a call, such as an event of a stream that a
/// listener gets. A test then expects what [holds] says, with its reason.
Future<void> waitUntil(WidgetTester tester, bool Function() holds) =>
    inRealTime(tester, 'waiting', () async {
      for (var turn = 0; turn < 200 && !holds(); turn++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

/// A user as a test compares it: nobody, an anonymous user, or the user of
/// the account of an email address.
String userOf(AuthUser? user) => switch (user) {
      null => 'nobody',
      AuthUser(isAnonymous: true, :final email) => email == null
          ? 'an anonymous user'
          : 'an anonymous user with the address $email',
      AuthUser(:final email) => 'the account of $email',
    };

/// Who the session of the app says uses it, and its two flags, as a test
/// compares them.
String sessionNow() {
  final who = switch (appSession.value) {
    SignedOutSession() => 'nobody',
    AnonymousSession() => 'an anonymous user',
    AccountSession(:final email) => 'the account of $email',
  };
  return '$who, allowsApp ${appSession.allowsApp.value}, '
      'hasAccount ${appSession.hasAccount.value}';
}

/// What [sessionNow] says while the account of [email] is signed in, in
/// every mode.
String sessionOfAccount(String email) =>
    'the account of $email, allowsApp true, hasAccount true';

/// What [sessionNow] says while no account is signed in, once the session
/// did what its mode says: nobody uses the app in the modes required and
/// guest, of which only guest lets the user see the app, and an anonymous
/// user in the mode anonymous.
String get sessionWithoutAccount => switch (authMode) {
      AuthMode.required => 'nobody, allowsApp false, hasAccount false',
      AuthMode.guest => 'nobody, allowsApp true, hasAccount false',
      AuthMode.anonymous =>
        'an anonymous user, allowsApp true, hasAccount false',
    };

/// What [sessionNow] says while the provider has nobody signed in and the
/// session did not sign anybody in: nobody uses the app, in every mode.
String get sessionOfNobody => switch (authMode) {
      AuthMode.required => 'nobody, allowsApp false, hasAccount false',
      AuthMode.guest ||
      AuthMode.anonymous =>
        'nobody, allowsApp true, hasAccount false',
    };
