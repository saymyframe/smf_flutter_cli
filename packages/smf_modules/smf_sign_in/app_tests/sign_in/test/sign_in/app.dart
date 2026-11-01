// What the tests of the sign-in module share, in the apps with the module:
// the start of the app with main() of lib/main.dart, which the app entry
// role puts into every app, the screens of the sign-in and what they show,
// in the language that the device asks for, the way to the sign-in through
// the navigation of the router role, the screen of the account with its
// entry on the settings screen, and a service of sign-in of the test, which
// a test gives the session of the app to script what a call does. The ways
// to sign in of the app are those of appSignInMethods of the auth role, each
// with the mocks of its module, which answer at once.
//
// They know the module, and of the rest of the app only its roles: the session
// of the auth role, whichever module provides the sign-in, in the mode that
// the app has as a constant, and the router, which shows the screens and
// leaves them. The matrix writes of_app.dart next to this file: the screen
// that the app starts on, the settings screen of the app with the entry of the
// module, from the settings screen role, whether that screen is a destination
// of the main navigation, from the layout role, and the texts of the module in
// each language of the app. It sets up the mocks of the platform side of every
// module of the app before the tests of each test file
// (flutter_test_config.dart), so the start-up runs whatever other modules the
// app has, and a guard of the routes of another module is open.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';
import 'package:{{app_name}}/core/auth/sign_in_methods.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/sign_in/account_screen.dart';
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

/// The screen of the sign-in itself, also below another screen.
final Finder builtSignInScreen = find.byType(
  SignInScreen,
  skipOffstage: false,
);

/// The screen of the account that the user sees, and every one that the
/// app has built, also below another screen.
final Finder accountScreen = find.byType(AccountScreen);
final Finder builtAccountScreen = find.byType(
  AccountScreen,
  skipOffstage: false,
);

/// The settings screen of the app that the user sees, and every one that
/// the app has built, also below another screen.
final Finder shownSettingsScreen = find.byType(settingsScreen);
final Finder builtSettingsScreen = find.byType(
  settingsScreen,
  skipOffstage: false,
);

/// The entry of the account on the settings screen.
final Finder accountRow = find.byType(accountEntry);

/// The action of the screen of the account that deletes the account.
final Finder deleteAction = find.byType(DestructiveAction);

/// The sheet that asks before the account is deleted, and what it shows of
/// [matching].
final Finder deleteSheet = find.byType(BottomSheet);
Finder inDeleteSheet(Finder matching) =>
    find.descendant(of: deleteSheet, matching: matching);

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
      AuthFailureReason.credentialInUse => 'failureCredentialInUse',
      AuthFailureReason.accountExistsWithOtherMethod => 'failureOtherMethod',
      AuthFailureReason.weakPassword => 'failureWeakPassword',
      AuthFailureReason.invalidEmail => 'emailInvalid',
      AuthFailureReason.userDisabled => 'failureDisabled',
      AuthFailureReason.tooManyAttempts => 'failureTooManyAttempts',
      AuthFailureReason.network => 'failureNoNetwork',
      AuthFailureReason.recentSignInRequired => 'failureRecentSignIn',
      AuthFailureReason.notConfigured => 'failureNotSetUp',
      AuthFailureReason.unknown => 'failureUnknown',
    };

/// The ways to sign in of the app that work on the platform that the app
/// runs on, as the screens of the sign-in show their buttons: those of
/// appSignInMethods of the auth role that are available, in their order.
List<SignInMethod> methodsHere() => [
      for (final method in appSignInMethods)
        if (method.isAvailable) method,
    ];

/// The button of [method], a way to sign in, on the screen that the user
/// sees.
Finder methodButton(SignInMethod method) => find.byWidgetPredicate(
      (widget) => widget is SignInMethodButton && widget.method == method,
      description: 'the button of the way to sign in of ${method.issuer}',
    );

/// The button itself in [button], a button of a way to sign in, which a
/// screen reader reads and which takes a tap or does not.
Finder buttonIn(Finder button) =>
    find.descendant(of: button, matching: find.byType(FilledButton));

/// Has the app run on [platform], as the platform that the app runs on, or
/// on the platform of the test again for `null`, and builds it again, so
/// that a screen of the sign-in shows the buttons of the ways to sign in
/// that work there. A test that calls it calls it with `null` before it
/// ends: flutter_test checks that the test put the platform back.
Future<void> usePlatform(WidgetTester tester, TargetPlatform? platform) async {
  debugDefaultTargetPlatformOverride = platform;
  // Every widget builds again, as after a hot reload: the theme of the app
  // and the screens read the platform when they build.
  tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
  await tester.pumpAndSettle();
}

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

/// Has the platform ask the app for [location], as a link to it does while
/// the app runs, and waits for the screen.
Future<void> followLink(WidgetTester tester, AppLocation location) async {
  await tester.binding.handlePushRoute(location.path);
  await tester.pumpAndSettle();
}

/// Presses the back button of the system and waits for the screen. Returns
/// whether the app handled the press: one that it does not handle closes
/// the app.
Future<bool> pressSystemBack(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return handled;
}

/// Asks for each of the three routes of the sign-in in turn, as the code of
/// a page does with go(), in place of the stack, and as the platform does
/// for a link, and waits for the screen after each.
Future<void> followLinksToSignIn(WidgetTester tester) async {
  for (final AppLocation location in const [
    SignInSignInLocation(),
    SignInSignUpLocation(),
    SignInResetPasswordLocation(),
  ]) {
    navigatorOf(tester).go(location);
    await tester.pumpAndSettle();
    await followLink(tester, location);
  }
}

/// Checks that the router of the app takes no location from the platform,
/// which the router role lets a router do, once it did not show the
/// sign-in for a link to it, [when]: asked by the platform for another
/// page of the app, whose route asks for nothing, it does not show that
/// page either. A router that takes such locations shows the sign-in for a
/// link to it, for a user without an account.
Future<void> expectRouterTakesNoLinks(WidgetTester tester, String when) async {
  for (final (:location, :screen) in otherPages) {
    await followLink(tester, location);
    expect(
      find.byType(screen),
      findsNothing,
      reason: '$when, a router that takes locations from the platform, as '
          'this one does for ${location.path}, shows the sign-in over the '
          'screen that the app starts on. Only a router that takes none '
          'leaves the user where they are.',
    );
  }
}

/// Opens the settings screen of the app for a user with an account, and
/// waits for it.
///
/// Where the screen is no destination of the main navigation, it opens over
/// the screen that the app starts on, as a screen of the app opens it. So a
/// page over it that closes more than itself leaves the user on the screen
/// that the app starts on, which a test sees. A destination cannot be
/// pushed, so there the screen takes the place of the stack.
Future<void> openSettings(WidgetTester tester) async {
  if (settingsInMainNavigation) {
    navigatorOf(tester).go(settingsLocation);
  } else {
    // The screen that the app starts on, alone: the router shows it to a
    // user with an account who asks for the sign-in, whose flow is over.
    navigatorOf(tester).go(const SignInSignInLocation());
    await tester.pumpAndSettle();
    unawaited(navigatorOf(tester).push<void>(settingsLocation));
  }
  await tester.pumpAndSettle();
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
      AccountSession(:final email?) => 'the account of $email',
      AccountSession(:final issuers) => 'the account of ${issuers.join(', ')}',
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

  /// Signs the user out without a call of the app, and tells of it: as when
  /// the session of the user ends on the server, or the account is deleted
  /// on another device.
  void endSession() {
    _user = null;
    _changes.add(null);
  }

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
  Future<void> deleteAccount({SignInCredential? fresh}) =>
      _answer('deleteAccount', () => null);

  @override
  Future<String?> userToken({bool forceRefresh = false}) async =>
      _user == null ? null : 'token-of-${_user!.uid}';

  /// The issuer of [credential], which names it in the calls.
  String _issuerOf(SignInCredential credential) => switch (credential) {
        IdTokenCredential(:final issuer) => issuer,
      };

  /// Signs in to the user of the identity of [credential], an account
  /// without an email address.
  @override
  Future<void> signInWith(SignInCredential credential) {
    final issuer = _issuerOf(credential);
    return _answer(
      'signInWith $issuer',
      () => AuthUser(
        uid: 'identity-of-$issuer',
        isAnonymous: false,
        issuers: {issuer},
      ),
    );
  }

  /// Gives the user who is signed in the identity of [credential].
  @override
  Future<void> linkWith(SignInCredential credential) {
    final issuer = _issuerOf(credential);
    return _answer(
      'linkWith $issuer',
      () => AuthUser(uid: _user!.uid, isAnonymous: false, issuers: {issuer}),
    );
  }
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
