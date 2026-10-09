import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'auth_service.dart';
import 'guest_data.dart';

export 'auth_service.dart' show AuthFailure, AuthFailureReason;

/// Who may use the app without an account.
enum AuthMode {
  /// Nobody: the user signs in first.
  required,

  /// Everyone. The app has no user until someone signs in, and asks for an
  /// account only where a screen needs one.
  guest,

  /// Everyone, as an anonymous user that the app signs in itself when it
  /// starts, so that code has the id of a user from the first frame. An
  /// account is asked for only where a screen needs one, and signing up
  /// gives it to that same user.
  anonymous,
}

/// The mode of this app, which was chosen when the app was generated.
///
/// The mode gates nothing on its own. It decides what [appSession] does when
/// it starts and what [AppSessionController.allowsApp] says, which a guard
/// of the routes reads.
const AuthMode authMode = {{{auth_mode}}};

/// Who uses the app: nobody that the app knows, an anonymous user, or the
/// user of an account.
@immutable
sealed class AppSession {
  const AppSession();

  /// The id of the user, or `null` when nobody is signed in.
  String? get uid;
}

/// Nobody is signed in.
final class SignedOutSession extends AppSession {
  /// Creates the session of an app without a user.
  const SignedOutSession();

  @override
  String? get uid => null;

  @override
  bool operator ==(Object other) => other is SignedOutSession;

  @override
  int get hashCode => (SignedOutSession).hashCode;
}

/// An anonymous user is signed in: one without an account, whom the app
/// signed in itself.
final class AnonymousSession extends AppSession {
  /// Creates the session of the anonymous user [uid].
  const AnonymousSession(this.uid);

  @override
  final String uid;

  @override
  bool operator ==(Object other) =>
      other is AnonymousSession && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}

/// The user of an account is signed in.
final class AccountSession extends AppSession {
  /// Creates the session of the account [uid].
  const AccountSession(this.uid, {this.email});

  @override
  final String uid;

  /// The email address of the account, or `null` if it has none.
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AccountSession && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);
}

/// The session of the app: who uses it, known before the first frame, and
/// the way to sign in, up and out.
///
/// Its `value` is the [AppSession], and it tells its listeners when that
/// changes. A widget follows it with a `ValueListenableBuilder`.
final appSession = AppSessionController(
  mode: authMode,
  takeGuestData: takeGuestData,
);

/// Keeps the session of the app up to date with the service of the provider
/// of sign-in, and signs in, up and out through that service. The app has
/// one, [appSession].
///
/// Every call here fails only with an [AuthFailure], whose reason the app
/// shows in a text of its own. An error of another kind becomes a failure
/// with the reason [AuthFailureReason.unknown] and the error as its
/// [AuthFailure.developerHint].
///
/// The calls run one after another, in the order they were made, and none
/// runs next to an anonymous sign-in that is on its way. So the user of the
/// app is the result of the call that was made last.
final class AppSessionController extends ChangeNotifier
    implements ValueListenable<AppSession> {
  /// Creates a controller for an app in [mode]. The app creates
  /// [appSession] and no other. A test creates one to see another mode, or
  /// a shorter [anonymousWait], and disposes of it.
  AppSessionController({
    required this.mode,
    required this.takeGuestData,
    this.anonymousWait = const Duration(seconds: 3),
  });

  /// Who may use the app without an account.
  final AuthMode mode;

  /// Takes what an anonymous user has before that user signs in to an
  /// account: `takeGuestData` of `guest_data.dart`.
  final Future<GiveGuestData?> Function(String guestUid) takeGuestData;

  /// How long the app waits for its anonymous user when it starts, and
  /// after a sign-out or the deletion of an account, in the mode
  /// [AuthMode.anonymous].
  final Duration anonymousWait;

  AuthService? _service;
  StreamSubscription<AuthUser?>? _userChanges;
  AppSession _session = const SignedOutSession();

  /// Completes when the app has started for the first time.
  final Completer<void> _started = Completer<void>();

  /// The call that was made last, while a call is on its way: the next one
  /// waits for it. It is `null` when none is, and a call then awaits
  /// nothing. A future that completed in another zone would hold the call
  /// back in a widget test, where the app starts in real time and the test
  /// goes on in fake time.
  Future<void>? _lastCall;

  /// The anonymous sign-in that is on its way, so that the app starts no
  /// second one next to it.
  Future<void>? _anonymousSignIn;

  /// Tells when the user comes back to the app, in the mode
  /// [AuthMode.anonymous].
  AppLifecycleListener? _lifecycle;

  /// Who uses the app.
  @override
  AppSession get value => _session;

  /// Whether the user may see the app: always in the modes [AuthMode.guest]
  /// and [AuthMode.anonymous], and with an account in the mode
  /// [AuthMode.required].
  ///
  /// It is computed from the session each time it is read, and its
  /// listeners are those of the session. So when the session changes, a
  /// listener finds this value and [hasAccount] both up to date, whichever
  /// of the two it listens to. A listener is also called for a change of
  /// the session that leaves this value as it was.
  late final ValueListenable<bool> allowsApp = _SessionFlag(
    this,
    (session) => mode != AuthMode.required || session is AccountSession,
  );

  /// Whether the user of an account is signed in, which an anonymous user
  /// is not. It follows the session as [allowsApp] does.
  late final ValueListenable<bool> hasAccount = _SessionFlag(
    this,
    (session) => session is AccountSession,
  );

  /// Starts the session with [service]: takes the user who is signed in on
  /// this device, and follows the changes that the service tells of.
  ///
  /// `initAuth()` calls it in `bootstrap()`, so the session is known before
  /// the first frame. In the mode [AuthMode.anonymous], an app without a
  /// user signs in anonymously here and waits for that for at most
  /// [anonymousWait]. When the sign-in fails or takes longer, the app
  /// starts without a user. A sign-in that takes longer still becomes the
  /// session when it comes, and the app tries again each time the user
  /// comes back to it.
  ///
  /// A call made before the first start waits for it: [signIn], [signUp],
  /// [sendPasswordReset], [signOut] and [deleteAccount]. Such calls run in
  /// their order once the start has the user, and the future of this start
  /// completes after them. The mocks of the tests of an app use this: a
  /// call of [signUp] made before `bootstrap()`, which nothing awaits,
  /// gives the app an account before its first frame.
  ///
  /// It may be called again, with the service that the session has from
  /// then on: `initAuth()` does so in a test of the next launch of the app,
  /// and a test gives it a service of its own.
  Future<void> start(AuthService service) async {
    unawaited(_userChanges?.cancel());
    if (!identical(service, _service)) _anonymousSignIn = null;
    _service = service;
    _userChanges = service.userChanges.listen((_) => _sync());
    _sync();
    if (mode == AuthMode.anonymous) {
      // The try of a user who comes back waits for its turn among the
      // calls, so it starts no anonymous sign-in next to a sign-in.
      _lifecycle ??= AppLifecycleListener(
        onResume: () => unawaited(_call((_) => _signInAnonymously())),
      );
      await _signInAnonymously();
    }
    if (!_started.isCompleted) _started.complete();
    await _lastCall;
  }

  /// Signs in to the account of [email] with [password].
  ///
  /// An anonymous user becomes the user of that account, and what the
  /// anonymous user had moves to the account as `takeGuestData` says.
  Future<void> signIn({required String email, required String password}) =>
      _call(
        (service) => _toAccount(
          () => service.signIn(email: email, password: password),
        ),
      );

  /// Creates an account for [email] with [password] and signs in to it.
  ///
  /// An anonymous user gets the account and keeps the id, so everything
  /// that the user had stays.
  Future<void> signUp({required String email, required String password}) =>
      _call(
        (service) => _session is AnonymousSession
            ? service.linkPassword(email: email, password: password)
            : service.signUp(email: email, password: password),
      );

  /// Sends the message with which the owner of the account of [email] sets
  /// a new password. It completes whether [email] has an account or not.
  Future<void> sendPasswordReset(String email) =>
      _call((service) => service.sendPasswordReset(email));

  /// Signs the user out. In the mode [AuthMode.anonymous], the app then
  /// signs in anonymously again, as when it starts.
  Future<void> signOut() => _call((service) async {
        await service.signOut();
        _sync();
        await _signInAnonymously();
      });

  /// Deletes the user who is signed in. The app is then without a user, as
  /// after [signOut], and in the mode [AuthMode.anonymous] it signs in
  /// anonymously again.
  ///
  /// It may fail with [AuthFailureReason.recentSignInRequired]: the user
  /// then signs out, signs in again and repeats it.
  Future<void> deleteAccount() => _call((service) async {
        await service.deleteAccount();
        _sync();
        await _signInAnonymously();
      });

  @override
  void dispose() {
    unawaited(_userChanges?.cancel());
    _lifecycle?.dispose();
    super.dispose();
  }

  /// Runs [call] with the service once the calls made before it are over,
  /// and not before the app has started for the first time.
  Future<void> _call(Future<void> Function(AuthService service) call) async {
    final earlier =
        _lastCall ?? (_started.isCompleted ? null : _started.future);
    final done = Completer<void>();
    final own = _lastCall = done.future;
    if (earlier != null) await earlier;
    try {
      await _guarded(call);
    } finally {
      if (identical(_lastCall, own)) _lastCall = null;
      done.complete();
    }
  }

  /// Runs [call] with the service, once an anonymous sign-in that is on its
  /// way is over: of a call and a sign-in that run at the same time, the
  /// one that ended last would decide who the user is.
  ///
  /// Whatever [call] throws that is no [AuthFailure] becomes one, and the
  /// session has the user of the service when it is over, also when it
  /// failed.
  Future<void> _guarded(
    Future<void> Function(AuthService service) call,
  ) async {
    try {
      await _anonymousSignIn;
      await call(_service!);
    } on AuthFailure {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthFailure(AuthFailureReason.unknown, developerHint: '$error'),
        stackTrace,
      );
    } finally {
      _sync();
    }
  }

  /// Signs in to an account with [signIn], in whichever way, and moves what
  /// an anonymous user had to that account.
  ///
  /// It takes the data before the sign-in, while the anonymous user is
  /// still signed in, and gives it once the user of another id has an
  /// account. If taking fails, the call fails and nothing has changed. If
  /// giving fails, the user is signed in already, so the call completes and
  /// the error is reported as an error of the app.
  Future<void> _toAccount(Future<void> Function() signIn) async {
    final guest = _session;
    final give =
        guest is AnonymousSession ? await takeGuestData(guest.uid) : null;
    await signIn();
    _sync();
    final account = _session;
    if (give == null ||
        account is! AccountSession ||
        account.uid == guest.uid) {
      return;
    }
    try {
      await give(account.uid);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app session',
          context: ErrorDescription(
            'while giving the data of a guest to the account',
          ),
        ),
      );
    }
  }

  /// In the mode [AuthMode.anonymous], signs in anonymously when nobody is
  /// signed in, and waits for that for at most [anonymousWait].
  ///
  /// It never fails. A sign-in that takes longer goes on and becomes the
  /// session when it comes. One that fails leaves the app without a user
  /// until the next try, and in debug mode its error is printed.
  Future<void> _signInAnonymously() async {
    final service = _service!;
    if (mode != AuthMode.anonymous || service.currentUser != null) return;
    final signIn = _anonymousSignIn ??=
        _tryAnonymously(service).whenComplete(() {
      if (!identical(service, _service)) return;
      _anonymousSignIn = null;
      _sync();
    });
    await signIn.timeout(anonymousWait, onTimeout: () {});
  }

  Future<void> _tryAnonymously(AuthService service) async {
    try {
      await service.signInAnonymously();
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint(
          'The anonymous sign-in failed, so the app has no user: $error',
        );
      }
    }
  }

  /// Takes the user of the service as the session, and tells the listeners
  /// when that changes it.
  void _sync() {
    final session = switch (_service!.currentUser) {
      null => const SignedOutSession(),
      AuthUser(isAnonymous: true, :final uid) => AnonymousSession(uid),
      AuthUser(:final uid, :final email) => AccountSession(uid, email: email),
    };
    if (session == _session) return;
    _session = session;
    notifyListeners();
  }
}

/// A flag of the session of a controller: its value is computed from the
/// session each time it is read, and its listeners are those of the
/// session.
final class _SessionFlag implements ValueListenable<bool> {
  const _SessionFlag(this._controller, this._of);

  final AppSessionController _controller;
  final bool Function(AppSession session) _of;

  @override
  bool get value => _of(_controller.value);

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);
}

/// Returns the service of the provider of sign-in, which [initAuth] created:
/// `bootstrap()` awaits it before the first frame, and there is none to
/// return before that.
///
/// The code of the app does not call it: it signs in through [appSession].
AuthService createAuthService() => _authService;

{{{smf_auth__implementations}}}
