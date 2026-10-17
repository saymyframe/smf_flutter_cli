@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// The file of the fake provider of sign-in in the test app.
const _fakeFile = ImportRef.app('fakes/fake_auth.dart');

/// The file of the session, as code imports it.
const _sessionImport = ImportRef.app('core/auth/app_session.dart');

/// The implementation of the service of the test app: one that is created
/// asynchronously, or one created with the app.
AuthImplementation _implementation({required bool async}) => async
    ? const AuthImplementation.async(
        type: TypeRef('FakeAuth', import: _fakeFile),
        init: FactoryRef('openFakeAuth', import: _fakeFile),
      )
    : const AuthImplementation(
        type: TypeRef('FakeAuth', import: _fakeFile),
        create: FactoryRef('createFakeAuth', import: _fakeFile),
      );

/// The file of the test app with the function of its ways to sign in.
const _methodFile = ImportRef.app('fakes/fake_method.dart');

/// The path of [_methodFile].
const _methodPath = 'lib/fakes/fake_method.dart';

/// The issuer of the way to sign in of the tests.
const _issuer = 'https://id.example.com';

/// A way to sign in of the test app with the identity provider [issuer],
/// on [platforms], whose label is the text [label] and which asks for a
/// credential again before a deletion if it [revokes].
SignInMethod _method({
  String issuer = _issuer,
  Set<AppPlatform> platforms = const {AppPlatform.android, AppPlatform.ios},
  AppStoreLogin appStore = AppStoreLogin.privacyFocused,
  bool revokes = false,
  LocalizedText label =
      const LocalizedText('label', en: 'Continue with Example'),
}) =>
    SignInMethod(
      label: label,
      icon: const Fragment('FakeIcon()', imports: [_methodFile]),
      platforms: platforms,
      credential: const FunctionRef('fakeCredential', import: _methodFile),
      issuer: issuer,
      appStore: appStore,
      revokesOnDeletion: revokes,
    );

/// The files of the role in an app of [mode], rendered with an
/// implementation that is created asynchronously, or with the app, and
/// with [methods], the ways to sign in of the module `example_sign_in`,
/// and what the template puts into other sockets.
Future<RenderedTemplate> _rendered({
  AuthMode mode = AuthMode.required,
  bool async = false,
  List<SignInMethod> methods = const [],
}) =>
    renderTemplate(
      authRole,
      data: [
        dataOf(authRole, _implementation(async: async), module: 'fake_auth'),
        for (final method in methods)
          dataOf(authRole, method, module: 'example_sign_in'),
      ],
      choice: mode,
    );

/// A stand-in for the part of Flutter's foundation library that the files
/// of the role use, with the signatures of Flutter 3.44: the app runs in
/// debug mode, what it prints goes to `debugPrinted`, and the errors that
/// it reports go to `reportedErrors`.
const _foundation = r'''
const bool kDebugMode = true;

/// What the app printed with [debugPrint], in order.
final List<String> debugPrinted = [];

void debugPrint(String? message, {int? wrapWidth}) =>
    debugPrinted.add('$message');

class Immutable {
  const Immutable();
}

const Immutable immutable = Immutable();

typedef VoidCallback = void Function();

abstract class Listenable {
  const Listenable();

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
}

abstract class ValueListenable<T> extends Listenable {
  const ValueListenable();

  T get value;
}

mixin class ChangeNotifier implements Listenable {
  final List<VoidCallback> _listeners = [];
  bool _disposed = false;

  void _notDisposed() {
    if (_disposed) throw StateError('A $runtimeType was used after dispose.');
  }

  @override
  void addListener(VoidCallback listener) {
    _notDisposed();
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void notifyListeners() {
    _notDisposed();
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  void dispose() {
    _notDisposed();
    _disposed = true;
    _listeners.clear();
  }
}

class ErrorDescription {
  ErrorDescription(this.message);

  final String message;
}

class FlutterErrorDetails {
  const FlutterErrorDetails({
    required this.exception,
    this.stack,
    this.library = 'Flutter framework',
    this.context,
  });

  final Object exception;
  final StackTrace? stack;
  final String? library;
  final ErrorDescription? context;
}

/// The errors that the app reported with [FlutterError.reportError].
final List<FlutterErrorDetails> reportedErrors = [];

class FlutterError {
  static void reportError(FlutterErrorDetails details) =>
      reportedErrors.add(details);
}

enum TargetPlatform { android, fuchsia, iOS, linux, macOS, windows }

/// The platform that the app runs on in place of the one of the device, as
/// a test of Flutter sets it.
TargetPlatform? debugDefaultTargetPlatformOverride;

/// The platform that the app runs on: Android, unless a script says
/// otherwise.
TargetPlatform get defaultTargetPlatform =>
    debugDefaultTargetPlatformOverride ?? TargetPlatform.android;
''';

/// A stand-in for the part of Flutter's widgets library that the files of
/// the role use: what that library exports of the foundation library, and
/// the binding with the observers of the lifecycle of the app.
/// `lifecycle()` puts the app into a state, and `resumeApp()` stands for
/// the user who comes back to the app.
const _widgets = '''
export 'foundation.dart'
    show
        ChangeNotifier,
        ErrorDescription,
        FlutterError,
        FlutterErrorDetails,
        VoidCallback,
        debugPrint,
        immutable;

enum AppLifecycleState { detached, resumed, inactive, hidden, paused }

abstract class Widget {
  const Widget();
}

/// The context of a widget, which is in a language, as one below the root
/// of an app is.
final class BuildContext {
  const BuildContext(this.language);

  /// The code of the language of the app at the context.
  final String language;
}

abstract mixin class WidgetsBindingObserver {
  void didChangeAppLifecycleState(AppLifecycleState state) {}
}

class WidgetsBinding {
  static final WidgetsBinding instance = WidgetsBinding();

  /// The observers that were added and not removed.
  final List<WidgetsBindingObserver> observers = [];

  void addObserver(WidgetsBindingObserver observer) => observers.add(observer);

  bool removeObserver(WidgetsBindingObserver observer) =>
      observers.remove(observer);
}

/// The app comes into [state], which every observer is told of.
void lifecycle(AppLifecycleState state) {
  for (final observer in [...WidgetsBinding.instance.observers]) {
    observer.didChangeAppLifecycleState(state);
  }
}

/// The user comes back to the app, which was shown but not in use.
void resumeApp() {
  lifecycle(AppLifecycleState.inactive);
  lifecycle(AppLifecycleState.resumed);
}
''';

/// A provider of sign-in for the test app, which keeps to the contract of
/// `AuthService` unless a test says otherwise.
///
/// The accounts are on a map that stands for the server, and the user who
/// is signed in on a variable that stands for the device: each new service
/// reads it, as a service does at the next launch of an app. The services
/// note their calls. A test holds a call until it lets it go, makes a call
/// fail, and changes the user as something outside the app does.
const _fakeAuth = r'''
import 'dart:async';

import '../core/auth/auth_service.dart';

/// The accounts on the server, by their email addresses.
final Map<String, ({String uid, String password})> accounts = {};

/// The identities of the identity providers on the server: the id of the
/// user of each, by its issuer and its token.
final Map<String, String> identities = {};

/// The credentials that reached the services, in order.
final List<SignInCredential> credentials = [];

/// The user who is signed in on the device.
AuthUser? onDevice;

/// The calls that reached the services, in order.
final List<String> calls = [];

/// The [calls] since it last asked.
List<String> takeCalls() {
  final taken = [...calls];
  calls.clear();
  return taken;
}

/// The calls that wait until their completer completes, by their names.
final Map<String, Completer<void>> holds = {};

/// What the calls throw, by their names.
final Map<String, Object> failures = {};

/// Whether a call that fails signs the user out first, without an event,
/// as a call for a user whose session has ended on the server does.
bool failuresSignOut = false;

/// Whether a service tells of the changes that its calls make.
bool tells = true;

/// How many services were created.
int created = 0;

int _users = 0;

AuthService createFakeAuth() => FakeAuth();

Future<AuthService> openFakeAuth() async {
  await Future<void>.delayed(Duration.zero);
  return FakeAuth();
}

final class FakeAuth implements AuthService {
  FakeAuth() : _user = onDevice {
    created++;
  }

  final StreamController<AuthUser?> _changes = StreamController.broadcast();

  AuthUser? _user;

  /// Whether something listens to the changes of the user.
  bool get hasListener => _changes.hasListener;

  /// Changes the user as something outside the app does, and tells of it.
  void change(AuthUser? user) {
    _user = user;
    onDevice = user;
    _changes.add(user);
  }

  /// Sends an error to those who follow the changes of the user.
  void fail(Object error) => _changes.addError(error, StackTrace.current);

  void _set(AuthUser? user) {
    _user = user;
    onDevice = user;
    if (tells) _changes.add(user);
  }

  Future<void> _enter(String name, [String argument = '']) async {
    calls.add(argument.isEmpty ? name : '$name $argument');
    await holds[name]?.future;
    final failure = failures[name];
    if (failure == null) return;
    if (failuresSignOut) {
      _user = null;
      onDevice = null;
    }
    throw failure;
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _enter('signIn', email);
    final account = accounts[email];
    if (account == null || account.password != password) {
      throw const AuthFailure(AuthFailureReason.invalidCredentials);
    }
    _set(AuthUser(uid: account.uid, isAnonymous: false, email: email));
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _enter('signUp', email);
    if (accounts.containsKey(email)) {
      throw const AuthFailure(AuthFailureReason.emailInUse);
    }
    final uid = 'user-${++_users}';
    accounts[email] = (uid: uid, password: password);
    _set(AuthUser(uid: uid, isAnonymous: false, email: email));
  }

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) async {
    await _enter('linkPassword', email);
    final uid = _user!.uid;
    accounts[email] = (uid: uid, password: password);
    _set(AuthUser(uid: uid, isAnonymous: false, email: email));
  }

  @override
  Future<void> signInWith(SignInCredential credential) async {
    credentials.add(credential);
    await _enter('signInWith', '$credential');
    final (:key, :issuer) = _identityOf(credential);
    final uid = identities[key] ??= 'user-${++_users}';
    _set(AuthUser(uid: uid, isAnonymous: false, issuers: {issuer}));
  }

  @override
  Future<void> linkWith(SignInCredential credential) async {
    credentials.add(credential);
    await _enter('linkWith', '$credential');
    final (:key, :issuer) = _identityOf(credential);
    if (identities.containsKey(key)) {
      throw const AuthFailure(AuthFailureReason.credentialInUse);
    }
    final user = _user!;
    identities[key] = user.uid;
    _set(
      AuthUser(
        uid: user.uid,
        isAnonymous: false,
        email: user.email,
        issuers: {...user.issuers, issuer},
      ),
    );
  }

  /// The identity of [credential], by its issuer and its token, and its
  /// issuer.
  ({String key, String issuer}) _identityOf(SignInCredential credential) =>
      switch (credential) {
        IdTokenCredential(:final issuer, :final idToken) => (
            key: '$issuer $idToken',
            issuer: issuer,
          ),
      };

  @override
  Future<void> signInAnonymously() async {
    await _enter('signInAnonymously');
    _set(AuthUser(uid: 'user-${++_users}', isAnonymous: true));
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _enter('sendPasswordReset', email);

  @override
  Future<void> signOut() async {
    await _enter('signOut');
    _set(null);
  }

  @override
  Future<void> deleteAccount({SignInCredential? fresh}) async {
    if (fresh != null) credentials.add(fresh);
    await _enter('deleteAccount', fresh == null ? '' : 'fresh $fresh');
    final uid = _user!.uid;
    accounts.removeWhere((email, account) => account.uid == uid);
    identities.removeWhere((key, owner) => owner == uid);
    _set(null);
  }
}
''';

/// The file of the test app with the function of a way to sign in, which
/// notes each call in `calls` of the fake provider, and returns, throws or
/// holds what a script says, and the icon of that way to sign in.
const _fakeMethod = '''
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/auth/app_session.dart';
import 'fake_auth.dart';

/// What [fakeCredential] answers next: a credential, `null` for a sheet
/// that the user closed, or what it throws.
Object? answer;

/// Holds [fakeCredential] until it completes.
Completer<void>? holdCredential;

Future<SignInCredential?> fakeCredential() async {
  calls.add('credential');
  await holdCredential?.future;
  return switch (answer) {
    final SignInCredential credential => credential,
    null => null,
    final error => throw error,
  };
}

final class FakeIcon extends Widget {
  const FakeIcon();
}
''';

/// What the scripts for the test app share. `show` tells a session, and
/// `failureOf` the failure that a call completes with: its reason, its
/// hint, and the file in which its stack trace starts, which is where the
/// error was thrown. `pump` lets what is on its way happen.
///
/// It takes `AuthFailure` and its reasons from the file of the session,
/// which exports them.
const _notes = r'''
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:my_app/core/auth/app_session.dart';
import 'package:my_app/core/auth/auth_service.dart' show AuthService, AuthUser;
import 'package:my_app/core/auth/guest_data.dart';
import 'package:my_app/fakes/fake_auth.dart';
import 'package:my_app/fakes/fake_method.dart';

final result = <String, Object?>{};

String show(AppSession session) => switch (session) {
      SignedOutSession() => 'signed out',
      AnonymousSession(:final uid) => 'anonymous $uid',
      AccountSession(:final uid, :final email) => 'account $uid $email',
    };

Future<void> pump() => Future<void>.delayed(Duration.zero);

Future<String> failureOf(Future<void> Function() call) async {
  try {
    await call();
    return 'none';
  } on AuthFailure catch (failure, stackTrace) {
    final file = RegExp(r'\w+\.dart').firstMatch('$stackTrace')?[0];
    return '${failure.reason.name}, hint ${failure.developerHint}, '
        'thrown in $file';
  } on Object catch (error) {
    return 'no AuthFailure: $error';
  }
}

/// The errors that the app reported, each as what a test compares.
List<Map<String, Object?>> reported() => [
      for (final details in reportedErrors)
        {
          'exception': '${details.exception}',
          'has a stack trace': details.stack != null,
          'library': details.library,
          'context': details.context?.message,
        },
    ];

/// A timer of [timed], which runs when a script fires it.
final class HeldTimer implements Timer {
  HeldTimer(this.duration, this._callback);

  /// How long the code asked the timer to wait.
  final Duration duration;

  final void Function() _callback;

  void fire() {
    cancel();
    _callback();
  }

  @override
  void cancel() => timers.remove(this);

  @override
  bool get isActive => timers.contains(this);

  @override
  int get tick => 0;
}

/// The timers of [timed] that neither ran nor were cancelled.
final List<HeldTimer> timers = [];

/// Runs [body] in a zone whose timers wait until a script fires them, so
/// that a script sees how long the code waits without waiting itself.
void timed(void Function() body) => runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          final timer = HeldTimer(duration, callback);
          timers.add(timer);
          return timer;
        },
      ),
    );

const email = 'ann@example.com';
const password = 'secret';

/// A credential of the identity provider of the tests.
const credential = IdTokenCredential(
  issuer: 'https://id.example.com',
  idToken: 'token-of-ann',
);
''';

/// Goes through the life of the session of the app, with the session and
/// the functions that the role generates: a first launch, sign-up,
/// sign-out, sign-in, the next launch, a password reset and the deletion
/// of the account. After each step it notes the session with its two
/// flags, the calls that reached the provider, and what the listeners of
/// the session and of each flag found when they were called.
const _life = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  final heard = <String>[];
  String state() => '${show(appSession.value)}; '
      'allows ${appSession.allowsApp.value}, '
      'account ${appSession.hasAccount.value}';
  appSession.addListener(() => heard.add('session: ${state()}'));
  appSession.allowsApp.addListener(() => heard.add('allowsApp: ${state()}'));
  appSession.hasAccount.addListener(() => heard.add('hasAccount: ${state()}'));
  void note(String step) {
    result[step] = {
      'state': state(),
      'calls': takeCalls(),
      'heard': [...heard],
    };
    heard.clear();
  }

  result['the mode'] = '${authMode.name}, ${appSession.mode.name}';
  result['the wait for an anonymous user'] = '${appSession.anonymousWait}';
  try {
    createAuthService();
    result['the service before the start'] = 'a service';
  } on Error {
    result['the service before the start'] = 'none';
  }
  note('before the start');

  await initAuth();
  final first = createAuthService();
  note('a first launch');

  await appSession.signUp(email: email, password: password);
  note('sign-up');

  await appSession.signOut();
  note('sign-out');

  await appSession.signIn(email: email, password: password);
  note('sign-in');

  await initAuth();
  note('the next launch');
  result['the services'] = {
    'created': created,
    'the app has the one of the last start':
        !identical(createAuthService(), first) &&
            identical(createAuthService(), createAuthService()),
    'the first one is listened to': (first as FakeAuth).hasListener,
  };

  await appSession.sendPasswordReset(email);
  note('a password reset');

  await appSession.deleteAccount();
  note('the deletion of the account');
  result['the accounts'] = [...accounts.keys];
  port.send(result);
}
''';

/// What the listeners of the session and of its two flags find at a change
/// to [state]: each is called once, and each finds the session and both
/// flags as they are after the change.
List<String> _heard(String state) => [
      'session: $state',
      'allowsApp: $state',
      'hasAccount: $state',
    ];

/// What [_life] sends back from the app of [mode].
Map<String, Object?> _lifeIn(AuthMode mode) {
  // Whether a user without an account may see the app.
  final open = mode != AuthMode.required;
  final anonymous = mode == AuthMode.anonymous;
  String state(String session, {bool account = false}) =>
      '$session; allows ${open || account}, account $account';
  final signedOut = state('signed out');
  final account = state('account user-1 ann@example.com', account: true);
  // What a user who signed out or was deleted leaves behind: nobody, or in
  // the anonymous mode a new anonymous user, after the app had nobody.
  Map<String, Object?> left(String call, String user) => {
        'state': anonymous ? state('anonymous $user') : signedOut,
        'calls': [call, if (anonymous) 'signInAnonymously'],
        'heard': [
          ..._heard(signedOut),
          if (anonymous) ..._heard(state('anonymous $user')),
        ],
      };
  return {
    'the mode': '${mode.name}, ${mode.name}',
    'the wait for an anonymous user': '0:00:03.000000',
    'the service before the start': 'none',
    'before the start': {
      'state': signedOut,
      'calls': <Object?>[],
      'heard': <Object?>[],
    },
    // Nobody is signed in on a new device. Only the anonymous mode signs a
    // user in on its own.
    'a first launch': anonymous
        ? {
            'state': state('anonymous user-1'),
            'calls': ['signInAnonymously'],
            'heard': _heard(state('anonymous user-1')),
          }
        : {
            'state': signedOut,
            'calls': <Object?>[],
            'heard': <Object?>[],
          },
    // An anonymous user gets the account and keeps the id.
    'sign-up': {
      'state': account,
      'calls': [if (anonymous) 'linkPassword $_email' else 'signUp $_email'],
      'heard': _heard(account),
    },
    'sign-out': left('signOut', 'user-2'),
    'sign-in': {
      'state': account,
      'calls': ['signIn $_email'],
      'heard': _heard(account),
    },
    // The user is known when initAuth() completes, without a call, and the
    // listeners hear nothing, since nothing changed.
    'the next launch': {
      'state': account,
      'calls': <Object?>[],
      'heard': <Object?>[],
    },
    'the services': {
      'created': 2,
      'the app has the one of the last start': true,
      'the first one is listened to': false,
    },
    'a password reset': {
      'state': account,
      'calls': ['sendPasswordReset $_email'],
      'heard': <Object?>[],
    },
    'the deletion of the account': left('deleteAccount', 'user-3'),
    'the accounts': <Object?>[],
  };
}

/// The email address of the account of the scripts.
const _email = 'ann@example.com';

/// Makes the provider fail, and notes what each call of the session
/// completes with and what the session is after it.
const _failures = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  final heard = <String>[];
  appSession.addListener(() => heard.add(show(appSession.value)));
  Future<void> signIn() => appSession.signIn(email: email, password: password);
  final callsOfSession = <String, Future<void> Function()>{
    'signIn': signIn,
    'signUp': () => appSession.signUp(email: 'bob@example.com', password: 'x'),
    'signInWith': () => appSession.signInWith(credential),
    'sendPasswordReset': () => appSession.sendPasswordReset(email),
    'signOut': appSession.signOut,
    'deleteAccount': appSession.deleteAccount,
  };

  await initAuth();
  await appSession.signUp(email: email, password: password);
  heard.clear();

  // A failure of the provider, for each reason.
  final passed = <String, String>{};
  for (final reason in AuthFailureReason.values) {
    failures['signIn'] = AuthFailure(
      reason,
      developerHint:
          reason == AuthFailureReason.notConfigured ? 'Enable it.' : null,
    );
    passed[reason.name] = await failureOf(signIn);
  }
  failures.clear();
  result['a failure of the provider'] = passed;

  // An error that is no failure, from each call.
  final errors = <String, String>{};
  for (final MapEntry(key: name, value: call) in callsOfSession.entries) {
    failures[name] = StateError('The plugin broke in $name.');
    errors[name] = await failureOf(call);
  }
  failures.clear();
  failures['signIn'] = 'A text that was thrown.';
  errors['an object that is no error'] = await failureOf(signIn);
  failures.clear();
  result['an error of another kind'] = errors;
  result['the session after the failures'] = {
    'state': show(appSession.value),
    'heard': [...heard],
  };

  // The provider signs the user out, tells of nothing, and fails.
  tells = false;
  failuresSignOut = true;
  failures['deleteAccount'] = const AuthFailure(
    AuthFailureReason.recentSignInRequired,
  );
  result['a call for a user whose session has ended'] = {
    'failure': await failureOf(appSession.deleteAccount),
    'state': show(appSession.value),
    'heard': [...heard],
  };
  const notSetUp = AuthFailure(
    AuthFailureReason.notConfigured,
    developerHint: 'Enable it.',
  );
  result['a failure as text'] = [
    '${const AuthFailure(AuthFailureReason.network)}',
    '$notSetUp',
  ];
  port.send(result);
}
''';

/// Changes the user as something outside the app does, starts the session
/// again with another service, sends an error where a change is told of,
/// and removes listeners of the two flags.
const _changes = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final heard = <String>[];
  appSession.addListener(() => heard.add(show(appSession.value)));
  void note(String step) {
    result[step] = {'state': show(appSession.value), 'heard': [...heard]};
    heard.clear();
  }

  const remote = AuthUser(
    uid: 'remote',
    isAnonymous: false,
    email: 'remote@example.com',
  );
  await initAuth();
  final first = createAuthService() as FakeAuth;

  first.change(remote);
  await pump();
  note('a change that no call made');

  first.change(remote);
  await pump();
  note('an event for the same user');

  first.change(null);
  await pump();
  note('a sign-out that no call made');

  onDevice = const AuthUser(uid: 'other', isAnonymous: true);
  final second = FakeAuth();
  await appSession.start(second);
  note('a start with another service');

  first.change(remote);
  await pump();
  note('a change of the service before');
  result['the service before is listened to'] = first.hasListener;

  second.change(remote);
  await pump();
  note('a change of the service of the start');

  second.fail(StateError('The stream broke.'));
  await pump();
  note('an error where a change is told of');
  result['reported'] = reported();
  second.change(null);
  await pump();
  note('a change after the error');

  var flags = 0;
  void onFlag() => flags++;
  appSession.allowsApp.addListener(onFlag);
  appSession.hasAccount.addListener(onFlag);
  second.change(remote);
  await pump();
  final heardByFlags = flags;
  appSession.allowsApp.removeListener(onFlag);
  appSession.hasAccount.removeListener(onFlag);
  second.change(null);
  await pump();
  result['the listeners of the flags'] = {
    'told of a change': heardByFlags,
    'told once they are removed': flags - heardByFlags,
  };

  result['sessions compare by value'] = {
    'signed out': SignedOutSession() == const SignedOutSession(),
    'the same anonymous user': AnonymousSession('a') == AnonymousSession('a'),
    'another anonymous user': AnonymousSession('a') == AnonymousSession('b'),
    'the same account':
        AccountSession('a', email: email) == AccountSession('a', email: email),
    'another address of the account':
        AccountSession('a', email: email) == AccountSession('a'),
    'an account and an anonymous user of one id':
        AccountSession('a') == AnonymousSession('a'),
    'the same issuers of the account, in another order':
        AccountSession('a', issuers: {'x', 'y'}) ==
            AccountSession('a', issuers: {'y', 'x'}),
    'other issuers of the account':
        AccountSession('a', issuers: {'x'}) ==
            AccountSession('a', issuers: {'x', 'y'}),
    'an issuer of the account more':
        AccountSession('a', issuers: {'x', 'y'}) ==
            AccountSession('a', issuers: {'x'}),
    'as keys': {
      SignedOutSession(),
      SignedOutSession(),
      AnonymousSession('a'),
      AnonymousSession('a'),
      AccountSession('a', email: email),
      AccountSession('a', email: email),
      AccountSession('a', issuers: {'x', 'y'}),
      AccountSession('a', issuers: {'y', 'x'}),
    }.length,
  };
  port.send(result);
}
''';

/// Makes calls before the first start of a session, in each mode, and
/// three after it, each while the one before it is on its way.
const _earlyCalls = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  for (final mode in AuthMode.values) {
    onDevice = null;
    accounts.clear();
    final session = AppSessionController(
      mode: mode,
      takeGuestData: takeGuestData,
    );
    final done = <String>[];
    unawaited(
      session
          .signUp(email: email, password: password)
          .then((_) => done.add('sign-up')),
    );
    // The second call fails, which neither the start nor the third call
    // takes for its own failure.
    unawaited(
      failureOf(() => session.signIn(email: email, password: 'wrong'))
          .then((failure) => done.add('sign-in: $failure')),
    );
    unawaited(
      session.sendPasswordReset(email).then((_) => done.add('reset')),
    );
    await pump();
    final before = {'calls': takeCalls(), 'state': show(session.value)};

    // The start holds the first call, so the others wait behind it.
    final hold = Completer<void>();
    holds[mode == AuthMode.anonymous ? 'linkPassword' : 'signUp'] = hold;
    var started = false;
    final start = session.start(FakeAuth()).then((_) => started = true);
    await pump();
    final during = {
      'calls': takeCalls(),
      'the calls that are done': [...done],
      'the start is done': started,
    };
    holds.clear();
    hold.complete();
    await start;
    await pump();
    final after = {
      'calls': takeCalls(),
      'the calls that are done': [...done],
      'state': show(session.value),
    };

    // After the first start, a call still waits for the one before it,
    // and a third one for the second, once the first is over too.
    final holdOfSignOut = holds['signOut'] = Completer<void>();
    final holdOfReset = holds['sendPasswordReset'] = Completer<void>();
    unawaited(session.signOut());
    unawaited(session.sendPasswordReset(email));
    await pump();
    final first = takeCalls();
    holdOfSignOut.complete();
    await pump();
    final second = takeCalls();
    holds.clear();
    final third = session.sendPasswordReset('later@example.com');
    await pump();
    final whileTheSecondRuns = takeCalls();
    holdOfReset.complete();
    await third;
    result[mode.name] = {
      'before the start': before,
      'while the first call is on its way': during,
      'after the start': after,
      'a call after the start': first,
      'the call after it': second,
      'a third call while the second is on its way': whileTheSecondRuns,
      'the third call': takeCalls(),
    };
    session.dispose();
  }
  port.send(result);
}
''';

/// Starts a session, and then makes a call and starts the session again in
/// a zone whose microtasks run only when the script says so, as those of a
/// test of Flutter in fake time do, which starts the app in real time
/// before.
const _otherZone = '''
Future<void> main(List<String> arguments, SendPort port) async {
  final microtasks = <void Function()>[];
  final zone = Zone.current.fork(
    specification: ZoneSpecification(
      scheduleMicrotask: (self, parent, zone, microtask) =>
          microtasks.add(microtask),
    ),
  );
  void flush() {
    while (microtasks.isNotEmpty) {
      microtasks.removeAt(0)();
    }
  }

  final session = AppSessionController(
    mode: AuthMode.guest,
    takeGuestData: takeGuestData,
  );
  await session.start(FakeAuth());
  await session.signUp(email: email, password: password);
  takeCalls();

  var signedOut = false;
  zone.run(() => unawaited(session.signOut().then((_) => signedOut = true)));
  flush();
  result['a call'] = {
    'calls': takeCalls(),
    'the call is done': signedOut,
    'state': show(session.value),
  };

  var started = false;
  zone.run(
    () => unawaited(session.start(FakeAuth()).then((_) => started = true)),
  );
  flush();
  result['a start is done'] = started;
  session.dispose();
  port.send(result);
}
''';

/// Starts sessions in the anonymous mode whose anonymous sign-in takes
/// long, comes in time or fails, brings the user back to the app, and
/// signs out; and sessions in the other modes, which sign nobody in.
const _anonymous = r'''
AppSessionController anonymousSession({required Duration wait}) =>
    AppSessionController(
      mode: AuthMode.anonymous,
      takeGuestData: takeGuestData,
      anonymousWait: wait,
    );

Map<String, Object?> note(AppSessionController session) => {
      'state': show(session.value),
      'calls': takeCalls(),
      'printed': [...debugPrinted],
    };

Future<void> main(List<String> arguments, SendPort port) async {
  // A sign-in that takes longer than the wait.
  var session = anonymousSession(wait: const Duration(milliseconds: 20));
  var service = FakeAuth();
  var hold = holds['signInAnonymously'] = Completer<void>();
  var started = false;
  Future<void> start = session.start(service).then((_) => started = true);
  await pump();
  result['while the app waits for its anonymous user'] = {
    'the start is done': started,
    'calls': [...calls],
  };
  await start;
  result['a sign-in that takes longer than the wait'] = note(session);
  resumeApp();
  await pump();
  result['the user comes back while it is on its way'] = note(session);
  // It comes, and the provider tells of nothing.
  tells = false;
  hold.complete();
  await pump();
  tells = true;
  holds.clear();
  result['when it comes'] = note(session);
  resumeApp();
  await pump();
  result['the user comes back to an app with a user'] = note(session);
  session.dispose();
  result['after dispose'] = {
    'observers of the lifecycle': WidgetsBinding.instance.observers.length,
    'the service is listened to': service.hasListener,
  };

  // A sign-in that comes within the wait.
  onDevice = null;
  session = anonymousSession(wait: const Duration(hours: 1));
  hold = holds['signInAnonymously'] = Completer<void>();
  start = session.start(FakeAuth());
  await pump();
  hold.complete();
  await start;
  holds.clear();
  result['a sign-in that comes within the wait'] = note(session);
  session.dispose();

  // A sign-in that fails, and the tries after it.
  onDevice = null;
  session = anonymousSession(wait: const Duration(hours: 1));
  failures['signInAnonymously'] = const AuthFailure(
    AuthFailureReason.notConfigured,
    developerHint: 'Enable anonymous sign-in.',
  );
  await session.start(FakeAuth());
  result['a sign-in that fails'] = note(session);
  debugPrinted.clear();
  resumeApp();
  await pump();
  result['the user comes back, and it fails again'] = note(session);
  debugPrinted.clear();
  failures.clear();
  resumeApp();
  await pump();
  result['the user comes back, and it works'] = note(session);

  // Sign-out and the deletion of an account, while the anonymous sign-in
  // fails and while it works.
  await session.signUp(email: email, password: password);
  takeCalls();
  failures['signInAnonymously'] = StateError('No network.');
  await session.signOut();
  result['a sign-out, after which it fails'] = note(session);
  debugPrinted.clear();
  failures.clear();
  await session.signIn(email: email, password: password);
  takeCalls();
  await session.deleteAccount();
  result['the deletion of the account'] = note(session);
  await session.deleteAccount();
  result['the deletion of an anonymous user'] = note(session);
  session.dispose();

  // Starts with one service, with another, and with each of them again,
  // while their sign-ins are on their way: each service signs in once, and
  // when the sign-in of the first comes, that of the second is still the
  // one on its way.
  onDevice = null;
  session = anonymousSession(wait: const Duration(milliseconds: 20));
  final holdOfFirst = holds['signInAnonymously'] = Completer<void>();
  final first = FakeAuth();
  await session.start(first);
  final holdOfSecond = holds['signInAnonymously'] = Completer<void>();
  final second = FakeAuth();
  await session.start(second);
  await session.start(second);
  await session.start(first);
  await session.start(second);
  final signInsOfStarts = takeCalls();
  holdOfFirst.complete();
  await pump();
  resumeApp();
  await pump();
  final afterTheFirst = takeCalls();
  holdOfSecond.complete();
  await pump();
  holds.clear();
  result['starts while an anonymous sign-in is on its way'] = {
    'the sign-ins of the starts': signInsOfStarts,
    'calls once the first has come': afterTheFirst,
    'the user': show(session.value),
  };
  session.dispose();

  // A call that is made while the anonymous sign-in is on its way waits
  // for it, and finds the anonymous user.
  onDevice = null;
  accounts.clear();
  session = anonymousSession(wait: const Duration(milliseconds: 20));
  hold = holds['signInAnonymously'] = Completer<void>();
  await session.start(FakeAuth());
  takeCalls();
  var signedUp = false;
  final signUp = session
      .signUp(email: email, password: password)
      .then((_) => signedUp = true);
  await pump();
  result['a call while the anonymous sign-in is on its way'] = {
    'calls': takeCalls(),
    'the call is done': signedUp,
  };
  holds.clear();
  hold.complete();
  await signUp;
  result['the call, once the sign-in is over'] = note(session);
  session.dispose();

  // The user comes back while a call is on its way: the try waits for the
  // call, and is made only if the app has no user then.
  for (final wrong in [false, true]) {
    onDevice = null;
    session = anonymousSession(wait: const Duration(hours: 1));
    failures['signInAnonymously'] = StateError('No network.');
    await session.start(FakeAuth());
    failures.clear();
    debugPrinted.clear();
    takeCalls();
    hold = holds['signIn'] = Completer<void>();
    final signIn = failureOf(
      () => session.signIn(email: email, password: wrong ? 'wrong' : password),
    );
    await pump();
    resumeApp();
    await pump();
    final during = takeCalls();
    holds.clear();
    hold.complete();
    final failure = await signIn;
    await pump();
    result['the user comes back while a sign-in ${wrong ? 'fails' : 'works'}'] =
        {'calls while it is on its way': during, 'it': failure, ...note(session)};
    session.dispose();
  }

  // The other modes sign nobody in, and do not follow the lifecycle.
  for (final mode in [AuthMode.required, AuthMode.guest]) {
    onDevice = null;
    session = AppSessionController(mode: mode, takeGuestData: takeGuestData);
    await session.start(FakeAuth());
    final observers = WidgetsBinding.instance.observers.length;
    await session.signOut();
    resumeApp();
    await pump();
    result['in the mode ${mode.name}'] = {
      ...note(session),
      'observers of the lifecycle': observers,
    };
    session.dispose();
  }

  // The first start waits as long as the session was told, also when the
  // user comes back to the app meanwhile.
  onDevice = null;
  session = anonymousSession(wait: const Duration(minutes: 7));
  hold = holds['signInAnonymously'] = Completer<void>();
  started = false;
  timed(
    () => unawaited(session.start(FakeAuth()).then((_) => started = true)),
  );
  await pump();
  resumeApp();
  await pump();
  final waits = [for (final timer in timers) '${timer.duration}'];
  final startedEarly = started;
  timers.single.fire();
  await pump();
  result['the user comes back while the first start waits'] = {
    'the waits': waits,
    'the start is done before the wait is over': startedEarly,
    'the start is done once it is over': started,
    ...note(session),
  };
  holds.clear();
  hold.complete();
  await pump();
  result['once the sign-in of that start has come'] = note(session);
  session.dispose();

  // A call that fails and leaves nobody signed in, as one for a user whose
  // session has ended: the app signs in anonymously again, and the failure
  // does not wait for that.
  onDevice = null;
  session = anonymousSession(wait: const Duration(hours: 1));
  await session.start(FakeAuth());
  takeCalls();
  hold = holds['signInAnonymously'] = Completer<void>();
  failuresSignOut = true;
  failures['linkPassword'] = const AuthFailure(
    AuthFailureReason.recentSignInRequired,
  );
  final ended = await failureOf(
    () => session.signUp(email: 'carol@example.com', password: password),
  );
  failuresSignOut = false;
  failures.clear();
  result['a call that fails and leaves nobody signed in'] = {
    'it': ended,
    ...note(session),
  };
  holds.clear();
  hold.complete();
  await session.signUp(email: 'carol@example.com', password: password);
  result['the same call again'] = note(session);
  session.dispose();

  // A start while a call is on its way waits for the call, so its
  // anonymous sign-in does not run next to it.
  onDevice = null;
  session = anonymousSession(wait: const Duration(hours: 1));
  failures['signInAnonymously'] = StateError('No network.');
  final same = FakeAuth();
  await session.start(same);
  failures.clear();
  debugPrinted.clear();
  takeCalls();
  hold = holds['signIn'] = Completer<void>();
  final signIn = session.signIn(email: email, password: password);
  await pump();
  var restarted = false;
  unawaited(session.start(same).then((_) => restarted = true));
  await pump();
  final whileSigningIn = {
    'calls': takeCalls(),
    'the start is done': restarted,
  };
  holds.clear();
  hold.complete();
  await signIn;
  await pump();
  result['a start while a sign-in is on its way'] = {
    'while it is on its way': whileSigningIn,
    'the start is done': restarted,
    ...note(session),
  };
  session.dispose();

  // The user comes back from the background: the session looks at nothing
  // but that the app is resumed, whatever state it was in.
  onDevice = null;
  session = anonymousSession(wait: const Duration(hours: 1));
  failures['signInAnonymously'] = StateError('No network.');
  await session.start(FakeAuth());
  failures.clear();
  debugPrinted.clear();
  takeCalls();
  lifecycle(AppLifecycleState.paused);
  await pump();
  final whilePaused = takeCalls();
  lifecycle(AppLifecycleState.resumed);
  await pump();
  result['the app is paused and then resumed'] = {
    'calls while it is paused': whilePaused,
    ...note(session),
  };
  session.dispose();

  // A session that is disposed of while a call is on its way: the call
  // ends as it would have, and no anonymous sign-in follows it.
  onDevice = null;
  session = anonymousSession(wait: const Duration(hours: 1));
  await session.start(FakeAuth());
  takeCalls();
  hold = holds['signOut'] = Completer<void>();
  final signOut = failureOf(session.signOut);
  await pump();
  session.dispose();
  holds.clear();
  hold.complete();
  result['a call that ends after dispose'] = {
    'it': await signOut,
    'calls': takeCalls(),
  };

  // Two starts at once, before the first one is over.
  onDevice = null;
  session = anonymousSession(wait: const Duration(milliseconds: 20));
  hold = holds['signInAnonymously'] = Completer<void>();
  final both = FakeAuth();
  await Future.wait([session.start(both), session.start(both)]);
  result['two starts at once'] = note(session);
  holds.clear();
  hold.complete();
  await pump();
  session.dispose();

  // A call that works and leaves nobody signed in, as a password reset in
  // an app whose anonymous sign-in failed: the sign-in that follows it
  // does not hold the call back.
  onDevice = null;
  session = anonymousSession(wait: const Duration(minutes: 7));
  failures['signInAnonymously'] = StateError('No network.');
  await session.start(FakeAuth());
  failures.clear();
  debugPrinted.clear();
  takeCalls();
  hold = holds['signInAnonymously'] = Completer<void>();
  var reset = false;
  timed(
    () => unawaited(
      session.sendPasswordReset(email).then((_) => reset = true),
    ),
  );
  await pump();
  result['a call that works and leaves nobody signed in'] = {
    'the call is done': reset,
    'the waits': [for (final timer in timers) '${timer.duration}'],
    ...note(session),
  };
  holds.clear();
  hold.complete();
  await pump();
  session.dispose();
  port.send(result);
}
''';

/// Signs anonymous users in to an account that exists, with a function for
/// the data of a guest that notes what it is asked and fails when told.
const _guestData = r'''
Object? takingFails;
Object? givingFails;
bool nothingToMove = false;

Future<GiveGuestData?> take(String guestUid) async {
  calls.add('take $guestUid');
  if (takingFails case final error?) throw error;
  if (nothingToMove) return null;
  return (accountUid) async {
    calls.add('give $accountUid');
    if (givingFails case final error?) throw error;
  };
}

/// A session of [mode] that started on a device without a user.
Future<AppSessionController> sessionOf(AuthMode mode) async {
  onDevice = null;
  final session = AppSessionController(mode: mode, takeGuestData: take);
  await session.start(FakeAuth());
  takeCalls();
  return session;
}

Map<String, Object?> note(AppSessionController session, [String? failure]) => {
      'calls': takeCalls(),
      'state': show(session.value),
      if (failure != null) 'failure': failure,
    };

Future<void> main(List<String> arguments, SendPort port) async {
  accounts[email] = (uid: 'owner', password: password);
  Future<void> signIn(AppSessionController session) =>
      session.signIn(email: email, password: password);

  var session = await sessionOf(AuthMode.anonymous);
  await signIn(session);
  result['an anonymous user signs in'] = note(session);
  // The user of an account who signs in again is no guest.
  await signIn(session);
  result['the user of an account signs in'] = note(session);
  session.dispose();

  nothingToMove = true;
  session = await sessionOf(AuthMode.anonymous);
  await signIn(session);
  result['with nothing to move'] = note(session);
  nothingToMove = false;
  session.dispose();

  session = await sessionOf(AuthMode.anonymous);
  takingFails = StateError('The cart does not load.');
  result['taking fails'] = note(session, await failureOf(() => signIn(session)));
  takingFails = null;
  result['the sign-in fails'] = note(
    session,
    await failureOf(() => session.signIn(email: email, password: 'wrong')),
  );
  givingFails = StateError('The cart does not save.');
  result['giving fails'] = note(session, await failureOf(() => signIn(session)));
  givingFails = null;
  result['reported'] = reported();
  session.dispose();

  // Sign-up gives the guest the account, so nothing moves.
  session = await sessionOf(AuthMode.anonymous);
  await session.signUp(email: 'bob@example.com', password: password);
  result['an anonymous user signs up'] = note(session);
  session.dispose();

  // A sign-in after which the user has the id of the guest.
  session = await sessionOf(AuthMode.anonymous);
  accounts['same@example.com'] = (uid: session.value.uid!, password: password);
  await session.signIn(email: 'same@example.com', password: password);
  result['the account has the id of the guest'] = note(session);
  session.dispose();

  // An app without anonymous users.
  session = await sessionOf(AuthMode.guest);
  await signIn(session);
  result['a user who is not signed in signs in'] = note(session);
  session.dispose();

  // An anonymous user whom the provider has on the device in an app of
  // another mode: sign-up gives that user the account, and sign-in moves
  // the data.
  for (final mode in [AuthMode.guest, AuthMode.required]) {
    final name = mode.name;
    onDevice = AuthUser(uid: 'restored-$name', isAnonymous: true);
    session = AppSessionController(mode: mode, takeGuestData: take);
    await session.start(FakeAuth());
    await session.signUp(email: '$name@example.com', password: password);
    final signedUp = note(session);
    session.dispose();
    onDevice = AuthUser(uid: 'other-$name', isAnonymous: true);
    session = AppSessionController(mode: mode, takeGuestData: take);
    await session.start(FakeAuth());
    await signIn(session);
    result['an anonymous user in the mode $name'] = {
      'signs up': signedUp,
      'signs in': note(session),
    };
    session.dispose();
  }

  result['the function of the app has nothing to move'] =
      await takeGuestData('user-1') == null;
  port.send(result);
}
''';

/// The files of the test app of [mode]: the files of the role, as its
/// template generates them with [methods], the fake provider, and the file
/// of the function of the ways to sign in.
Future<DartFiles> _app({
  AuthMode mode = AuthMode.required,
  bool async = false,
  List<SignInMethod> methods = const [],
}) async {
  final rendered = await _rendered(mode: mode, async: async, methods: methods);
  return DartFiles.write(
    {
      ...rendered.files,
      'lib/fakes/fake_auth.dart': _fakeAuth,
      _methodPath: _fakeMethod,
    },
    flutter: const {'foundation.dart': _foundation, 'widgets.dart': _widgets},
  );
}

/// The top-level functions of [unit], by name.
Map<String, FunctionDeclaration> _functionsOf(CompilationUnit unit) => {
      for (final function in unit.declarations.whereType<FunctionDeclaration>())
        function.name.lexeme: function,
    };

/// The top-level variables of [unit], by name, each as its declaration.
Map<String, String> _variablesOf(CompilationUnit unit) => {
      for (final declaration
          in unit.declarations.whereType<TopLevelVariableDeclaration>())
        for (final variable in declaration.variables.variables)
          variable.name.lexeme: declaration.toSource(),
    };

/// The statements of the body of [function].
List<String> _statementsOf(FunctionDeclaration function) => [
      for (final statement
          in (function.functionExpression.body as BlockFunctionBody)
              .block
              .statements)
        '$statement',
    ];

/// The interface that a provider of the role implements.
const _service = 'AuthService';

/// The signature of [member], a method or a getter, as its code.
String _signatureOf(MethodDeclaration member) => [
      '${member.returnType} ',
      if (member.isGetter) 'get ',
      member.name.lexeme,
      '${member.parameters ?? ''}',
    ].join();

/// The values of the enum [name] of [unit].
List<String> _enumValuesOf(CompilationUnit unit, String name) => [
      for (final constant in unit.declarations
          .whereType<EnumDeclaration>()
          .singleWhere(
            (declaration) => declaration.namePart.typeName.lexeme == name,
          )
          .body
          .constants)
        constant.name.lexeme,
    ];

/// The template of a role whose code may reach the session, as that of a
/// role with screens of sign-in would.
final _otherRole = TestRole<NoDsl>('account_screens');

/// The implementation of the provider of the apps of the rules: its class
/// in one file and its function in another.
const _providerImplementation = AuthImplementation(
  type: TypeRef(
    'FakeAuthService',
    import: ImportRef.app('core/auth/fake_auth_service.dart'),
  ),
  create: FactoryRef(
    'createFakeAuthService',
    import: ImportRef.app('core/auth/fake_auth.dart'),
  ),
);

/// The file of the function of [_providerImplementation], which imports
/// the file of `AuthService`, as the file of an implementation may.
const _factoryFile = DartFileIndex(
  path: 'lib/core/auth/fake_auth.dart',
  imports: [IndexedImport('auth_service.dart')],
  declarations: [
    IndexedDeclaration(
      name: 'createFakeAuthService',
      kind: DeclarationKind.function,
    ),
  ],
);

/// The provider of the role and a feature that uses the role.
const _provider = ModuleDescriptor(
  id: ModuleId('fake_auth'),
  description: 'Sign-in',
  kind: ModuleKinds.infrastructure,
  providers: [RoleProvider.plain(authRole)],
);
const _feature = ModuleDescriptor(
  id: ModuleId('profile'),
  description: 'Profile',
  kind: ModuleKinds.feature,
  uses: {authRole},
);

/// The issues of the structural rules of the role in an app of the
/// provider with [_providerImplementation] and with [files], each with its
/// owner; a file without an owner has `null`.
List<SmfIssue> _structureIssues(
  Map<DartFileIndex, ContributionOrigin?> files,
) =>
    authRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: [
            dataOf(authRole, _providerImplementation, module: 'fake_auth'),
          ],
          presentRoles: {authRole},
          context: testContext,
        ),
        files: {
          _factoryFile.path: _factoryFile,
          for (final file in files.keys) file.path: file,
        },
        owners: {
          _factoryFile.path: ModuleOrigin(_provider.id),
          for (final MapEntry(key: file, value: owner) in files.entries)
            if (owner != null) file.path: owner,
        },
        modules: const [_provider, _feature],
      ),
    );

/// The screen [name] of the feature [feature], for the routes of the tests.
ScreenRef _screen(String name, String feature) => ScreenRef(
      name,
      import: ImportRef.app(
        'features/$feature/${SmfNames.snakeCaseOf(name)}.dart',
      ),
    );

/// The routes of the feature `profile`, which has no guard: a screen that
/// every user sees, and a screen for the users of an account with a screen
/// below it, which asks for the account by being there.
final RoutesData _profileRoutes = RoutesData([
  Route('/', name: 'overview', screen: _screen('ProfileScreen', 'profile')),
  Route(
    '/account',
    name: 'account',
    screen: _screen('AccountScreen', 'profile'),
    conditions: const [AuthRole.account],
    children: [
      Route('email', name: 'email', screen: _screen('EmailScreen', 'profile')),
    ],
  ),
]);

/// The routes of the feature `shop`, which has no guard either: one screen,
/// for the users of an account.
final RoutesData _shopRoutes = RoutesData([
  Route(
    '/orders',
    name: 'orders',
    screen: _screen('OrdersScreen', 'shop'),
    conditions: const [AuthRole.account],
  ),
]);

/// The routes of the feature `login`, the screens of sign-in, with
/// [guards].
RoutesData _loginRoutes(List<RouteGuard> guards) => RoutesData(
      [Route('/', name: 'signIn', screen: _screen('SignInScreen', 'login'))],
      guards: guards,
    );

/// The file of the functions of the guards of the feature `login`.
const _loginGuards = ImportRef.app('features/login/login_guards.dart');

/// The gate of the feature `login`, which keeps a user from the whole app.
const _loginGate = RouteGuard(
  name: 'app',
  allows: FunctionRef('allowsApp', import: _loginGuards),
  redirectTo: 'signIn',
  stage: GuardStage.identity,
  resumes: false,
);

/// The guard of the feature `login` that stands for the account.
const _accountGuard = RouteGuard(
  name: 'account',
  allows: FunctionRef('hasAccount', import: _loginGuards),
  redirectTo: 'signIn',
  stage: GuardStage.identity,
  condition: AuthRole.account,
);

/// What the template of the role reports for an app with a provider of
/// the role, with [routes], the routes of the features by their ids, and
/// with the roles in [present] besides the auth role.
List<SmfIssue> _issuesWith(
  Map<String, RoutesData> routes, {
  Set<Role> present = const {routerRole},
  AuthImplementation? implementation,
}) =>
    authRole.template.validate(
      inputOf(
        authRole,
        data: [
          dataOf(
            authRole,
            implementation ?? _implementation(async: false),
            module: 'fake_auth',
          ),
          for (final MapEntry(key: module, value: data) in routes.entries)
            dataOf(routerRole, data, module: module),
        ],
        present: present,
      ),
    );

/// The index of the file at [path] that imports the file of the session
/// and calls [function] of it.
DartFileIndex _calling(String path, String function) => DartFileIndex(
      path: path,
      imports: const [
        IndexedImport('package:my_app/core/auth/app_session.dart'),
      ],
      invocations: [IndexedInvocation(function)],
    );

/// Signs in with credentials: a user who is not signed in, the user of an
/// account, and anonymous users whose identity is new, belongs to another
/// user, or has the address of an account that signs in in another way,
/// with a function for the data of a guest that notes what it is asked.
const _signInWith = r'''
Future<GiveGuestData?> take(String guestUid) async {
  calls.add('take $guestUid');
  return (accountUid) async => calls.add('give $accountUid');
}

/// A session of [mode] that started on a device without a user.
Future<AppSessionController> sessionOf(AuthMode mode) async {
  onDevice = null;
  final session = AppSessionController(mode: mode, takeGuestData: take);
  await session.start(FakeAuth());
  takeCalls();
  credentials.clear();
  return session;
}

String issuersOf(AppSession session) => switch (session) {
      AccountSession(:final issuers) => issuers.join(', '),
      _ => '-',
    };

Map<String, Object?> note(AppSessionController session, [String? failure]) => {
      'calls': takeCalls(),
      'state': show(session.value),
      'issuers': issuersOf(session.value),
      if (failure != null) 'failure': failure,
    };

IdTokenCredential tokenOf(String name) =>
    IdTokenCredential(issuer: 'https://id.example.com', idToken: name);

Future<void> main(List<String> arguments, SendPort port) async {
  var session = await sessionOf(AuthMode.guest);
  await session.signInWith(credential);
  result['a user who is not signed in'] = note(session);
  final first = session.value.uid;
  await session.signInWith(tokenOf('token-of-bob'));
  result['the user of an account, with another identity'] = note(session);
  await session.signInWith(credential);
  result['the first identity again'] = {
    ...note(session),
    'the same user': session.value.uid == first,
  };
  result['the issuers cannot change'] = await failureOf(() async {
    (session.value as AccountSession).issuers.add('https://other.example.com');
  });
  session.dispose();

  identities.clear();
  session = await sessionOf(AuthMode.anonymous);
  final guest = session.value.uid;
  await session.signInWith(credential);
  result['an anonymous user, with a new identity'] = {
    ...note(session),
    'keeps the id': session.value.uid == guest,
  };
  session.dispose();

  session = await sessionOf(AuthMode.anonymous);
  await session.signInWith(credential);
  result['an anonymous user, with the identity of another user'] = {
    ...note(session),
    'the sign-in got the credential of the link': credentials.length == 2 &&
        identical(credentials.first, credentials.last),
  };
  session.dispose();

  session = await sessionOf(AuthMode.anonymous);
  failures['linkWith'] = const AuthFailure(
    AuthFailureReason.accountExistsWithOtherMethod,
  );
  await session.signInWith(tokenOf('token-of-carol'));
  failures.clear();
  result['an anonymous user, with an identity whose address has an account'] =
      note(session);
  session.dispose();

  session = await sessionOf(AuthMode.anonymous);
  failures['linkWith'] = const AuthFailure(
    AuthFailureReason.accountExistsWithOtherMethod,
  );
  failures['signInWith'] = const AuthFailure(
    AuthFailureReason.accountExistsWithOtherMethod,
  );
  final refused =
      await failureOf(() => session.signInWith(tokenOf('token-of-dan')));
  failures.clear();
  result['the sign-in after the link fails too'] = note(session, refused);
  session.dispose();

  for (final (name, error) in [
    ('another reason', const AuthFailure(AuthFailureReason.network)),
    ('an error of another kind', StateError('The link broke.')),
  ]) {
    session = await sessionOf(AuthMode.anonymous);
    failures['linkWith'] = error;
    final failure =
        await failureOf(() => session.signInWith(tokenOf('token-of-eve')));
    failures.clear();
    result['a link that fails with $name'] = note(session, failure);
    session.dispose();
  }
  port.send(result);
}
''';

/// The ways to sign in of the app of [_revokingDeletion]: one on iOS and
/// one on both platforms that ask for a credential again before a
/// deletion, and one that does not.
final List<SignInMethod> _deletionMethods = [
  _method(revokes: true, platforms: const {AppPlatform.ios}),
  _method(issuer: 'https://other.example.com', revokes: true),
  _method(issuer: 'https://plain.example.com'),
];

/// Deletes accounts of ways to sign in, on Android and on iOS, while the
/// way to sign in answers with a credential, with `null`, or with an error,
/// and while the service deletes or fails, in the app of
/// [_deletionMethods].
const _revokingDeletion = '''
const fresh = IdTokenCredential(
  issuer: 'https://id.example.com',
  idToken: 'fresh-token',
  authorizationCode: 'code',
);

/// A session in [mode] with the user of an account on the device, who
/// signs in with [issuers].
Future<AppSessionController> sessionOf(
  Set<String> issuers, {
  AuthMode mode = AuthMode.required,
}) async {
  onDevice = AuthUser(uid: 'account', isAnonymous: false, issuers: issuers);
  final session = AppSessionController(
    mode: mode,
    takeGuestData: takeGuestData,
  );
  await session.start(FakeAuth());
  takeCalls();
  credentials.clear();
  return session;
}

/// Deletes the account of [issuers] on [platform], while the way to sign in
/// answers [answered] and the service fails with [deletionFails].
Future<Map<String, Object?>> delete(
  Set<String> issuers, {
  TargetPlatform platform = TargetPlatform.iOS,
  Object? answered = fresh,
  Object? deletionFails,
  AuthMode mode = AuthMode.required,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  answer = answered;
  final session = await sessionOf(issuers, mode: mode);
  if (deletionFails != null) failures['deleteAccount'] = deletionFails;
  final failure = await failureOf(session.deleteAccount);
  failures.clear();
  final noted = {
    'calls': takeCalls(),
    'state': show(session.value),
    'failure': failure,
    if (credentials.isNotEmpty)
      'the service got the credential of the way to sign in':
          identical(credentials.single, answered),
  };
  session.dispose();
  return noted;
}

const id = 'https://id.example.com';
const other = 'https://other.example.com';
const plain = 'https://plain.example.com';

Future<void> main(List<String> arguments, SendPort port) async {
  result['a way to sign in that revokes, on its platform'] = await delete({id});
  result['the same way to sign in on another platform'] =
      await delete({id}, platform: TargetPlatform.android);
  result['two that revoke, on the platform of the second only'] =
      await delete({id, other}, platform: TargetPlatform.android);
  result['a way to sign in that does not revoke'] = await delete({plain});
  result['no way to sign in'] = await delete({});
  result['the user closes the sheet'] = await delete({id}, answered: null);
  result['the way to sign in fails'] = await delete(
    {id},
    answered: const AuthFailure(
      AuthFailureReason.notConfigured,
      developerHint: 'Set up the capability.',
    ),
  );
  result['the way to sign in throws another error'] =
      await delete({id}, answered: StateError('The sheet broke.'));
  result['the revocation fails'] = await delete(
    {id},
    deletionFails: const AuthFailure(
      AuthFailureReason.notConfigured,
      developerHint: 'Set up the key.',
    ),
  );
  result['in the anonymous mode'] =
      await delete({id}, mode: AuthMode.anonymous);

  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  answer = fresh;
  final session = await sessionOf({id});
  final hold = holdCredential = Completer<void>();
  final deleted = session.deleteAccount();
  unawaited(session.signOut());
  await pump();
  final whileItAsks = takeCalls();
  holdCredential = null;
  hold.complete();
  await deleted;
  await pump();
  result['a call while the way to sign in asks'] = {
    'calls while it asks': whileItAsks,
    'calls': takeCalls(),
  };
  session.dispose();
  port.send(result);
}
''';

/// The file of the test app with the function of the ways to sign in of a
/// second module, and their icon.
const _secondMethod = '''
import 'package:flutter/widgets.dart';

import '../core/auth/app_session.dart';

Future<SignInCredential?> secondCredential() async => const IdTokenCredential(
      issuer: 'https://second.example.com',
      idToken: 'second-token',
    );

final class SecondIcon extends Widget {
  const SecondIcon();
}
''';

/// The file of [_secondMethod].
const _secondFile = ImportRef.app('fakes/second_method.dart');

/// The file of the texts of a provider of the localization role, with a
/// getter for each of [getters], which returns the name of the getter after
/// the language of the context.
String _textsFile(List<String> getters) => [
      "import 'package:flutter/widgets.dart';",
      '',
      'final class Texts {',
      '  const Texts(this._language);',
      '',
      '  final String _language;',
      for (final getter in getters) ...[
        '',
        "  String get $getter => '\$_language $getter';",
      ],
      '}',
      '',
      'extension AppTexts on BuildContext {',
      '  Texts get l10n => Texts(language);',
      '}',
      '',
    ].join('\n');

/// A script that sends the ways to sign in of the app: for each, its label
/// in English and in Ukrainian, the type of its icon, its platforms, its
/// issuer, whether it revokes, whether it is available on Android and on
/// iOS, and what its function returns.
const _readMethods = r'''
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:my_app/core/auth/app_session.dart';
import 'package:my_app/core/auth/sign_in_methods.dart';
import 'package:my_app/fakes/fake_method.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  answer = const IdTokenCredential(
    issuer: 'https://id.example.com',
    idToken: 'token',
  );
  bool availableOn(SignInMethod method, TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    return method.isAvailable;
  }

  port.send([
    for (final method in appSignInMethods)
      {
        'label': '${method.label(const BuildContext('en'))} / '
            '${method.label(const BuildContext('uk'))}',
        'icon': '${method.icon.runtimeType}',
        'platforms': [for (final platform in method.platforms) platform.name],
        'issuer': method.issuer,
        'revokes': method.revokesOnDeletion,
        'on Android': availableOn(method, TargetPlatform.android),
        'on iOS': availableOn(method, TargetPlatform.iOS),
        'credential': '${await method.credential()}',
      },
  ]);
}
''';

/// What [_readMethods] sends for the app of the template rendered with
/// [data] in an app with the roles in [present], once its files type-check
/// with the files of the functions against the stand-ins of Flutter and
/// [texts], the file of the texts of the app, if it has one. It also
/// returns the file of the ways to sign in.
Future<(String, Object?)> _methodsOf(
  List<RoleData<Object>> data, {
  Set<Role> present = const {},
  String? texts,
}) async {
  final rendered = await renderTemplate(
    authRole,
    data: [
      dataOf(authRole, _implementation(async: false), module: 'fake_auth'),
      ...data,
    ],
    present: present,
    choice: AuthMode.required,
  );
  final files = DartFiles.write(
    {
      ...rendered.files,
      'lib/fakes/fake_auth.dart': _fakeAuth,
      _methodPath: _fakeMethod,
      'lib/${_secondFile.uri}': _secondMethod,
      if (texts != null) LocalizationRole.textsFile: texts,
    },
    flutter: const {'foundation.dart': _foundation, 'widgets.dart': _widgets},
  );
  try {
    final code = rendered.files[AuthRole.methodsFile]!;
    expect(await files.analysisProblems(), isEmpty, reason: code);
    return (code, await files.run(_readMethods));
  } finally {
    files.delete();
  }
}

/// The named arguments of each way to sign in of the list of the Dart
/// [code], each as its source by its name.
List<Map<String, String>> _itemsOf(String code) {
  final list = parseString(content: code)
      .unit
      .declarations
      .whereType<TopLevelVariableDeclaration>()
      .single
      .variables
      .variables
      .single
      .initializer! as ListLiteral;
  return [
    for (final item in list.elements)
      {
        for (final argument
            in (item as MethodInvocation).argumentList.arguments)
          if (argument
              case NamedArgument(:final name, :final argumentExpression))
            name.lexeme: argumentExpression.toSource(),
      },
  ];
}

/// The imports of the Dart [code], in order, each as its URI and, after a
/// space, its prefix if it has one.
List<String> _importsOf(String code) => [
      for (final directive in parseString(content: code).unit.directives)
        if (directive is ImportDirective)
          [
            directive.uri.stringValue,
            if (directive.prefix case final prefix?) prefix.name,
          ].join(' '),
    ];

/// A brick named [name] with a file at each of [paths].
BrickContribution _brick(List<String> paths, {String name = 'brick'}) =>
    BrickContribution(
      MasonBundle(
        name: name,
        description: name,
        version: '0.1.0',
        files: [
          for (final path in paths)
            MasonBundledFile(
              path,
              base64.encode(utf8.encode('// A file of the tests.\n')),
              'text',
            ),
        ],
      ),
    );

/// A module with ways to sign in, which requires the role and uses the
/// localization role.
const _methodModule = ModuleDescriptor(
  id: ModuleId('example_sign_in'),
  description: 'Sign-in with an example identity provider',
  kind: ModuleKinds.infrastructure,
  requires: {authRole},
  uses: {localizationRole},
);

/// The issues of the module rules of the role for [module], which
/// contributes [contributions], in an app with the localization role.
List<SmfIssue> _methodModuleIssues(
  List<Contribution> contributions, {
  ModuleDescriptor module = _methodModule,
}) {
  final origin = ModuleOrigin(module.id);
  // The pipeline gives each data its origin when it collects it.
  final own = [
    for (final contribution in contributions)
      if (contribution is RoleData<Object>)
        contribution.withOrigin(origin)
      else
        contribution,
  ];
  return authRole.checkModule(
    ModuleRuleRequest(
      hook: RoleHookRequest(
        data: [...own.whereType<RoleData<Object>>()],
        presentRoles: {authRole, localizationRole},
        context: testContext,
      ),
      module: module,
      contributions: own,
    ),
  );
}

void main() {
  group('the auth role', () {
    test(
        'takes one provider, requires no other role, works with a router and '
        'with the texts of the app, and has the socket of its '
        'implementation, the option of the mode and four files', () {
      expect(authRole.id, 'auth');
      expect(authRole.description, 'Authentication');
      expect(authRole.presenceFlag, 'has_auth');
      expect('$authRole', 'authentication role');
      expect(authRole.cardinality, RoleCardinality.atMostOne);
      expect(authRole.requires, isEmpty);
      // The router, whose routes ask for the account, and the texts of the
      // app, which the labels of the ways to sign in are. Not the DI role:
      // the role registers nothing in a container.
      expect(authRole.uses, {routerRole, localizationRole});
      // Its provider uses what the role uses, so the contract harness
      // builds the apps of a provider with a router and without one, and
      // with the texts of the app and without them.
      expect(_provider.effectiveUses, {routerRole, localizationRole});
      expect(_provider.effectiveRequires, isEmpty);
      expect(authRole.sockets, const [AuthRole.implementations]);
      expect(AuthRole.implementations.tag, 'smf_auth__implementations');
      expect(authRole.options, const [AuthRole.modeOption]);
      expect(authRole.interface.files, [
        'lib/core/auth/auth_service.dart',
        'lib/core/auth/app_session.dart',
        'lib/core/auth/guest_data.dart',
        'lib/core/auth/sign_in_methods.dart',
      ]);
      expect(authRole.interface.files, [
        AuthRole.serviceFile,
        AuthRole.sessionFile,
        AuthRole.guestDataFile,
        AuthRole.methodsFile,
      ]);
      expect(authRole.interface.symbols, const [AuthRole.signInMethod]);
      expect(AuthRole.signInMethod.path, AuthRole.methodsFile);
      expect(AuthRole.appSignInMethods, 'appSignInMethods');
      expect(
        [for (final rule in authRole.moduleRules) rule.id],
        ['services.implementations', 'auth.methods'],
      );
      expect(
        [for (final rule in authRole.structuralRules) rule.id],
        [
          'auth.factory_calls',
          'auth.start_calls',
          'auth.implementation_factories',
          'auth.method_functions',
        ],
      );
    });
  });

  group('the mode of the auth role', () {
    const option = AuthRole.modeOption;

    /// The choice of the role with [value] for its option, in a terminal
    /// whose user picks the item at [pick], or without a terminal.
    Future<Object?> choose(String? value, {SmfEnvironment? environment}) =>
        authRole.template.choose(
          authRole.choiceContext(
            RoleChoiceRequest(
              data: const [],
              presentRoles: {authRole},
              optionValues: {option.name: value},
              environment: environment ?? FakeEnvironment(),
              context: testContext,
            ),
          ),
        );

    test(
        'is the mode option --auth-mode, whose values are the modes, with '
        'the mode that asks for an account first', () {
      expect(option.name, 'auth-mode');
      expect(option.isMode, isTrue);
      expect(option.allowed, ['required', 'guest', 'anonymous']);
      expect(option.allowed, [for (final mode in AuthMode.values) mode.name]);
      for (final mode in AuthMode.values) {
        expect(option.help, contains(mode.name));
      }
    });

    test('is the value of the option, which nothing asks for then', () async {
      for (final mode in AuthMode.values) {
        // The environment without a terminal fails when it is asked.
        expect(await choose(mode.name), mode);
        final terminal = PromptingEnvironment(pick: 2);
        expect(await choose(mode.name, environment: terminal), mode);
        expect(terminal.asked, isEmpty);
      }
    });

    test(
        'is the first mode in a run without a terminal and without the '
        'option, which neither fails nor asks', () async {
      expect(await choose(null), AuthMode.required);
    });

    test(
        'is asked for in a terminal without the option, with the first mode '
        'as the first item and as the one that Enter takes', () async {
      for (final (pick, mode) in AuthMode.values.indexed) {
        final terminal = PromptingEnvironment(pick: pick);

        expect(await choose(null, environment: terminal), mode);
        expect(terminal.asked, ['Who may use the app without an account?']);
        expect(terminal.shown, [
          'Nobody: the user signs in first',
          'Everyone: an account only where a screen needs one',
          'Everyone, as an anonymous user with an id from the start',
        ]);
        expect(terminal.shownDefault, terminal.shown.first);
      }
    });

    test(
        'has the option for every choice, with which a run without a '
        'terminal makes the same choice', () async {
      for (final mode in AuthMode.values) {
        final options = authRole.template.optionsOf(mode);

        expect(options, {'auth-mode': mode.name});
        expect(await choose(options[option.name]), mode);
      }
    });

    test('reaches the render hooks of the role and of its provider', () {
      for (final mode in AuthMode.values) {
        expect(authRole.modeIn(inputOf(authRole, choice: mode)), mode);
      }
    });
  });

  group('the declaration of the mode, which a tool of the app reads,', () {
    /// The line of the mode in an app that was generated in the mode
    /// `required`.
    const generated = 'const AuthMode authMode = AuthMode.required;';

    /// The file of the session of an app in the mode `required`, as `dart
    /// format` leaves it.
    late String session;

    /// [source], a Dart file, as `dart format` of the SDK of the tests
    /// leaves it.
    String formatted(String source) {
      final directory = Directory.systemTemp.createTempSync('smf_auth_mode_');
      try {
        final file = File('${directory.path}/app_session.dart')
          ..writeAsStringSync(source);
        final result = Process.runSync(
          Platform.resolvedExecutable,
          ['format', file.path],
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
        return file.readAsStringSync();
      } finally {
        directory.deleteSync(recursive: true);
      }
    }

    /// [session] with [declaration] in place of the line of the mode.
    String withLine(String declaration) {
      expect(session, contains('\n$generated\n'));
      return session.replaceFirst(generated, declaration);
    }

    setUpAll(() async {
      session = formatted(
        (await _rendered()).files[AuthRole.sessionFile]!,
      );
    });

    test(
        'is read from the file of the session of an app of each mode, as '
        'the template writes it and as dart format leaves it', () async {
      for (final mode in AuthMode.values) {
        final rendered =
            (await _rendered(mode: mode)).files[AuthRole.sessionFile]!;
        final ofApp = formatted(rendered);

        expect(authRole.modeWrittenIn(rendered), mode, reason: mode.name);
        expect(authRole.modeWrittenIn(ofApp), mode, reason: mode.name);
        // The line that the doc of the constant asks the developer to keep.
        expect(
          ofApp,
          contains('\nconst AuthMode authMode = AuthMode.${mode.name};\n'),
        );
        expect(
          ofApp,
          contains(
            '/// To change the mode, change its value and keep the '
            'declaration as it is,\n'
            '/// on a line that it starts: a tool of the app that cannot '
            'import this\n'
            '/// file, which imports Flutter, reads the mode from this '
            'line.\n'
            'const AuthMode authMode = ',
          ),
        );
      }
    });

    test(
        'is read as a developer of the app may leave it: without the type, '
        'with final, with the value on the next line, with a comment after '
        'it, and in a file with other line ends', () {
      final read = {
        for (final declaration in [
          'const authMode = AuthMode.guest;',
          'final AuthMode authMode = AuthMode.guest;',
          'final authMode = AuthMode.anonymous;',
          'const AuthMode authMode =\n    AuthMode.anonymous;',
          'const AuthMode authMode = AuthMode.guest; // until the release',
          'const AuthMode authMode = AuthMode.guest; /* for now */',
          'const AuthMode  authMode  =  AuthMode.anonymous ;',
        ])
          declaration: authRole.modeWrittenIn(withLine(declaration)),
      };

      expect(read, {
        'const authMode = AuthMode.guest;': AuthMode.guest,
        'final AuthMode authMode = AuthMode.guest;': AuthMode.guest,
        'final authMode = AuthMode.anonymous;': AuthMode.anonymous,
        'const AuthMode authMode =\n    AuthMode.anonymous;':
            AuthMode.anonymous,
        'const AuthMode authMode = AuthMode.guest; // until the release':
            AuthMode.guest,
        'const AuthMode authMode = AuthMode.guest; /* for now */':
            AuthMode.guest,
        'const AuthMode  authMode  =  AuthMode.anonymous ;': AuthMode.anonymous,
      });
      // As an editor of Windows saves the file.
      expect(
        authRole.modeWrittenIn(
          withLine('const AuthMode authMode = AuthMode.guest;')
              .replaceAll('\n', '\r\n'),
        ),
        AuthMode.guest,
      );
    });

    test(
        'is not a declaration within a comment, nor that of a local '
        'variable: the file tells the mode by the one that is code', () {
      const real = 'const AuthMode authMode = AuthMode.guest;';
      const old = 'const AuthMode authMode = AuthMode.anonymous;';
      final read = {
        for (final (name, text) in [
          ('a comment of a line above', '// $old\n$real'),
          ('a doc comment above', '/// As generated: `$old`\n$real'),
          ('a block comment above', '/*\n$old\n*/\n$real'),
          ('a block comment on its line', '/* $old */\n$real'),
          (
            'a block comment within a block comment',
            '/* before /* within */\n$old\n*/\n$real',
          ),
          ('a block comment with a line comment', '/*\n// */\n$real'),
          (
            'a line comment that starts a block comment',
            '// see /* below\n$real\n// */',
          ),
          (
            'a local variable',
            '$real\n\nAuthMode _other() {\n'
                '  const authMode = AuthMode.anonymous;\n'
                '  return authMode;\n'
                '}',
          ),
          (
            'a constant of another name',
            '$real\n\nconst AuthMode authModeOfTests = AuthMode.anonymous;',
          ),
        ])
          name: authRole.modeWrittenIn(withLine(text)),
      };

      expect(read, {
        for (final name in read.keys) name: AuthMode.guest,
      });
    });

    test(
        'does not tell the mode when a tool would have to guess: with a '
        'value that is no mode, a computed value, two declarations, or none '
        'that is code', () {
      const old = 'const AuthMode authMode = AuthMode.anonymous;';
      const computed = 'final AuthMode authMode = modeOfBuild();';
      final read = {
        for (final (name, text) in [
          // A misspelt mode, which does not compile in the app either.
          ('no mode', 'const AuthMode authMode = AuthMode.anonymus;'),
          ('a longer name', 'const AuthMode authMode = AuthMode.guests;'),
          ('another type', 'const AuthMode authMode = Modes.guest;'),
          ('a computed value', computed),
          (
            'a value by a condition',
            'const AuthMode authMode =\n'
                "    bool.fromEnvironment('GUEST') ? AuthMode.guest : "
                'AuthMode.required;',
          ),
          ('a member of the mode', 'final authMode = AuthMode.guest.index;'),
          (
            'two declarations',
            'const AuthMode authMode = AuthMode.guest;\n'
                'const AuthMode authMode = AuthMode.guest;',
          ),
          ('one in a block comment only', '/*\n$old\n*/\n$computed'),
          ('one in a line comment only', '// $old\n$computed'),
          (
            'one within two block comments only',
            '/* before /* within */\n$old\n*/\n$computed',
          ),
          (
            'a comment within it',
            'const AuthMode authMode = /* was guest */ AuthMode.anonymous;',
          ),
          ('one that does not start its line', '  $old'),
          ('a field of a class', 'class Modes {\n  static $old\n}'),
          ('none', ''),
        ])
          name: authRole.modeWrittenIn(withLine(text)),
      };

      expect(read, {for (final name in read.keys) name: null});
      expect(authRole.modeWrittenIn(''), isNull);
    });

    test(
        'is a regular expression that a tool of the app runs itself: a '
        'match with a group is a declaration, with the name of its mode', () {
      // As a script of the app reads it, without this package.
      List<String?> matchesIn(String source) => [
            for (final match in RegExp(
              AuthRole.modeDeclaration,
              multiLine: true,
            ).allMatches(source))
              match[1],
          ];

      expect(
        AuthRole.modeDeclaration,
        endsWith(r'(required|guest|anonymous)\s*;'),
      );
      expect(
        [for (final mode in AuthMode.values) mode.name],
        ['required', 'guest', 'anonymous'],
      );
      expect(
        matchesIn(
          '// The mode.\n'
          'const AuthMode authMode = AuthMode.guest; /* a */ // b\n'
          '/* const authMode = AuthMode.required; */\n'
          'final authMode = AuthMode.anonymous;\n',
        ),
        [null, 'guest', null, null, null, 'anonymous'],
      );
      expect(
        matchesIn(session).nonNulls,
        ['required'],
        reason: 'The file of the session has one declaration, and every '
            'other match is one of its comments.',
      );
    });
  });

  group('the account condition of the auth role', () {
    /// What every warning of the role says to do.
    const hint = 'Add a module with the screens of sign-in to the app, or '
        'keep the other users away later with a guard of your own that '
        'reads appSession.hasAccount.';

    test(
        'is the condition account of the role, which a route asks for and '
        'a guard stands for', () {
      const account = AuthRole.account;

      expect(account.role, same(authRole));
      expect(account.name, 'account');
      expect('$account', 'auth.account');
      // A condition of the same role and name, created anew, is the same
      // one, and a condition of that name of another role is not.
      expect(account, RouteCondition(authRole, ['acc', 'ount'].join()));
      expect(account, isNot(RouteCondition(_otherRole, 'account')));
    });

    test(
        'lets the hooks of the role and of its provider read the routes '
        'that ask for it and the guard that stands for it, in an app with '
        'a router', () {
      final data = [
        dataOf(routerRole, _profileRoutes, module: 'profile'),
        dataOf(
          routerRole,
          _loginRoutes(const [_loginGate, _accountGuard]),
          module: 'login',
        ),
      ];
      final input = inputOf(authRole, data: data, present: {routerRole});

      expect(input.has(routerRole), isTrue);
      final facade = routerRole.facadeOf(input);
      expect(
        [
          for (final route in facade.routesAsking(AuthRole.account))
            route.fullName,
        ],
        ['profile.account', 'profile.email'],
      );
      expect(facade.guardFor(AuthRole.account)!.fullName, 'login.account');

      // Without a router, the routes of the modules are no part of the app.
      final without = inputOf(authRole, data: data);
      expect(without.has(routerRole), isFalse);
      expect(routerRole.facadeOf(without).routes, isEmpty);
    });

    test(
        'warns of the routes that ask for it in an app without a guard for '
        'it, each by its full name, those below a route that asks too, and '
        'says what to do', () {
      final issue = _issuesWith({
        'profile': _profileRoutes,
        'shop': _shopRoutes,
      }).single;

      // A warning: an app whose developer writes the guard later is an app.
      expect(issue.isError, isFalse);
      expect(issue.code, AuthRole.openAccountRoutesWarning);
      expect(AuthRole.openAccountRoutesWarning, 'auth.open_account_routes');
      expect(
        issue.message,
        'The routes profile.account, profile.email, shop.orders are for '
        'users with an account (they ask for the condition auth.account), '
        'but no module of the app has a guard for that condition, so every '
        'user gets to them.',
      );
      expect(issue.hint, hint);
      // The pipeline names the template of the role as the one who says so.
      expect(issue.origin, isNull);
      expect(issue.path, isNull);
    });

    test('warns of one route as of one', () {
      final issue = _issuesWith({'shop': _shopRoutes}).single;

      expect(issue.isError, isFalse);
      expect(
        issue.message,
        'The route shop.orders is for users with an account (it asks for '
        'the condition auth.account), but no module of the app has a guard '
        'for that condition, so every user gets to it.',
      );
      expect(issue.hint, hint);
    });

    test(
        'warns in an app whose guards stand for something else: a gate '
        'over the whole app, and a guard for a condition of another role', () {
      final ofOtherRole = RouteGuard(
        name: 'account',
        allows: const FunctionRef('hasAccount', import: _loginGuards),
        redirectTo: 'signIn',
        stage: GuardStage.identity,
        condition: RouteCondition(_otherRole, 'account'),
      );

      final issues = _issuesWith({
        'shop': _shopRoutes,
        'login': _loginRoutes([_loginGate, ofOtherRole]),
      });

      expect(issues.single.isError, isFalse);
      expect(issues.single.message, contains('The route shop.orders is for'));
    });

    test('reports nothing in an app with a guard for it, of whichever module',
        () {
      expect(
        _issuesWith({
          'profile': _profileRoutes,
          'shop': _shopRoutes,
          'login': _loginRoutes(const [_loginGate, _accountGuard]),
        }),
        isEmpty,
      );
      // The module with the guard comes first, and has such a route itself.
      expect(
        _issuesWith({
          'login': RoutesData(
            [
              Route(
                '/',
                name: 'signIn',
                screen: _screen('SignInScreen', 'login'),
              ),
              Route(
                '/account',
                name: 'account',
                screen: _screen('AccountScreen', 'login'),
                conditions: const [AuthRole.account],
              ),
            ],
            guards: const [_accountGuard],
          ),
          'shop': _shopRoutes,
        }),
        isEmpty,
      );
    });

    test(
        'reports nothing in an app whose routes do not ask for it: an app '
        'without routes, routes without a condition, and a route that asks '
        'for a condition of that name of another role', () {
      expect(_issuesWith(const {}), isEmpty);
      expect(
        _issuesWith({
          'profile': RoutesData([
            Route(
              '/',
              name: 'overview',
              screen: _screen('ProfileScreen', 'profile'),
            ),
            Route(
              '/account',
              name: 'account',
              screen: _screen('AccountScreen', 'profile'),
              conditions: [RouteCondition(_otherRole, 'account')],
            ),
          ]),
          'login': _loginRoutes(const [_loginGate]),
        }),
        isEmpty,
      );
    });

    test(
        'reports nothing in an app without a router, where no route of a '
        'module is part of the app', () {
      expect(
        _issuesWith(
          {'profile': _profileRoutes, 'shop': _shopRoutes},
          present: const {},
        ),
        isEmpty,
      );
    });

    test('comes after the problems of the implementation, which stay errors',
        () {
      final issues = _issuesWith(
        {'shop': _shopRoutes},
        implementation: const AuthImplementation(
          type: TypeRef('_Private'),
          create: FactoryRef('create', import: _fakeFile),
        ),
      );

      expect([for (final issue in issues) issue.isError], [true, false]);
      expect(issues.first.origin, const ModuleOrigin(ModuleId('fake_auth')));
      expect(issues.last.message, contains('shop.orders'));
    });
  });

  group('the auth template', () {
    test(
        'contributes the brick of the three files and the note of the '
        'role, and registers nothing in a DI container', () {
      final contributions = authRole.template.contribute(testContext);

      expect(contributions, hasLength(2));
      final brick = contributions.whereType<BrickContribution>().single;
      expect(
        templatesOf(brick.bundle).keys,
        unorderedEquals(authRole.interface.files),
      );
      expect(brick.when, isEmpty);
      expect(contributions.whereType<RoleData<Object>>(), isEmpty);
    });

    test(
        'generates the interface that a provider implements, with the user, '
        'the reasons of a failure and the credentials of identity '
        'providers', () async {
      final unit = parseString(
        content: (await _rendered()).files[AuthRole.serviceFile]!,
      ).unit;
      const credentials = '({required String email, required String password})';

      final service = unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere((type) => type.namePart.typeName.lexeme == _service);
      expect(service.interfaceKeyword, isNotNull);
      expect(service.abstractKeyword, isNotNull);
      expect(
        [
          for (final member in service.body.members)
            if (member is MethodDeclaration) _signatureOf(member),
        ],
        [
          'AuthUser? get currentUser',
          'Stream<AuthUser?> get userChanges',
          'Future<void> signIn$credentials',
          'Future<void> signUp$credentials',
          'Future<void> linkPassword$credentials',
          'Future<void> signInWith(SignInCredential credential)',
          'Future<void> linkWith(SignInCredential credential)',
          'Future<void> signInAnonymously()',
          'Future<void> sendPasswordReset(String email)',
          'Future<void> signOut()',
          'Future<void> deleteAccount({SignInCredential? fresh})',
        ],
      );
      expect(_enumValuesOf(unit, 'AuthFailureReason'), [
        'invalidCredentials',
        'emailInUse',
        'credentialInUse',
        'accountExistsWithOtherMethod',
        'weakPassword',
        'invalidEmail',
        'userDisabled',
        'tooManyAttempts',
        'network',
        'recentSignInRequired',
        'notConfigured',
        'unknown',
      ]);
      ClassDeclaration classOf(String name) => unit.declarations
          .whereType<ClassDeclaration>()
          .singleWhere((type) => type.namePart.typeName.lexeme == name);
      String fieldsOf(String name) => [
            for (final member in classOf(name).body.members)
              if (member is FieldDeclaration) '${member.fields}',
          ].join('; ');
      // A credential is one of a closed set, which a provider tells apart.
      expect(classOf('SignInCredential').sealedKeyword, isNotNull);
      expect(
        '${classOf('IdTokenCredential').extendsClause}',
        'extends SignInCredential',
      );
      expect(
        fieldsOf('IdTokenCredential'),
        'final String issuer; final String idToken; final String? rawNonce; '
        'final String? authorizationCode; final String? givenName; '
        'final String? familyName',
      );
      expect(
        fieldsOf('AuthUser'),
        'final String uid; final bool isAnonymous; final String? email; '
        'final Set<String> issuers',
      );
      // The file of the provider needs nothing of Flutter and no other
      // file of the app.
      expect(unit.directives, isEmpty);
    });

    test(
        'writes the mode of the app into the file of the session as the '
        'constant authMode, whose type has the modes of the option', () async {
      for (final mode in AuthMode.values) {
        final unit = parseString(
          content: (await _rendered(mode: mode)).files[AuthRole.sessionFile]!,
        ).unit;

        expect(
          _variablesOf(unit)['authMode'],
          'const AuthMode authMode = AuthMode.${mode.name};',
        );
        expect(
          _enumValuesOf(unit, 'AuthMode'),
          AuthRole.modeOption.allowed,
        );
      }
    });

    for (final async in [true, false]) {
      final how = async ? 'created asynchronously' : 'created with the app';

      test(
          'creates an implementation $how in initAuth(), starts the session '
          'with it, and awaits that in the platform phase of bootstrap()',
          () async {
        final rendered = await _rendered(async: async);
        final code = rendered.files[AuthRole.sessionFile]!;
        final unit = parseString(content: code).unit;

        final init = _functionsOf(unit)['initAuth']!;
        expect('${init.returnType}', 'Future<void>');
        expect(init.functionExpression.parameters!.parameters, isEmpty);
        expect(_statementsOf(init), [
          if (async)
            '_authService = await impl0.openFakeAuth();'
          else
            '_authService = impl0.createFakeAuth();',
          'await appSession.start(_authService);',
        ]);
        // Not final: initAuth() may run again.
        expect(
          _variablesOf(unit)['_authService'],
          'late AuthService _authService;',
        );
        final factory = _functionsOf(unit)['createAuthService']!;
        expect('${factory.returnType}', 'AuthService');
        final body = factory.functionExpression.body as ExpressionFunctionBody;
        expect('${body.expression}', '_authService');
        expect(
          code,
          contains("import 'package:my_app/fakes/fake_auth.dart' as impl0;"),
        );
        // The start-up, with any provider: the session starts in it.
        final start = rendered.elsewhere.singleWhere(
          (entry) => entry.socket == AppEntryRole.bootstrapPlatform,
        );
        expect(start.fragment!.code, 'await initAuth();');
        expect(start.fragment!.imports, [_sessionImport]);
      });
    }

    test(
        'reports the problems of the implementation, and a function of it '
        'that its file lacks', () {
      final issues = authRole.template.validate(
        inputOf(
          authRole,
          data: [
            dataOf(
              authRole,
              const AuthImplementation(
                type: TypeRef('_Private'),
                create: FactoryRef('create', import: _fakeFile),
              ),
              module: 'fake_auth',
            ),
          ],
        ),
      );
      expect(issues.single.origin, const ModuleOrigin(ModuleId('fake_auth')));

      final missing = authRole.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: [
              dataOf(
                authRole,
                _implementation(async: false),
                module: 'fake_auth',
              ),
            ],
            presentRoles: {authRole},
            context: testContext,
          ),
          files: const {
            'lib/fakes/fake_auth.dart':
                DartFileIndex(path: 'lib/fakes/fake_auth.dart'),
          },
        ),
      );
      expect(
        missing.single.message,
        contains('does not declare function createFakeAuth()'),
      );
    });
  });

  group('the generated session', () {
    for (final mode in AuthMode.values) {
      group('of an app in the mode ${mode.name}', () {
        late DartFiles app;

        setUpAll(() async => app = await _app(mode: mode));

        tearDownAll(() => app.delete());

        test('is code that type-checks', () async {
          expect(await app.analysisProblems(), isEmpty);
        });

        test(
            'knows the user when initAuth() completes, at a first launch '
            'and at the next one, and follows sign-up, sign-out, sign-in '
            'and the deletion of the account, with allowsApp and '
            'hasAccount as the mode says', () async {
          expect(await app.run('$_notes$_life'), _lifeIn(mode));
        });
      });
    }

    test('type-checks and starts with an implementation created asynchronously',
        () async {
      final app = await _app(async: true);
      addTearDown(app.delete);

      expect(await app.analysisProblems(), isEmpty);
      expect(await app.run('$_notes$_life'), _lifeIn(AuthMode.required));
    });

    group('with a provider that a test scripts', () {
      late DartFiles app;

      setUpAll(() async => app = await _app());

      tearDownAll(() => app.delete());

      test(
          'fails only with an AuthFailure: one of the provider as it is, '
          'and any other error as unknown with the error as its hint; and '
          'has the user of the provider after a failure too', () async {
        const hint = 'Bad state: The plugin broke in';
        // A failure keeps the stack trace of what the provider threw, also
        // when the session made it from another error.
        String thrown(String failure) => '$failure, thrown in fake_auth.dart';
        expect(await app.run('$_notes$_failures'), {
          'a failure of the provider': {
            for (final reason in [
              'invalidCredentials',
              'emailInUse',
              'credentialInUse',
              'accountExistsWithOtherMethod',
              'weakPassword',
              'invalidEmail',
              'userDisabled',
              'tooManyAttempts',
              'network',
              'recentSignInRequired',
            ])
              reason: thrown('$reason, hint null'),
            'notConfigured': thrown('notConfigured, hint Enable it.'),
            'unknown': thrown('unknown, hint null'),
          },
          'an error of another kind': {
            for (final call in [
              'signIn',
              'signUp',
              'signInWith',
              'sendPasswordReset',
              'signOut',
              'deleteAccount',
            ])
              call: thrown('unknown, hint $hint $call.'),
            'an object that is no error':
                thrown('unknown, hint A text that was thrown.'),
          },
          // No failure changed the user.
          'the session after the failures': {
            'state': 'account user-1 $_email',
            'heard': <Object?>[],
          },
          // The session takes the user of the provider when a call is
          // over, also when no event tells of the change.
          'a call for a user whose session has ended': {
            'failure': thrown('recentSignInRequired, hint null'),
            'state': 'signed out',
            'heard': ['signed out'],
          },
          'a failure as text': [
            'AuthFailure: network',
            'AuthFailure: notConfigured (Enable it.)',
          ],
        });
      });

      test(
          'follows the changes of the user that no call made, tells its '
          'listeners only of a change and only while they listen, follows '
          'only the service of the last start, and reports an error that '
          'comes where a change is told of', () async {
        expect(await app.run('$_notes$_changes'), {
          'a change that no call made': {
            'state': 'account remote remote@example.com',
            'heard': ['account remote remote@example.com'],
          },
          'an event for the same user': {
            'state': 'account remote remote@example.com',
            'heard': <Object?>[],
          },
          'a sign-out that no call made': {
            'state': 'signed out',
            'heard': ['signed out'],
          },
          // The session has the user of the new service when start()
          // completes.
          'a start with another service': {
            'state': 'anonymous other',
            'heard': ['anonymous other'],
          },
          'a change of the service before': {
            'state': 'anonymous other',
            'heard': <Object?>[],
          },
          'the service before is listened to': false,
          'a change of the service of the start': {
            'state': 'account remote remote@example.com',
            'heard': ['account remote remote@example.com'],
          },
          // The session reports the error as an error of the app, keeps
          // its user, and goes on listening.
          'an error where a change is told of': {
            'state': 'account remote remote@example.com',
            'heard': <Object?>[],
          },
          'reported': [
            {
              'exception': 'Bad state: The stream broke.',
              'has a stack trace': true,
              'library': 'app session',
              'context': 'while following the user of the provider of '
                  'sign-in',
            },
          ],
          'a change after the error': {
            'state': 'signed out',
            'heard': ['signed out'],
          },
          'the listeners of the flags': {
            'told of a change': 2,
            'told once they are removed': 0,
          },
          'sessions compare by value': {
            'signed out': true,
            'the same anonymous user': true,
            'another anonymous user': false,
            'the same account': true,
            'another address of the account': false,
            'an account and an anonymous user of one id': false,
            'the same issuers of the account, in another order': true,
            'other issuers of the account': false,
            'an issuer of the account more': false,
            'as keys': 4,
          },
        });
      });

      test(
          'keeps the calls made before its first start until it has the '
          'user, runs its calls one after another in their order, and '
          'completes the start after those made before it, also after one '
          'that fails', () async {
        Map<String, Object?> expected(AuthMode mode) {
          final anonymous = mode == AuthMode.anonymous;
          final signUp = anonymous ? 'linkPassword $_email' : 'signUp $_email';
          const refused =
              'invalidCredentials, hint null, thrown in fake_auth.dart';
          return {
            'before the start': {
              'calls': <Object?>[],
              'state': 'signed out',
            },
            // The anonymous mode has its user before the calls run, so
            // sign-up gives that user the account.
            'while the first call is on its way': {
              'calls': [if (anonymous) 'signInAnonymously', signUp],
              'the calls that are done': <Object?>[],
              'the start is done': false,
            },
            'after the start': {
              'calls': ['signIn $_email', 'sendPasswordReset $_email'],
              'the calls that are done': [
                'sign-up',
                'sign-in: $refused',
                'reset',
              ],
              // Each session has a user of its own.
              'state': 'account user-${mode.index + 1} $_email',
            },
            'a call after the start': ['signOut'],
            // In the anonymous mode, the sign-out is over once the app has
            // its anonymous user again.
            'the call after it': [
              if (anonymous) 'signInAnonymously',
              'sendPasswordReset $_email',
            ],
            'a third call while the second is on its way': <Object?>[],
            'the third call': ['sendPasswordReset later@example.com'],
          };
        }

        expect(await app.run('$_notes$_earlyCalls'), {
          for (final mode in AuthMode.values) mode.name: expected(mode),
        });
      });

      test(
          'makes a call that waits for no other, and a later start, wait '
          'for nothing that another zone has to run: a test in fake time '
          'calls it after the app started in real time', () async {
        expect(await app.run('$_notes$_otherZone'), {
          'a call': {
            'calls': ['signOut'],
            'the call is done': true,
            'state': 'signed out',
          },
          'a start is done': true,
        });
      });

      test(
          'in the anonymous mode, waits for its anonymous user only as long '
          'as it is told, starts without a user when the sign-in fails or '
          'takes longer, tries again when the user comes back to the app, '
          'after a sign-out or a deletion and after a call that leaves '
          'nobody signed in, and runs neither a call nor a later start next '
          'to an anonymous sign-in', () async {
        const failed = 'The anonymous sign-in failed, so the app has no '
            'user: AuthFailure: notConfigured (Enable anonymous sign-in.)';
        const noNetwork = 'The anonymous sign-in failed, so the app has no '
            'user: Bad state: No network.';
        Map<String, Object?> note(
          String state, {
          List<String> calls = const [],
          List<String> printed = const [],
        }) =>
            {'state': state, 'calls': calls, 'printed': printed};

        expect(await app.run('$_notes$_anonymous'), {
          'while the app waits for its anonymous user': {
            'the start is done': false,
            'calls': ['signInAnonymously'],
          },
          'a sign-in that takes longer than the wait': note(
            'signed out',
            calls: ['signInAnonymously'],
          ),
          // No second sign-in next to the one that is on its way.
          'the user comes back while it is on its way': note('signed out'),
          'when it comes': note('anonymous user-1'),
          'the user comes back to an app with a user': note('anonymous user-1'),
          'after dispose': {
            'observers of the lifecycle': 0,
            'the service is listened to': false,
          },
          'a sign-in that comes within the wait': note(
            'anonymous user-2',
            calls: ['signInAnonymously'],
          ),
          // The start does not wait for a sign-in that failed, and in
          // debug mode the developer of the app sees why.
          'a sign-in that fails': note(
            'signed out',
            calls: ['signInAnonymously'],
            printed: [failed],
          ),
          'the user comes back, and it fails again': note(
            'signed out',
            calls: ['signInAnonymously'],
            printed: [failed],
          ),
          'the user comes back, and it works': note(
            'anonymous user-3',
            calls: ['signInAnonymously'],
          ),
          // The user is signed out, so the call completes.
          'a sign-out, after which it fails': note(
            'signed out',
            calls: ['signOut', 'signInAnonymously'],
            printed: [noNetwork],
          ),
          'the deletion of the account': note(
            'anonymous user-4',
            calls: ['deleteAccount', 'signInAnonymously'],
          ),
          'the deletion of an anonymous user': note(
            'anonymous user-5',
            calls: ['deleteAccount', 'signInAnonymously'],
          ),
          'starts while an anonymous sign-in is on its way': {
            // Five starts, and one sign-in of each of the two services.
            'the sign-ins of the starts': [
              'signInAnonymously',
              'signInAnonymously',
            ],
            'calls once the first has come': <Object?>[],
            'the user': 'anonymous user-7',
          },
          // The sign-up finds the anonymous user, who gets the account:
          // next to the sign-in, it would have made a second user, and the
          // one of the two that came last would be the user.
          'a call while the anonymous sign-in is on its way': {
            'calls': <Object?>[],
            'the call is done': false,
          },
          'the call, once the sign-in is over': note(
            'account user-8 $_email',
            calls: ['linkPassword $_email'],
          ),
          // No anonymous sign-in next to the sign-in, and none after it
          // for a user with an account.
          'the user comes back while a sign-in works': {
            'calls while it is on its way': ['signIn $_email'],
            'it': 'none',
            ...note('account user-8 $_email'),
          },
          'the user comes back while a sign-in fails': {
            'calls while it is on its way': ['signIn $_email'],
            'it': 'invalidCredentials, hint null, thrown in fake_auth.dart',
            ...note('anonymous user-9', calls: ['signInAnonymously']),
          },
          for (final mode in ['required', 'guest'])
            'in the mode $mode': {
              ...note('signed out', calls: ['signOut']),
              'observers of the lifecycle': 0,
            },
          // The wait is the one of the session. The start is over when it
          // is, although the try of the user who came back still waits for
          // the sign-in that is on its way.
          'the user comes back while the first start waits': {
            'the waits': ['0:07:00.000000'],
            'the start is done before the wait is over': false,
            'the start is done once it is over': true,
            ...note('signed out', calls: ['signInAnonymously']),
          },
          'once the sign-in of that start has come': note('anonymous user-10'),
          'a call that fails and leaves nobody signed in': {
            'it': 'recentSignInRequired, hint null, thrown in fake_auth.dart',
            ...note(
              'signed out',
              calls: ['linkPassword carol@example.com', 'signInAnonymously'],
            ),
          },
          // The new anonymous user gets the account.
          'the same call again': note(
            'account user-12 carol@example.com',
            calls: ['linkPassword carol@example.com'],
          ),
          'a start while a sign-in is on its way': {
            'while it is on its way': {
              'calls': ['signIn $_email'],
              'the start is done': false,
            },
            'the start is done': true,
            ...note('account user-8 $_email'),
          },
          'the app is paused and then resumed': {
            'calls while it is paused': <Object?>[],
            ...note('anonymous user-13', calls: ['signInAnonymously']),
          },
          'a call that ends after dispose': {
            'it': 'none',
            'calls': ['signOut'],
          },
          'two starts at once': note(
            'signed out',
            calls: ['signInAnonymously'],
          ),
          // The sign-in is on its way, with its wait, and the call is over.
          'a call that works and leaves nobody signed in': {
            'the call is done': true,
            'the waits': ['0:07:00.000000'],
            ...note(
              'signed out',
              calls: ['sendPasswordReset $_email', 'signInAnonymously'],
            ),
          },
        });
      });

      test(
          'takes the data of an anonymous user before it signs in to an '
          'account, and gives it once the user of the account is signed '
          'in; fails when taking fails, and reports when giving fails',
          () async {
        Map<String, Object?> note(
          String state,
          List<String> calls, [
          String? failure,
        ]) =>
            {
              'calls': calls,
              'state': state,
              if (failure != null) 'failure': failure,
            };
        const owner = 'account owner $_email';

        expect(await app.run('$_notes$_guestData'), {
          'an anonymous user signs in': note(
            owner,
            ['take user-1', 'signIn $_email', 'give owner'],
          ),
          'the user of an account signs in': note(owner, ['signIn $_email']),
          'with nothing to move': note(
            owner,
            ['take user-2', 'signIn $_email'],
          ),
          // The provider is not called, and the guest stays.
          'taking fails': note(
            'anonymous user-3',
            ['take user-3'],
            'unknown, hint Bad state: The cart does not load., thrown in '
                'check.dart',
          ),
          // Nothing is given to an account that the user is not in.
          'the sign-in fails': note(
            'anonymous user-3',
            ['take user-3', 'signIn $_email'],
            'invalidCredentials, hint null, thrown in fake_auth.dart',
          ),
          // The user is signed in, so the call completes.
          'giving fails': note(
            owner,
            ['take user-3', 'signIn $_email', 'give owner'],
            'none',
          ),
          'reported': [
            {
              'exception': 'Bad state: The cart does not save.',
              'has a stack trace': true,
              'library': 'app session',
              'context': 'while giving the data of a guest to the account',
            },
          ],
          'an anonymous user signs up': note(
            'account user-4 bob@example.com',
            ['linkPassword bob@example.com'],
          ),
          'the account has the id of the guest': note(
            'account user-5 same@example.com',
            ['take user-5', 'signIn same@example.com'],
          ),
          'a user who is not signed in signs in': note(
            owner,
            ['signIn $_email'],
          ),
          for (final mode in ['guest', 'required'])
            'an anonymous user in the mode $mode': {
              'signs up': note(
                'account restored-$mode $mode@example.com',
                ['linkPassword $mode@example.com'],
              ),
              'signs in': note(
                owner,
                ['take other-$mode', 'signIn $_email', 'give owner'],
              ),
            },
          'the function of the app has nothing to move': true,
        });
      });
    });
  });

  group('the note of the auth role for coding agents', () {
    test(
        'is a note of the role in the section of the role of every app with '
        'it, and names what the four files declare', () async {
      final rendered = await _rendered();
      final note = agentNoteOf(authRole);

      expect(rendered.notes.single.entryKey, authRole.description);
      expect(rendered.notes.single.entryValue, note);
      expect(note.isOfRole, isTrue);
      expectNamesOfCode(
        note,
        {
          AuthRole.sessionFile: [
            'appSession',
            'AppSessionController',
            'AppSessionController.value',
            'AppSessionController.allowsApp',
            'AppSessionController.hasAccount',
            'AppSession.uid',
            'SignedOutSession',
            'AnonymousSession',
            'AccountSession',
            'authMode',
            'initAuth',
            'createAuthService',
            'AppSessionController.signInWith',
            'AppSessionController.deleteAccount',
            'AccountSession.issuers',
            'AccountSession.email',
          ],
          AuthRole.serviceFile: [
            'AuthService',
            'AuthFailure',
            'AuthFailure.reason',
            'AuthFailure.developerHint',
            'AuthFailureReason',
            'AuthFailureReason.recentSignInRequired',
            'SignInCredential',
            'IdTokenCredential',
          ],
          AuthRole.guestDataFile: ['takeGuestData'],
          AuthRole.methodsFile: [
            'appSignInMethods',
            'SignInMethod',
            'SignInMethod.isAvailable',
            'SignInMethod.label',
            'SignInMethod.icon',
            'SignInMethod.credential',
            'SignInMethod.issuer',
            'SignInMethod.revokesOnDeletion',
          ],
        },
        files: rendered.files,
      );
      // The files that it names are those of the role, which every app
      // with the role has.
      expect(
        {
          for (final span in codeSpansOf(note.text))
            if (span.contains('/')) span,
        },
        authRole.interface.files.toSet(),
      );
    });

    test(
        'tells to import the file of the session alone, which exports the '
        'failure and its reasons and the credentials, as the rule of the '
        'role asks', () async {
      final unit = parseString(
        content: (await _rendered()).files[AuthRole.sessionFile]!,
      ).unit;

      expect(
        unit.directives.whereType<ExportDirective>().single.toSource(),
        "export 'auth_service.dart' show AuthFailure, AuthFailureReason, "
        'IdTokenCredential, SignInCredential;',
      );
      expect(
        agentNoteOf(authRole).text,
        contains(
          'The code of the app imports `${AuthRole.sessionFile}`, which '
          'exports `AuthFailure`, `AuthFailureReason`, `SignInCredential` '
          'and `IdTokenCredential`',
        ),
      );
    });
  });

  group('the section of the auth role in the README of the app', () {
    /// The section of [app], under the heading of the role.
    String sectionOf(RenderedTemplate app) {
      final section = app.elsewhere.singleWhere(
        (entry) => entry.socket == AppEntryRole.readmeSections,
      );
      expect(section.entryKey, AuthRole.readmeHeading);
      expect(AppEntryRole.readmeSections.problemsWith(section), isEmpty);
      return section.entryValue! as String;
    }

    test(
        'comes from the render hook, since it tells the mode of the app and '
        'where that is written, and is the same text otherwise', () async {
      expect(AuthRole.readmeHeading, 'Sign-in');
      // No contribution of the template: those are the same in every mode.
      expect(
        authRole.template.contribute(testContext).where(
              (contribution) =>
                  contribution is SocketContribution &&
                  contribution.socket == AppEntryRole.readmeSections,
            ),
        isEmpty,
      );
      final sections = <AuthMode, String>{};
      for (final mode in AuthMode.values) {
        final rendered = await _rendered(mode: mode);
        final section = sections[mode] = sectionOf(rendered);

        // The mode as the file of the session has it.
        final ofApp = 'This app was generated in the mode `${mode.name}`: '
            '`authMode` in `${AuthRole.sessionFile}` is '
            '`AuthMode.${mode.name}`.';
        expect(section, contains(ofApp));
        expect(
          rendered.files[AuthRole.sessionFile],
          contains('const AuthMode authMode = AuthMode.${mode.name};'),
        );
        // What each mode means, in every app.
        for (final other in AuthMode.values) {
          expect(section, contains('- In `${other.name}`, '));
        }
        expect(
          section.replaceFirst(ofApp, ''),
          sections[AuthMode.values.first]!.replaceFirst(
            RegExp(r'This app was generated in the mode [^\n]*'),
            '',
          ),
        );
      }
    });

    test(
        'names what the files of the role declare, no file but theirs, and '
        'the wait for an anonymous user that the session has', () async {
      final rendered = await _rendered(mode: AuthMode.anonymous);
      final section = sectionOf(rendered);

      expectNamesOfCodeIn(
        section,
        {
          AuthRole.sessionFile: [
            'authMode',
            'AuthMode.required',
            'AuthMode.guest',
            'AuthMode.anonymous',
            'appSession',
            'AppSessionController.value',
            'AppSessionController.allowsApp',
            'AppSessionController.hasAccount',
            'AppSession.uid',
          ],
          AuthRole.guestDataFile: ['takeGuestData'],
          AuthRole.methodsFile: ['appSignInMethods', 'SignInMethod'],
        },
        files: rendered.files,
      );
      expect(
        {
          for (final span in codeSpansOf(section))
            if (span.contains('/')) span,
        },
        {AuthRole.sessionFile, AuthRole.guestDataFile, AuthRole.methodsFile},
      );
      final wait = RegExp(r'anonymousWait = const Duration\(seconds: (\d+)\)')
          .firstMatch(rendered.files[AuthRole.sessionFile]!)![1];
      expect(section, contains('The app waits up to $wait seconds'));
    });

    test(
        'tells in every mode which guard keeps a user from the whole app '
        'and which only from the screens that need an account, and that '
        'such a screen is open too in an app without a guard for it', () async {
      for (final mode in AuthMode.values) {
        final section = sectionOf(await _rendered(mode: mode));

        expect(
          section,
          contains(
            'One that reads `appSession.allowsApp` stands before the whole '
            'app. One that reads `appSession.hasAccount` stands only before '
            'the routes that it lists, the screens that need an account.',
          ),
        );
        expect(
          section,
          contains(
            'A screen that a module made for users with an account is open '
            'then too. A warning named each such route when the app was '
            'generated, and a guard of your own for them reads '
            '`appSession.hasAccount`.',
          ),
        );
      }
    });
  });

  group('the rules of the auth role', () {
    const session = 'package:my_app/core/auth/app_session.dart';
    const service = 'package:my_app/core/auth/auth_service.dart';
    const providerFile = 'lib/core/auth/fake_auth_service.dart';
    const screen = 'lib/features/profile/profile_screen.dart';
    const ofProvider = ModuleOrigin(ModuleId('fake_auth'));
    const ofFeature = ModuleOrigin(ModuleId('profile'));

    test(
        'let each provider contribute one implementation, and no module '
        'put code into the socket of the implementation', () {
      List<SmfIssue> issuesOf(
        ModuleDescriptor module, {
        List<AuthData> implementations = const [],
        List<Contribution> contributions = const [],
      }) =>
          authRole.checkModule(
            ModuleRuleRequest(
              hook: RoleHookRequest(
                data: [
                  for (final implementation in implementations)
                    authRole
                        .data(implementation)
                        .withOrigin(ModuleOrigin(module.id)),
                ],
                presentRoles: {authRole},
                context: testContext,
              ),
              module: module,
              contributions: contributions,
            ),
          );
      final implementation = _implementation(async: false);

      expect(issuesOf(_provider, implementations: [implementation]), isEmpty);
      expect(issuesOf(_feature), isEmpty);
      expect(
        issuesOf(_provider).single.message,
        contains('exactly one implementation, but the module contributes 0'),
      );
      expect(
        issuesOf(_feature, implementations: [implementation]).single.message,
        contains('which only its providers do'),
      );
      final issue = issuesOf(
        _provider,
        implementations: [implementation],
        contributions: const [
          SocketContribution.code(
            AuthRole.implementations,
            Fragment('late AuthService _authService;'),
          ),
        ],
      ).single;
      expect(issue.message, contains('socket auth.implementations'));
      expect(issue.hint, contains('RoleImplementation'));
    });

    test(
        'auth.factory_calls: no module calls createAuthService(), the '
        'provider neither; a file of a module, or of the template of '
        'another role, that calls it is reported, with the session as what '
        'to use', () {
      final issues = _structureIssues({
        _calling(providerFile, 'createAuthService'): ofProvider,
        _calling(screen, 'createAuthService'): ofFeature,
        _calling('lib/core/account/account.dart', 'createAuthService'):
            RoleTemplateOrigin(_otherRole),
        // Another file of the template of the role itself, and files that
        // neither a module nor the template of a role owns.
        _calling('lib/core/auth/more.dart', 'createAuthService'):
            const RoleTemplateOrigin(authRole),
        _calling('lib/generated.dart', 'createAuthService'):
            const PipelineOrigin(),
        _calling('lib/mine.dart', 'createAuthService'): null,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (providerFile, ofProvider),
          (screen, ofFeature),
          ('lib/core/account/account.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls createAuthService(), which no module may '
          'call.',
        );
        expect(
          issue.hint,
          'Sign in, up and out through appSession of '
          'lib/core/auth/app_session.dart, which also exports AuthFailure '
          'and AuthFailureReason.',
        );
      }
    });

    test(
        'auth.factory_calls: the file of AuthService is for the files of '
        'the implementation of the provider, those of its class and of its '
        'function; any other file of a module that imports or exports it, '
        'in whichever way, is reported, a widget of the provider too', () {
      const widget = DartFileIndex(
        path: 'lib/core/auth/fake_auth_widget.dart',
        imports: [IndexedImport('auth_service.dart')],
      );
      const relative = DartFileIndex(
        path: screen,
        imports: [IndexedImport('../../core/auth/auth_service.dart')],
      );
      const prefixed = DartFileIndex(
        path: 'lib/features/profile/profile_state.dart',
        imports: [
          IndexedImport(service, prefix: 'auth', show: ['AuthService']),
        ],
      );
      const exported = DartFileIndex(
        path: 'lib/features/profile/profile.dart',
        exports: [IndexedImport(service)],
      );
      // The file of the function of the implementation imports it too, in
      // every app of these tests.
      expect(_factoryFile.imports.single.uri, 'auth_service.dart');
      final issues = _structureIssues({
        const DartFileIndex(
          path: providerFile,
          imports: [IndexedImport('auth_service.dart')],
        ): ofProvider,
        widget: ofProvider,
        relative: ofFeature,
        prefixed: ofFeature,
        exported: ofFeature,
        // The file of the session, which the code of an app imports, and a
        // file of the same name of another directory.
        const DartFileIndex(
          path: 'lib/features/profile/profile_cubit.dart',
          imports: [
            IndexedImport(session),
            IndexedImport('auth_service.dart'),
          ],
        ): ofFeature,
        // The file of the session itself imports it, and a file that no
        // module owns may.
        const DartFileIndex(
          path: AuthRole.sessionFile,
          imports: [IndexedImport('auth_service.dart')],
        ): const RoleTemplateOrigin(authRole),
        const DartFileIndex(
          path: 'lib/mine.dart',
          imports: [IndexedImport(service)],
        ): null,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (widget.path, ofProvider),
          (relative.path, ofFeature),
          (prefixed.path, ofFeature),
          (exported.path, ofFeature),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} imports lib/core/auth/auth_service.dart, the file '
          'of AuthService, which only the files of the implementation of '
          'the provider of the authentication role import.',
        );
        expect(issue.hint, contains('appSession'));
      }
    });

    test(
        'auth.start_calls: initAuth() is for bootstrap(); any other file of '
        'the app that calls it is reported, the file of the provider too', () {
      final issues = _structureIssues({
        _calling(AppEntryRole.bootstrapFile, 'initAuth'):
            const ModuleOrigin(ModuleId('flutter_core')),
        _calling(providerFile, 'initAuth'): ofProvider,
        _calling(screen, 'initAuth'): ofFeature,
        _calling('lib/core/account/account.dart', 'initAuth'):
            RoleTemplateOrigin(_otherRole),
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (providerFile, ofProvider),
          (screen, ofFeature),
          ('lib/core/account/account.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls initAuth(), which only bootstrap() calls.',
        );
        expect(issue.hint, contains('appSession'));
      }
    });

    test(
        'auth.start_calls: appSession.start() is for initAuth(); a file of '
        'a module, or of the template of another role, that calls it is '
        'reported, also through the prefix of its import of the session', () {
      /// The index of the file at [path] that imports the file of the
      /// session, with [prefix] or without one, and calls `start` on
      /// [target].
      DartFileIndex starting(String path, String target, {String? prefix}) =>
          DartFileIndex(
            path: path,
            imports: [IndexedImport(session, prefix: prefix)],
            invocations: [IndexedInvocation('start', target: target)],
          );
      const prefixedScreen = 'lib/features/profile/profile_state.dart';
      final issues = _structureIssues({
        starting(providerFile, 'appSession'): ofProvider,
        starting(screen, 'appSession'): ofFeature,
        starting(prefixedScreen, 'auth.appSession', prefix: 'auth'): ofFeature,
        starting('lib/core/account/account.dart', 'appSession'):
            RoleTemplateOrigin(_otherRole),
        // The file of the role itself, which starts the session in
        // initAuth(), and a file that no module owns.
        starting('lib/core/auth/more.dart', 'appSession'):
            const RoleTemplateOrigin(authRole),
        starting('lib/mine.dart', 'appSession'): null,
        // Another object that is started, the session of an import with a
        // prefix under its plain name, and an `appSession` of a file that
        // does not import the file of the session.
        starting('lib/features/profile/a.dart', 'controller'): ofFeature,
        starting('lib/features/profile/b.dart', 'appSession', prefix: 'auth'):
            ofFeature,
        const DartFileIndex(
          path: 'lib/features/profile/c.dart',
          imports: [IndexedImport('profile_session.dart')],
          invocations: [IndexedInvocation('start', target: 'appSession')],
        ): ofFeature,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (providerFile, ofProvider),
          (screen, ofFeature),
          (prefixedScreen, ofFeature),
          ('lib/core/account/account.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls appSession.start(), which only initAuth() '
          'calls.',
        );
        expect(
          issue.hint,
          'The role starts the session in bootstrap(), before the first '
          'frame. Read who is signed in from appSession.',
        );
      }
    });

    test(
        'take a function of the same name of another file for none of the '
        'role, and the session for what the code of an app may use', () {
      expect(
        _structureIssues({
          for (final function in ['createAuthService', 'initAuth'])
            DartFileIndex(
              path: 'lib/features/profile/$function.dart',
              imports: const [IndexedImport('profile_auth.dart')],
              invocations: [IndexedInvocation(function)],
            ): ofFeature,
          // What a screen of a feature does with the session.
          const DartFileIndex(
            path: screen,
            imports: [IndexedImport(session)],
            invocations: [
              IndexedInvocation('signIn', target: 'appSession'),
              IndexedInvocation('AuthFailure'),
            ],
            references: [IndexedReference('appSession')],
            memberAccesses: [IndexedMemberAccess('appSession', 'allowsApp')],
          ): ofFeature,
        }),
        isEmpty,
      );
    });
  });

  group('the data of the auth role', () {
    test(
        'has the implementation of the provider, created with the app or '
        'asynchronously', () {
      final sync = _implementation(async: false);
      final async = _implementation(async: true);

      expect(sync.implementation.isAsync, isFalse);
      expect(sync.implementation.type, sync.type);
      expect(sync.implementation.factory.name, 'createFakeAuth');
      expect(async.implementation.isAsync, isTrue);
      expect(async.implementation.factory.name, 'openFakeAuth');
      expect('$sync', 'implementation FakeAuth');
      expect('${sync.implementation}', '$sync');
    });

    test(
        'has ways to sign in, each with its label as the text that a user '
        'sees, which ask for nothing of a backend and do not revoke unless '
        'they say so', () {
      final method = _method();

      expect(method.shownTexts, [method.label]);
      expect(method.needs, isEmpty);
      expect(method.revokesOnDeletion, isFalse);
      expect(method.problems(), isEmpty);
      expect('$method', 'way to sign in of https://id.example.com');
      expect(AppPlatform.values, [AppPlatform.android, AppPlatform.ios]);
      expect(
        AppStoreLogin.values,
        [AppStoreLogin.thirdParty, AppStoreLogin.privacyFocused],
      );
      expect(SignInNeed.values, [
        SignInNeed.androidCertificate,
        SignInNeed.iosClient,
        SignInNeed.serverClient,
      ]);
    });

    test(
        'takes an issuer that is an https URL without a query or a fragment, '
        'as an identity provider writes it into its tokens', () {
      for (final issuer in [
        'https://id.example.com',
        'https://id.example.com/',
        'https://login.example.com/tenant/v2.0',
      ]) {
        expect(_method(issuer: issuer).problems(), isEmpty, reason: issuer);
      }
      for (final issuer in [
        'http://id.example.com',
        'id.example.com',
        'https://',
        'https://id.example.com?tenant=1',
        'https://id.example.com#top',
        '',
      ]) {
        expect(
          _method(issuer: issuer).problems().single,
          'The issuer "$issuer" of a way to sign in must be an https URL '
          'without a query or a fragment, such as '
          'https://accounts.example.com, as the identity provider writes it '
          'into its tokens.',
          reason: issuer,
        );
      }
    });

    test(
        'reports an icon that is no expression, a way to sign in on no '
        'platform, and a function that is no public function of the app', () {
      final problems = const SignInMethod(
        label: LocalizedText('label', en: 'Continue with Example'),
        icon: Fragment.wrap('Center(child: ', ')'),
        platforms: {},
        credential: FunctionRef(
          '_credential',
          import: ImportRef('package:example/example.dart'),
        ),
        issuer: _issuer,
        appStore: AppStoreLogin.thirdParty,
      ).problems();

      const noExpression = 'The way to sign in of https://id.example.com has '
          'an icon that is not an expression, such as Icon(Icons.key).';
      const noPlatform = 'The way to sign in of https://id.example.com names '
          'no platform that it works on.';
      const outside = 'The function _credential of the way to sign in of '
          'https://id.example.com must be a function of a file of the app, '
          'imported with ImportRef.app.';
      expect(problems, [
        noExpression,
        noPlatform,
        'The function "_credential" is not a public Dart function name.',
        outside,
      ]);
      expect(
        const SignInMethod(
          label: LocalizedText('label', en: 'Continue with Example'),
          icon: Fragment(
            ' ',
            imports: [ImportRef('package:flutter/material.dart', prefix: '1')],
          ),
          platforms: {AppPlatform.ios},
          credential: FunctionRef('credential', import: _methodFile),
          issuer: _issuer,
          appStore: AppStoreLogin.privacyFocused,
        ).problems(),
        [
          noExpression,
          ...const ImportRef('package:flutter/material.dart', prefix: '1')
              .problems(),
        ],
      );
    });
  });

  group('AuthRole.methodsIn', () {
    test(
        'has the ways to sign in in the order of the data, each with its '
        'module, also one of a variant of the module', () {
      final input = inputOf(
        authRole,
        data: [
          dataOf(authRole, _implementation(async: false), module: 'fake_auth'),
          dataOf(authRole, _method(), module: 'example_sign_in'),
          authRole
              .data(_method(issuer: 'https://other.example.com'))
              .withOrigin(
                const ModuleOrigin(
                  ModuleId('second'),
                  variant: ModuleId('bloc'),
                ),
              ),
        ],
      );
      final methods = authRole.methodsIn(input);

      expect(
        [for (final placed in methods) placed.method.issuer],
        [_issuer, 'https://other.example.com'],
      );
      expect(
        [for (final placed in methods) placed.owner],
        const [
          ModuleOrigin(ModuleId('example_sign_in')),
          ModuleOrigin(ModuleId('second')),
        ],
      );
      expect(
        '${methods.first}',
        'way to sign in of https://id.example.com of example_sign_in',
      );
    });

    test('is empty in an app without ways to sign in', () {
      expect(authRole.methodsIn(inputOf(authRole)), isEmpty);
    });

    test('reads the ways to sign in for a role that uses the auth role', () {
      final account = TestRole<NoDsl>('account_screens', uses: {authRole});
      final input = inputOf(
        account,
        data: [dataOf(authRole, _method(), module: 'example_sign_in')],
        present: {authRole},
      );

      expect(authRole.methodsIn(input).single.method.issuer, _issuer);
    });
  });

  group('the list of the ways to sign in', () {
    test(
        'is a constant list of SignInMethod, empty in an app without ways to '
        'sign in, whose class has what the role requires', () async {
      final code = (await _rendered()).files[AuthRole.methodsFile]!;
      final unit = parseString(content: code).unit;
      final list = unit.declarations
          .whereType<TopLevelVariableDeclaration>()
          .single
          .variables;

      expect('${list.type}', 'List<SignInMethod>');
      expect(list.isConst, isTrue);
      expect(list.variables.single.name.lexeme, AuthRole.appSignInMethods);
      expect(
        (list.variables.single.initializer! as ListLiteral).elements,
        isEmpty,
      );
      final declared = declarationsOf(code);
      for (final getter in AuthRole.signInMethod.getters) {
        expect(declared, contains('SignInMethod.$getter'));
      }
      final type = unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (type) => type.namePart.typeName.lexeme == 'SignInMethod',
          );
      final constructor =
          type.body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.constKeyword, isNotNull);
      expect(
        [
          for (final parameter in constructor.parameters.parameters)
            parameter.name!.lexeme,
        ],
        AuthRole.signInMethod.namedParameters,
      );
      // An app without ways to sign in type-checks too.
      final (ofApp, methods) = await _methodsOf(const []);
      expect(ofApp, code);
      expect(methods, isEmpty);
    });

    test(
        'has each way to sign in with a function of the file for its label, '
        'its icon, its platforms, its function through a prefix of the '
        'file of its function, its issuer and whether it revokes, in the '
        'order of the modules', () async {
      final (code, methods) = await _methodsOf([
        dataOf(
          authRole,
          _method(
            revokes: true,
            label: const LocalizedText('signInLabel', en: 'Continue'),
          ),
          module: 'example',
        ),
        dataOf(
          authRole,
          _method(
            issuer: 'https://ios.example.com',
            platforms: const {AppPlatform.ios},
            appStore: AppStoreLogin.thirdParty,
          ),
          module: 'example_sign_in',
        ),
        dataOf(
          authRole,
          const SignInMethod(
            label: LocalizedText('label', en: "Continue with 'Second'"),
            icon: Fragment('SecondIcon()', imports: [_secondFile]),
            platforms: {AppPlatform.ios, AppPlatform.android},
            credential: FunctionRef('secondCredential', import: _secondFile),
            issuer: 'https://second.example.com',
            appStore: AppStoreLogin.thirdParty,
          ),
          module: 'second_sign_in',
        ),
      ]);

      expect(_itemsOf(code), [
        {
          'label': '_exampleSignInLabel',
          'icon': 'FakeIcon()',
          'platforms': '{TargetPlatform.android, TargetPlatform.iOS}',
          'credential': 'method0.fakeCredential',
          'issuer': "'https://id.example.com'",
          'revokesOnDeletion': 'true',
        },
        // The id of the module continues in the name of the text of the
        // one before, so the name of its function takes a number.
        {
          'label': '_exampleSignInLabel2',
          'icon': 'FakeIcon()',
          'platforms': '{TargetPlatform.iOS}',
          'credential': 'method0.fakeCredential',
          'issuer': "'https://ios.example.com'",
        },
        {
          'label': '_secondSignInLabel',
          'icon': 'SecondIcon()',
          'platforms': '{TargetPlatform.android, TargetPlatform.iOS}',
          'credential': 'method1.secondCredential',
          'issuer': "'https://second.example.com'",
        },
      ]);
      expect(_importsOf(code), [
        'package:flutter/foundation.dart',
        'package:flutter/widgets.dart',
        'auth_service.dart',
        'package:my_app/fakes/fake_method.dart',
        'package:my_app/fakes/fake_method.dart method0',
        'package:my_app/fakes/second_method.dart',
        'package:my_app/fakes/second_method.dart method1',
      ]);
      // Without the texts of the app, each label is its English text.
      expect(methods, [
        {
          'label': 'Continue / Continue',
          'icon': 'FakeIcon',
          'platforms': ['android', 'iOS'],
          'issuer': 'https://id.example.com',
          'revokes': true,
          'on Android': true,
          'on iOS': true,
          'credential': 'IdTokenCredential(https://id.example.com)',
        },
        {
          'label': 'Continue with Example / Continue with Example',
          'icon': 'FakeIcon',
          'platforms': ['iOS'],
          'issuer': 'https://ios.example.com',
          'revokes': false,
          'on Android': false,
          'on iOS': true,
          'credential': 'IdTokenCredential(https://id.example.com)',
        },
        {
          'label': "Continue with 'Second' / Continue with 'Second'",
          'icon': 'SecondIcon',
          'platforms': ['android', 'iOS'],
          'issuer': 'https://second.example.com',
          'revokes': false,
          'on Android': true,
          'on iOS': true,
          'credential': 'IdTokenCredential(https://second.example.com)',
        },
      ]);
    });

    test(
        'reads a label from the texts of the app when the module of the way '
        'to sign in gave them the text, and is the English text otherwise',
        () async {
      const label = LocalizedText(
        'label',
        en: 'Continue with Example',
        translations: {'uk': 'Продовжити з Example'},
      );
      final (code, methods) = await _methodsOf(
        [
          dataOf(authRole, _method(label: label), module: 'example_sign_in'),
          dataOf(
            localizationRole,
            const TextsData([label]),
            module: 'example_sign_in',
          ),
          // A module that gave the texts of the app no text.
          dataOf(
            authRole,
            _method(issuer: 'https://other.example.com'),
            module: 'other_sign_in',
          ),
        ],
        present: {localizationRole},
        texts: _textsFile(['exampleSignInLabel']),
      );

      expect(
        [
          for (final method in methods! as List<Object?>)
            (method! as Map)['label'],
        ],
        [
          'en exampleSignInLabel / uk exampleSignInLabel',
          'Continue with Example / Continue with Example',
        ],
      );
      expect(code, contains("import 'package:my_app/core/l10n/l10n.dart';"));
    });

    test('refuses a label with problems, in every app', () {
      final broken = _method(label: const LocalizedText('Label', en: ''));
      for (final present in [
        <Role>{},
        {localizationRole},
      ]) {
        expect(
          () => authRole.template.render(
            inputOf(
              authRole,
              data: [
                dataOf(
                  authRole,
                  _implementation(async: false),
                  module: 'fake_auth',
                ),
                dataOf(authRole, broken, module: 'example_sign_in'),
              ],
              present: present,
              choice: AuthMode.required,
            ),
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('the template validates the ways to sign in', () {
    /// What the template reports for an app with [methods], each of a
    /// module of its own, `sign_in_0`, `sign_in_1` and so on.
    List<SmfIssue> issuesOf(List<SignInMethod> methods) =>
        authRole.template.validate(
          inputOf(
            authRole,
            data: [
              dataOf(
                authRole,
                _implementation(async: false),
                module: 'fake_auth',
              ),
              for (final (index, method) in methods.indexed)
                dataOf(authRole, method, module: 'sign_in_$index'),
            ],
          ),
        );
    SignInMethod thirdParty(
      String name, {
      Set<AppPlatform> platforms = const {AppPlatform.android, AppPlatform.ios},
    }) =>
        _method(
          issuer: 'https://$name.example.com',
          label: LocalizedText('label', en: 'Continue with $name'),
          appStore: AppStoreLogin.thirdParty,
          platforms: platforms,
        );
    SignInMethod private({
      Set<AppPlatform> platforms = const {AppPlatform.ios},
    }) =>
        _method(
          issuer: 'https://private.example.com',
          platforms: platforms,
        );

    test(
        'warns of an app with a login service of a third party on iOS and '
        'no way to sign in that the App Store takes as its equivalent there',
        () {
      final warning = issuesOf([thirdParty('Example')]).single;

      expect(warning.isError, isFalse);
      expect(warning.category, WarningCategory.composition);
      expect(warning.code, AuthRole.noEquivalentSignInWarning);
      expect(warning.code, 'auth.no_equivalent_sign_in');
      expect(SmfIssue.isWarningCode(warning.code!), isTrue);
      expect(warning.origin, isNull);
      expect(
        warning.message,
        'The app offers Continue with Example on iOS, a login service of a '
        'third party, but no way to sign in that the App Store takes as an '
        'equivalent: one that asks for no more than the name and the email '
        'address of the user and lets the user keep the address private '
        '(App Store Review Guideline 4.8).',
      );
      expect(
        warning.hint,
        'Add such a way to sign in on iOS, such as Sign in with Apple.',
      );
      expect(
        issuesOf([thirdParty('One'), thirdParty('Two'), thirdParty('Three')])
            .single
            .message,
        startsWith(
          'The app offers Continue with One, Continue with Two and Continue '
          'with Three on iOS, login services of third parties, but',
        ),
      );
      // The equivalent on Android only is none on iOS.
      expect(
        issuesOf([
          thirdParty('Example'),
          private(platforms: const {AppPlatform.android}),
        ]).single.code,
        AuthRole.noEquivalentSignInWarning,
      );
    });

    test(
        'warns of nothing with an equivalent on iOS, with a login service of '
        'a third party on Android only, and without one', () {
      expect(issuesOf([thirdParty('Example'), private()]), isEmpty);
      expect(issuesOf([private(), thirdParty('Example')]), isEmpty);
      expect(
        issuesOf([
          thirdParty('Example', platforms: const {AppPlatform.android}),
        ]),
        isEmpty,
      );
      expect(issuesOf([private()]), isEmpty);
      expect(issuesOf(const []), isEmpty);
    });

    test(
        'reports two modules with ways to sign in of one issuer, which the '
        'app would show two buttons for', () {
      final issues = issuesOf([_method(), _method(), _method()]);

      expect([
        for (final issue in issues) issue.origin,
      ], const [
        ModuleOrigin(ModuleId('sign_in_1')),
        ModuleOrigin(ModuleId('sign_in_2')),
      ]);
      expect(
        issues.first.message,
        'The modules sign_in_0 and sign_in_1 both give the authentication '
        'role a way to sign in of https://id.example.com, so the app would '
        'show two buttons for one identity provider.',
      );
      expect(issues.first.isError, isTrue);
      // The module rule of the module reports two of its own.
      expect(
        authRole.template.validate(
          inputOf(
            authRole,
            data: [
              dataOf(authRole, _method(), module: 'example_sign_in'),
              authRole.data(_method()).withOrigin(
                    const ModuleOrigin(
                      ModuleId('example_sign_in'),
                      variant: ModuleId('bloc'),
                    ),
                  ),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('reports a way to sign in that the template of a role gives', () {
      final issue = authRole.template
          .validate(
            inputOf(
              authRole,
              data: [
                authRole.data(_method()).withOrigin(
                      RoleTemplateOrigin(_otherRole),
                    ),
              ],
            ),
          )
          .single;

      expect(issue.isError, isTrue);
      expect(issue.origin, RoleTemplateOrigin(_otherRole));
      expect(
        issue.message,
        'The way to sign in of https://id.example.com comes from '
        'role:account_screens, but only a module gives the authentication '
        'role a way to sign in.',
      );
    });
  });

  group('the module rule auth.methods', () {
    final brick = _brick([_methodPath]);
    final method = authRole.data(_method());
    final texts = localizationRole.data(TextsData([_method().label]));

    test(
        'accepts ways to sign in whose functions the bricks of the module '
        'generate, of a module that requires or provides the role', () {
      expect(_methodModuleIssues([brick, method, texts]), isEmpty);
      expect(
        _methodModuleIssues(
          [brick, method, authRole.data(_implementation(async: false))],
          module: _provider,
        ),
        isEmpty,
      );
      // A module that only uses the role and gives it no way to sign in.
      expect(_methodModuleIssues(const [], module: _feature), isEmpty);
    });

    test(
        'rejects a way to sign in of a module that neither requires nor '
        'provides the role, whose function would be in an app without the '
        'files of the role', () {
      final issue =
          _methodModuleIssues([brick, method], module: _feature).single;

      expect(issue.origin, const ModuleOrigin(ModuleId('profile')));
      expect(
        issue.message,
        'The module gives the authentication role a way to sign in, but '
        'neither requires nor provides the role, so its function would be in '
        'an app without the files of the role that it uses.',
      );
      expect(issue.hint, 'Add the role to the requires of the module.');
    });

    test(
        'rejects a way to sign in with problems, a label with translations '
        'of a module without the texts of the app, and two ways to sign in '
        'of one issuer', () {
      const plain = ModuleDescriptor(
        id: ModuleId('example_sign_in'),
        description: 'Sign-in with an example identity provider',
        kind: ModuleKinds.infrastructure,
        requires: {authRole},
      );
      final issues = _methodModuleIssues(
        [
          brick,
          authRole.data(_method(issuer: 'http://id.example.com')),
          authRole.data(
            _method(
              label: const LocalizedText(
                'label',
                en: 'Continue',
                translations: {'uk': 'Продовжити'},
              ),
            ),
          ),
          method,
        ],
        module: plain,
      );

      expect(
        [for (final issue in issues) issue.message],
        [
          contains('must be an https URL'),
          contains('has a translation into uk, but the module '
              'example_sign_in does not list the localization role'),
          'The module gives two ways to sign in of https://id.example.com.',
        ],
      );
      for (final issue in issues) {
        expect(issue.origin, const ModuleOrigin(ModuleId('example_sign_in')));
      }
    });

    test(
        'rejects a function in a file that the bricks of the module do not '
        'generate', () {
      final issue = _methodModuleIssues([method, texts]).single;

      expect(
        issue.message,
        'The function fakeCredential of the way to sign in of '
        'https://id.example.com is in lib/fakes/fake_method.dart, which the '
        'bricks of the module do not generate.',
      );
      expect(issue.path, _methodPath);
      expect(
        issue.hint,
        'Generate the file of the function in a brick of the module.',
      );
    });
  });

  group('the structural rule auth.method_functions', () {
    /// The issues of the structural rules of the role in an app with the
    /// way to sign in of the module `example_sign_in`, [method], and with
    /// [files], each with its owner, or with the module as its owner.
    List<SmfIssue> issuesOf(
      List<DartFileIndex> files, {
      SignInMethod? method,
      Map<String, ContributionOrigin> owners = const {},
    }) =>
        authRole
            .checkStructure(
              StructuralRuleRequest(
                hook: RoleHookRequest(
                  data: [
                    dataOf(
                      authRole,
                      method ?? _method(),
                      module: 'example_sign_in',
                    ),
                  ],
                  presentRoles: {authRole},
                  context: testContext,
                ),
                files: {for (final file in files) file.path: file},
                owners: {
                  for (final file in files)
                    file.path: const ModuleOrigin(ModuleId('example_sign_in')),
                  ...owners,
                },
              ),
            )
            .where((issue) => issue.path == _methodPath)
            .toList();

    /// The file of the function of the way to sign in, which declares it
    /// with [type] and [parameters], and imports the file of the session
    /// and invokes [invocations].
    DartFileIndex functionFile({
      String? type = 'Future<SignInCredential?>',
      List<IndexedParameter> parameters = const [],
      List<IndexedInvocation> invocations = const [],
      List<IndexedReference> references = const [],
    }) =>
        DartFileIndex(
          path: _methodPath,
          imports: const [
            IndexedImport('package:my_app/core/auth/app_session.dart'),
          ],
          declarations: [
            IndexedDeclaration(
              name: 'fakeCredential',
              kind: DeclarationKind.function,
              type: type,
              parameters: parameters,
            ),
          ],
          invocations: invocations,
          references: references,
        );

    test(
        'accepts a function that returns a Future of a credential that may '
        'be null and takes no arguments, in a file that uses the session '
        'only for its types', () {
      expect(issuesOf([functionFile()]), isEmpty);
      expect(
        issuesOf([functionFile(type: 'Future<IdTokenCredential?>')]),
        isEmpty,
      );
      expect(
        issuesOf([
          functionFile(
            invocations: const [IndexedInvocation('IdTokenCredential')],
          ),
        ]),
        isEmpty,
      );
    });

    test(
        'rejects a function that returns no Future of a credential that '
        'may be null, or requires arguments', () {
      const hint = 'The screens of sign-in and appSession.deleteAccount() '
          'call it without arguments, and await a credential or null.';
      final issues = {
        for (final (name, file) in [
          ('a credential', functionFile(type: 'Future<SignInCredential>')),
          ('no Future', functionFile(type: 'SignInCredential?')),
          ('no type', functionFile(type: null)),
          (
            'an argument',
            functionFile(
              parameters: const [
                IndexedParameter(
                  'hint',
                  kind: ParameterKind.requiredPositional,
                ),
              ],
            ),
          ),
        ])
          name: [
            for (final issue in issuesOf([file])) ...[
              issue.message,
              if (issue.hint != hint) 'another hint',
            ],
          ],
      };

      const notNullable = 'function fakeCredential() in '
          'lib/fakes/fake_method.dart must return a Future of a credential '
          'that may be null, such as Future<SignInCredential?>, not '
          'Future<SignInCredential>.';
      expect(issues, {
        'a credential': [notNullable],
        'no Future': [contains('not SignInCredential?.')],
        'no type': [contains('not an undeclared type.')],
        'an argument': [contains('fakeCredential')],
      });
    });

    test(
        'rejects a missing function, and a function in a file of another '
        'module', () {
      expect(
        issuesOf([const DartFileIndex(path: _methodPath)]).single.message,
        contains('does not declare function fakeCredential()'),
      );
      final issue = issuesOf(
        [functionFile()],
        owners: {_methodPath: const ModuleOrigin(ModuleId('other'))},
      ).single;
      expect(
        issue.message,
        'The function fakeCredential of the way to sign in of '
        'https://id.example.com of example_sign_in is in '
        'lib/fakes/fake_method.dart, a file of other; a way to sign in calls '
        'a function of its own module.',
      );
    });

    test(
        'rejects a file of the function that uses appSession, which calls '
        'the function within its own calls', () {
      for (final file in [
        // As the index of a file has `appSession.signInWith(credential)`.
        functionFile(
          invocations: const [
            IndexedInvocation('signInWith', target: 'appSession'),
          ],
          references: const [IndexedReference('appSession')],
        ),
        // And `session.appSession.value`, after an import with a prefix.
        const DartFileIndex(
          path: _methodPath,
          imports: [
            IndexedImport(
              'package:my_app/core/auth/app_session.dart',
              prefix: 'session',
            ),
          ],
          declarations: [
            IndexedDeclaration(
              name: 'fakeCredential',
              kind: DeclarationKind.function,
              type: 'Future<SignInCredential?>',
            ),
          ],
          memberAccesses: [IndexedMemberAccess('session', 'appSession')],
        ),
      ]) {
        final issue = issuesOf([file]).single;
        expect(
          issue.message,
          'lib/fakes/fake_method.dart, the file of the function '
          'fakeCredential of the way to sign in of https://id.example.com, '
          'uses appSession, which calls that function within its own calls '
          'when it deletes an account, so a call of appSession there would '
          'wait for itself.',
        );
        expect(issue.origin, const ModuleOrigin(ModuleId('example_sign_in')));
      }
    });

    test('leaves a function of a package to the compiler', () {
      expect(
        issuesOf(
          const [],
          method: const SignInMethod(
            label: LocalizedText('label', en: 'Continue with Example'),
            icon: Fragment('Icon(Icons.key)'),
            platforms: {AppPlatform.ios},
            credential: FunctionRef(
              'credential',
              import: ImportRef('package:example/example.dart'),
            ),
            issuer: _issuer,
            appStore: AppStoreLogin.privacyFocused,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('the generated session signs in with a credential', () {
    late DartFiles app;

    setUpAll(() async => app = await _app());

    tearDownAll(() => app.delete());

    test(
        'signs in a user who is not signed in and the user of an account, '
        'gives an anonymous user a new identity with the same id, and signs '
        'an anonymous user in to the account of an identity that has one, '
        'with the same credential, moving the data of the guest', () async {
      const issuer = 'https://id.example.com';
      const signIn = 'signInWith IdTokenCredential($issuer)';
      const link = 'linkWith IdTokenCredential($issuer)';
      Map<String, Object?> note(
        String state,
        List<String> calls, {
        String issuers = issuer,
        String? failure,
      }) =>
          {
            'calls': calls,
            'state': state,
            'issuers': issuers,
            if (failure != null) 'failure': failure,
          };

      expect(await app.run('$_notes$_signInWith'), {
        'a user who is not signed in': note('account user-1 null', [signIn]),
        'the user of an account, with another identity':
            note('account user-2 null', [signIn]),
        'the first identity again': {
          ...note('account user-1 null', [signIn]),
          'the same user': true,
        },
        'the issuers cannot change': startsWith('no AuthFailure: Unsupported'),
        'an anonymous user, with a new identity': {
          ...note('account user-3 null', [link]),
          'keeps the id': true,
        },
        'an anonymous user, with the identity of another user': {
          ...note(
            'account user-3 null',
            [link, 'take user-4', signIn, 'give user-3'],
          ),
          'the sign-in got the credential of the link': true,
        },
        'an anonymous user, with an identity whose address has an account':
            note(
          'account user-6 null',
          [link, 'take user-5', signIn, 'give user-6'],
        ),
        // The anonymous user stays, and nothing was given.
        'the sign-in after the link fails too': note(
          'anonymous user-7',
          [link, 'take user-7', signIn],
          issuers: '-',
          failure: 'accountExistsWithOtherMethod, hint null, thrown in '
              'fake_auth.dart',
        ),
        'a link that fails with another reason': note(
          'anonymous user-8',
          [link],
          issuers: '-',
          failure: 'network, hint null, thrown in fake_auth.dart',
        ),
        'a link that fails with an error of another kind': note(
          'anonymous user-9',
          [link],
          issuers: '-',
          failure: 'unknown, hint Bad state: The link broke., thrown in '
              'fake_auth.dart',
        ),
      });
    });
  });

  group('the generated session deletes an account of a way to sign in', () {
    late DartFiles app;

    setUpAll(() async => app = await _app(methods: _deletionMethods));

    tearDownAll(() => app.delete());

    test('is code that type-checks', () async {
      expect(await app.analysisProblems(), isEmpty);
    });

    test(
        'asks a way to sign in of the account that revokes and is available '
        'for a credential again first, within its call, and gives it to the '
        'service; deletes nothing when the user closes the sheet, which is '
        'no failure, nor when that way to sign in or the service fails',
        () async {
      const fresh =
          'deleteAccount fresh IdTokenCredential(https://id.example.com)';
      const account = 'account account null';
      const none = 'none';
      Map<String, Object?> note(
        List<String> calls, {
        String state = 'signed out',
        String failure = none,
        bool? got,
      }) =>
          {
            'calls': calls,
            'state': state,
            'failure': failure,
            if (got != null)
              'the service got the credential of the way to sign in': got,
          };

      expect(await app.run('$_notes$_revokingDeletion'), {
        'a way to sign in that revokes, on its platform':
            note(['credential', fresh], got: true),
        'the same way to sign in on another platform': note(['deleteAccount']),
        'two that revoke, on the platform of the second only':
            note(['credential', fresh], got: true),
        'a way to sign in that does not revoke': note(['deleteAccount']),
        'no way to sign in': note(['deleteAccount']),
        'the user closes the sheet': note(['credential'], state: account),
        'the way to sign in fails': note(
          ['credential'],
          state: account,
          failure: 'notConfigured, hint Set up the capability., thrown in '
              'fake_method.dart',
        ),
        'the way to sign in throws another error': note(
          ['credential'],
          state: account,
          failure: 'unknown, hint Bad state: The sheet broke., thrown in '
              'fake_method.dart',
        ),
        'the revocation fails': note(
          ['credential', fresh],
          state: account,
          failure: 'notConfigured, hint Set up the key., thrown in '
              'fake_auth.dart',
          got: true,
        ),
        'in the anonymous mode': note(
          ['credential', fresh, 'signInAnonymously'],
          state: 'anonymous user-1',
          got: true,
        ),
        // The sign-out waits for the deletion.
        'a call while the way to sign in asks': {
          'calls while it asks': ['credential'],
          'calls': [fresh, 'signOut'],
        },
      });
    });
  });

  group('the ways to sign in in the section of the auth role in the README',
      () {
    /// The section of the README of the app with [methods].
    Future<String> sectionWith(List<SignInMethod> methods) async {
      final rendered = await _rendered(methods: methods);
      return rendered.elsewhere
          .singleWhere((entry) => entry.socket == AppEntryRole.readmeSections)
          .entryValue! as String;
    }

    test(
        'tells in an app without ways to sign in where one goes, after what '
        'it tells of the mode and of the data of a guest', () async {
      final section = await sectionWith(const []);

      expect(
        section,
        endsWith(
          'As generated it moves nothing.\n\n'
          'Besides an email address and a password, the app signs in with no '
          'identity provider, such as the account of a user at another '
          'service. Such a way to sign in is a `SignInMethod` of '
          '`appSignInMethods` in `lib/core/auth/sign_in_methods.dart`, which '
          'the module of the way to sign in adds.\n',
        ),
      );
    });

    test(
        'lists the ways to sign in of the app with their platforms, tells '
        'what the deletion of an account of one that revokes asks, and what '
        'an anonymous user gets', () async {
      final section = await sectionWith([
        _method(revokes: true, platforms: const {AppPlatform.ios}),
        _method(
          issuer: 'https://other.example.com',
          label: const LocalizedText('label', en: 'Continue with Other'),
          appStore: AppStoreLogin.thirdParty,
        ),
      ]);

      expect(
        section,
        endsWith(
          'Besides an email address and a password, the app signs in with '
          'these identity providers, the ways to sign in of '
          '`appSignInMethods` in `lib/core/auth/sign_in_methods.dart`:\n'
          '\n'
          '- Continue with Example, on iOS. Deleting an account that signs in '
          'this way asks the identity provider for a credential again first, '
          'so that the provider of sign-in can revoke the tokens that it gave '
          'the app. If the user closes its sheet, nothing is deleted.\n'
          '- Continue with Other, on Android and iOS.\n'
          '\n'
          'A screen of sign-in shows the button of a way to sign in only on '
          'the platforms that it works on. When an anonymous user signs in '
          'this way, the user gets the identity and keeps the id if no '
          'account has it yet, and otherwise signs in to that account, as '
          'with a password, and `takeGuestData()` moves what the anonymous '
          'user had.\n',
        ),
      );
    });

    test(
        'tells what the App Store asks when the app has a login service of '
        'a third party on iOS and no equivalent, as the warning does',
        () async {
      const asks = 'On iOS, the App Store asks an app that offers a login '
          'service of a third party to offer an equivalent one too, one that '
          'asks for no more than the name and the email address of the user '
          'and lets the user keep the address private (App Store Review '
          'Guideline 4.8). This app offers none on iOS, so the review may '
          'reject it until it does.\n';
      final thirdParty = _method(
        issuer: 'https://other.example.com',
        appStore: AppStoreLogin.thirdParty,
      );

      expect(await sectionWith([thirdParty]), endsWith('had.\n\n$asks'));
      expect(await sectionWith([thirdParty, _method()]), isNot(contains(asks)));
      expect(
        await sectionWith([
          _method(
            issuer: 'https://other.example.com',
            appStore: AppStoreLogin.thirdParty,
            platforms: const {AppPlatform.android},
          ),
        ]),
        isNot(contains(asks)),
      );
    });
  });
}
