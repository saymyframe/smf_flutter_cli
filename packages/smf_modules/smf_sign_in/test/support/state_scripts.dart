import 'package:smf_pipeline/testing.dart';

import 'dart_app.dart';

/// What every script of the state of the sign-in screens starts with: the
/// files of the auth role and the values of the state, a service of
/// sign-in that the script scripts, and what the scenarios share,
/// whichever way the app manages state.
///
/// `Scripted` notes its calls, holds them while `hold` is not complete,
/// and fails them with `failure` while that is set. `Screen` is the state
/// of one screen as a scenario sees it: its state, each state that it told
/// its listeners of, the call of the screen, and the user who leaves the
/// screen.
const _prelude = r'''
import 'dart:async';
import 'dart:isolate';

import 'package:contract_app/core/auth/app_session.dart';
import 'package:contract_app/core/auth/auth_service.dart';
import 'package:contract_app/features/sign_in/sign_in_guards.dart';
import 'package:contract_app/features/sign_in/sign_in_state.dart';

const email = 'ann@example.com';
const password = 'secret';

final class Scripted implements AuthService {
  final StreamController<AuthUser?> _changes = StreamController.broadcast();

  AuthUser? user;

  /// The calls that the service got, each with its arguments.
  final List<String> calls = [];

  /// What the calls wait for, or `null`.
  Completer<void>? hold;

  /// What the calls fail with, or `null`.
  AuthFailure? failure;

  Future<void> _answer(String call, AuthUser? Function()? next) async {
    calls.add(call);
    await hold?.future;
    if (failure case final failure?) throw failure;
    if (next == null) return;
    user = next();
    _changes.add(user);
  }

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) =>
      _answer(
        'signIn $email $password',
        () => AuthUser(uid: 'account', isAnonymous: false, email: email),
      );

  @override
  Future<void> signUp({required String email, required String password}) =>
      _answer(
        'signUp $email $password',
        () => AuthUser(uid: 'new', isAnonymous: false, email: email),
      );

  @override
  Future<void> linkPassword({
    required String email,
    required String password,
  }) => _answer(
    'linkPassword $email $password',
    () => AuthUser(uid: user!.uid, isAnonymous: false, email: email),
  );

  @override
  Future<void> signInAnonymously() => _answer(
    'signInAnonymously',
    () => const AuthUser(uid: 'guest', isAnonymous: true),
  );

  @override
  Future<void> sendPasswordReset(String email) =>
      _answer('sendPasswordReset $email', null);

  @override
  Future<void> signOut() => _answer('signOut', () => null);

  @override
  Future<void> deleteAccount() => _answer('deleteAccount', () => null);
}

/// A session of an app in [mode], started with [service].
Future<AppSessionController> sessionOf(
  Scripted service, {
  AuthMode mode = AuthMode.required,
}) async {
  final session = AppSessionController(
    mode: mode,
    takeGuestData: (_) async => null,
  );
  await session.start(service);
  return session;
}

String show(Object? value) => switch (value) {
  AuthActionState(:final busy, :final failure) =>
    'busy: $busy, failure: ${failure?.reason.name}',
  ResetPasswordState(:final busy, :final failure, :final sentTo) =>
    'busy: $busy, failure: ${failure?.reason.name}, sent to: $sentTo',
  SignedOutSession() => 'nobody',
  AnonymousSession(:final uid) => 'anonymous $uid',
  AccountSession(:final uid, :final email) => 'account $uid $email',
  _ => '$value',
};

/// Lets what waits for a microtask or for a timer of no time go on.
Future<void> turn() => Future<void>.delayed(Duration.zero);

/// The state of a screen as a scenario sees it.
final class Screen {
  Screen({
    required this.state,
    required this.states,
    required this.submit,
    required this.leave,
  });

  /// The state of the screen now.
  final String Function() state;

  /// Each state that the screen told its listeners of, in order.
  final List<String> states;

  /// Makes the call of the screen, as its button does.
  final Future<void> Function() submit;

  /// The user leaves the screen.
  final Future<void> Function() leave;
}

/// What a screen does in each scenario, by the name of the scenario:
/// [open] creates the state of the screen over a session.
Future<Map<String, Object?>> scenariosOf(
  Screen Function(AppSessionController session) open,
) async {
  final result = <String, Object?>{};

  // The call succeeds.
  {
    final service = Scripted();
    final session = await sessionOf(service);
    final screen = open(session);
    result['at first'] = screen.state();
    await screen.submit();
    await turn();
    result['success: states'] = [...screen.states];
    result['success: state'] = screen.state();
    result['success: calls'] = [...service.calls];
    result['success: session'] = show(session.value);
  }

  // The call fails, and the next one succeeds.
  {
    final service = Scripted()
      ..failure = const AuthFailure(
        AuthFailureReason.network,
        developerHint: 'offline',
      );
    final session = await sessionOf(service);
    final screen = open(session);
    await screen.submit();
    await turn();
    result['failure: states'] = [...screen.states];
    result['failure: state'] = screen.state();
    result['failure: session'] = show(session.value);
    service.failure = null;
    await screen.submit();
    await turn();
    result['again: states'] = [...screen.states];
    result['again: calls'] = service.calls.length;
  }

  // A second submit while the call is on its way.
  {
    final service = Scripted()..hold = Completer<void>();
    final session = await sessionOf(service);
    final screen = open(session);
    final first = screen.submit();
    await turn();
    result['busy: state'] = screen.state();
    await screen.submit();
    await turn();
    result['busy: calls'] = service.calls.length;
    result['busy: states'] = [...screen.states];
    service.hold!.complete();
    await first;
    await turn();
    result['busy: calls in the end'] = service.calls.length;
  }

  // The user leaves the screen while the call is on its way, and the call
  // then fails or succeeds.
  for (final fails in [true, false]) {
    final name = fails ? 'left, then a failure' : 'left, then a success';
    final service = Scripted()..hold = Completer<void>();
    final session = await sessionOf(service);
    final screen = open(session);
    final call = screen.submit();
    await turn();
    await screen.leave();
    final told = screen.states.length;
    if (fails) {
      service.failure = const AuthFailure(AuthFailureReason.network);
    }
    service.hold!.complete();
    try {
      await call;
      await turn();
      result['$name: error'] = null;
    } on Object catch (error) {
      result['$name: error'] = '$error';
    }
    result['$name: states told since'] = screen.states.length - told;
  }
  return result;
}
''';

/// Runs [body] as the `main` of a script in an isolate of its own, with
/// the Dart files of [app] and [imports], the paths below `lib/` of the
/// files of the app that the script uses besides those of the auth role
/// and the values of the state, and returns what it puts into `result`.
///
/// [declarations] are the top-level declarations of the script, such as
/// what opens the state of a screen in the way of a variant.
Future<Map<Object?, Object?>> runState(
  RenderedApp app, {
  required List<String> imports,
  required String body,
  String declarations = '',
}) async {
  final dartApp = await DartApp.write(app);
  try {
    final directives = _prelude.replaceFirst(
      "import 'dart:isolate';\n",
      [
        "import 'dart:isolate';\n",
        for (final import in imports) "import '$import';",
      ].join('\n'),
    );
    return (await dartApp.run('''
$directives
$declarations

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};
$body
  port.send(result);
}
'''))! as Map<Object?, Object?>;
  } finally {
    dartApp.delete();
  }
}

/// The errors and warnings that the analyzer finds in the files of [app]
/// at [paths], with the packages that the state managers build on.
Future<List<String>> analysisProblemsOf(
  RenderedApp app,
  Iterable<String> paths,
) async {
  final dartApp = await DartApp.write(app);
  try {
    return await dartApp.analysisProblems(paths);
  } finally {
    dartApp.delete();
  }
}
