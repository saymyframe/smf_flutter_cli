// What the tests of the sign-in module share, in the apps with the module:
// the start of the app with main() of lib/main.dart, which the app entry
// role puts into every app, the screens of the sign-in and what they show,
// in the language that the device asks for, the way to the sign-in through
// the navigation of the router role, and a service of sign-in of the test,
// which a test gives the session of the app to script what a call does.
//
// They know the module, and of the rest of the app only its roles: the
// session of the auth role, whichever module provides the sign-in, in the
// mode that the app has as a constant, and the router, which shows the
// screens and leaves them. The matrix writes of_app.dart next to this
// file: the screen that the app starts on and the texts of the module in
// each language of the app. It sets up the mocks of the platform side of
// every module of the app before the tests of each test file
// (flutter_test_config.dart), so the start-up runs whatever other modules
// the app has, and a guard of the routes of another module is open.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/sign_in/reset_password_screen.dart';
import 'package:{{app_name}}/features/sign_in/sign_in_screen.dart';
import 'package:{{app_name}}/features/sign_in/sign_in_widgets.dart';
import 'package:{{app_name}}/features/sign_in/sign_up_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'of_app.dart';

/// The screens of the sign-in that the user sees: a screen below another
/// one is not among them.
final Finder signInScreen = find.byType(SignInScreen);
final Finder signUpScreen = find.byType(SignUpScreen);
final Finder resetScreen = find.byType(ResetPasswordScreen);

/// Every screen of the sign-in that the app has built, also below another
/// screen.
final Finder anySignInScreen = find.byWidgetPredicate(
  (widget) =>
      widget is SignInScreen ||
      widget is SignUpScreen ||
      widget is ResetPasswordScreen,
  skipOffstage: false,
);

/// The screen that the app starts on, also below another screen.
final Finder builtStartScreen = find.byType(startScreen, skipOffstage: false);

/// The texts of the module in the language that the device asks for (see
/// [useLanguage]), each by its name in the module.
Map<String, String> texts = signInTexts.values.first;

/// The text of the module with the name [name], on the screen that the
/// user sees.
Finder text(String name) => find.text(texts[name]!);

/// The name among the texts of the module of the text that the screens
/// show for [reason], the reason of a failure of a call. A reason that the
/// role gets later has no name here, and this file does not compile until
/// it has.
String failureTextOf(AuthFailureReason reason) => switch (reason) {
      AuthFailureReason.invalidCredentials => 'failureCredentials',
      AuthFailureReason.emailInUse => 'failureEmailInUse',
      AuthFailureReason.weakPassword => 'failureWeakPassword',
      AuthFailureReason.invalidEmail => 'emailInvalid',
      AuthFailureReason.userDisabled => 'failureDisabled',
      AuthFailureReason.tooManyAttempts => 'failureTooManyAttempts',
      AuthFailureReason.network => 'failureNoNetwork',
      AuthFailureReason.recentSignInRequired => 'failureRecentSignIn',
      AuthFailureReason.notConfigured => 'failureNotSetUp',
      AuthFailureReason.unknown => 'failureUnknown',
    };

/// The field of the email address of the form that the user sees.
final Finder emailField = find.byType(EmailField);

/// The field of the password of the form that the user sees.
final Finder passwordField = find.byType(PasswordField);

/// The button that submits the form that the user sees.
final Finder submitButton = find.byType(SubmitButton);

/// The action of the screen that the user sees that leads to the other
/// screen: from the sign-in to the sign-up, and back.
final Finder otherScreenAction = find.byType(OtherScreenAction);

/// The message of the failure of the last call of the form that the user
/// sees: its text for the user.
Finder failureMessage(AuthFailureReason reason) => find.descendant(
      of: find.byType(FailureMessage),
      matching: text(failureTextOf(reason)),
    );

/// Has the device ask for [language], a language of the app, which the app
/// follows while its user chose none. No call of a form is on its way, so
/// the screen settles.
Future<void> useLanguage(WidgetTester tester, String language) async {
  tester.platformDispatcher.localesTestValue = [Locale(language)];
  texts = signInTexts[language]!;
  await tester.pumpAndSettle();
}

/// Gives the app a phone tall enough for each form of the sign-in with the
/// message of a failure, so that a tap reaches every button without a
/// scroll.
void useTallPhone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(400, 1100)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the module that provides
/// the sign-in, does not wait for the fake time of the test. An error of
/// [action] fails the test, which tester.runAsync would only report to the
/// handler of the errors of Flutter.
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

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time
/// of the test waiting forever. An error of main() fails the test. The
/// handlers of errors that the start-up installs, such as those of crash
/// reporting, and the builder of the widget of an error go back to those
/// of the test once main() returns, so that flutter_test reports the
/// errors of the frames that follow, such as a widget that does not fit.
///
/// A test file starts the app once: the start-up of an app may not run
/// twice, and the entrance of a page of the sign-in counts the time from
/// the first frame of the file.
Future<void> startApp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await inRealTime(tester, 'main()', app.main);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  await tester.pumpAndSettle();
}

/// The navigator of the router role for the page that the user sees, as
/// the code of that page has it.
AppNavigator navigatorOf(WidgetTester tester) =>
    appRouter.navigatorOf(tester.element(find.byType(Navigator).last));

/// Asks the router for the sign-in over the page that the user sees, as the
/// code of a screen does that offers to sign in, and waits for the screen.
/// Nothing awaits the page: its future completes when the page is closed.
Future<void> pushSignIn(WidgetTester tester) async {
  unawaited(navigatorOf(tester).push<void>(const SignInSignInLocation()));
  await tester.pumpAndSettle();
}

/// Asks the router for each of the three routes of the sign-in in turn, in
/// place of the stack, as a link to it does, and waits for the screen after
/// each.
Future<void> followLinksToSignIn(WidgetTester tester) async {
  for (final AppLocation location in const [
    SignInSignInLocation(),
    SignInSignUpLocation(),
    SignInResetPasswordLocation(),
  ]) {
    navigatorOf(tester).go(location);
    await tester.pumpAndSettle();
  }
}

/// Whether the navigator at the root of the app has a page to go back to.
bool rootCanPop(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first).canPop();

/// Types [email] and [password] into the form that the user sees, each
/// unless it is `null`, as with a form that has no such field.
Future<void> fill(
  WidgetTester tester, {
  String? email,
  String? password,
}) async {
  if (email != null) await tester.enterText(emailField, email);
  if (password != null) await tester.enterText(passwordField, password);
  await tester.pump();
}

/// Taps [target], which starts a call of the module that provides the
/// sign-in, in real time, and waits there until [holds], for three seconds
/// at most, with a frame after each wait: the platform side of that module
/// may answer in real time. Then the screen settles, unless [settle] is
/// `false`, for a screen whose button may still spin. A test expects what
/// [holds] says, with its reason.
Future<void> tapInRealTime(
  WidgetTester tester,
  Finder target, {
  required bool Function() until,
  bool settle = true,
}) async {
  await inRealTime(tester, 'a tap that starts a call of sign-in', () async {
    await tester.tap(target);
    for (var turn = 0; turn < 300 && !until(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  if (settle) await tester.pumpAndSettle();
}

/// Whether the button that submits the form that the user sees shows that a
/// call is on its way.
bool submitSpins() => find
    .descendant(
      of: submitButton,
      matching: find.byType(CircularProgressIndicator),
    )
    .evaluate()
    .isNotEmpty;

/// Who the session of the app says uses it, as a test compares it.
String sessionNow() => switch (appSession.value) {
      SignedOutSession() => 'nobody',
      AnonymousSession() => 'an anonymous user',
      AccountSession(:final email) => 'the account of $email',
    };

/// A service of sign-in of the test, which keeps its user in memory: a
/// test gives it to the session of the app with appSession.start(), once
/// the app has started, and then says what its calls do. Every call
/// answers in the turn of the test that made it, so a test goes on with a
/// frame and needs no real time. It starts with nobody signed in.
final class ScriptedAuthService implements AuthService {
  AuthUser? _user;
  final StreamController<AuthUser?> _changes = StreamController.broadcast();
  var _anonymousUsers = 0;

  /// What each call fails with from now on, or `null` while the calls
  /// succeed.
  AuthFailure? failure;

  /// What each call waits for before it answers, or `null` while the calls
  /// answer at once.
  Completer<void>? hold;

  /// The calls that reached the service, each by its name and its email
  /// address, if it has one.
  final List<String> calls = [];

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  /// Notes [call], and answers it as the test says: once [hold] completes,
  /// with [failure], or with the user that [user] returns signed in.
  Future<void> _answer(String call, AuthUser? Function() user) async {
    calls.add(call);
    await hold?.future;
    if (failure case final failure?) throw failure;
    _user = user();
    _changes.add(_user);
  }

  AuthUser _accountOf(String email, {String? uid}) => AuthUser(
        uid: uid ?? 'account-of-$email',
        isAnonymous: false,
        email: email,
      );

  @override
  Future<void> signIn({required String email, required String password}) =>
      _answer('signIn $email', () => _accountOf(email));

  @override
  Future<void> signUp({required String email, required String password}) =>
      _answer('signUp $email', () => _accountOf(email));

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) =>
      _answer('linkPassword $email', () => _accountOf(email, uid: _user!.uid));

  @override
  Future<void> signInAnonymously() => _answer(
        'signInAnonymously',
        () => AuthUser(
          uid: 'anonymous-${++_anonymousUsers}',
          isAnonymous: true,
        ),
      );

  @override
  Future<void> sendPasswordReset(String email) =>
      _answer('sendPasswordReset $email', () => _user);

  @override
  Future<void> signOut() => _answer('signOut', () => null);

  @override
  Future<void> deleteAccount() => _answer('deleteAccount', () => null);
}

/// Gives the session of the app [service], a service of the test with
/// nobody signed in, in place of the service of the module that provides
/// the sign-in, and shows the sign-in.
///
/// The session then has nobody, or in an app that signs an anonymous user
/// in, an anonymous user of the service. An app that asks for an account
/// shows the sign-in in place of its screens. An app that everyone may use
/// shows it over the page that the user sees, as the code of a screen does
/// that needs an account.
Future<void> showSignInWith(
  WidgetTester tester,
  ScriptedAuthService service,
) async {
  await appSession.start(service);
  await tester.pumpAndSettle();
  if (authMode != AuthMode.required) await pushSignIn(tester);
}
