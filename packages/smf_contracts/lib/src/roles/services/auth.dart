part of '../services.dart';

/// The auth role; see [AuthRole].
const authRole = AuthRole._();

/// Who may use an app without an account: the value of
/// [AuthRole.modeOption], and the choice of the [AuthRole].
enum AuthMode {
  /// Nobody: the user signs in first. The default.
  required('Nobody: the user signs in first'),

  /// Everyone. The app has no user until someone signs in, and asks for an
  /// account only where a screen needs one.
  guest('Everyone: an account only where a screen needs one'),

  /// Everyone, as an anonymous user that the app signs in itself when it
  /// starts, so that code has the id of a user from the first frame.
  /// Signing up gives that same user an account.
  anonymous('Everyone, as an anonymous user with an id from the start');

  const AuthMode(this.label);

  /// The mode as the question of `smf create` offers it.
  final String label;
}

/// The role of sign-in: who uses the app, and the accounts of its users,
/// which a provider keeps, such as a backend with authentication.
///
/// The role's template generates three files, whichever module provides
/// the role:
/// - [serviceFile] with `AuthService`, the interface that the provider
///   implements, `AuthUser`, and `AuthFailure` with its
///   `AuthFailureReason`;
/// - [sessionFile] with `appSession`, the `AppSessionController` of the
///   app, the sealed `AppSession` with `SignedOutSession`,
///   `AnonymousSession` and `AccountSession`, and `authMode`, the mode of
///   the app as an `AuthMode`. The file exports `AuthFailure` and
///   `AuthFailureReason`, so the code of the app imports this file alone;
/// - [guestDataFile] with `takeGuestData`, which the developer of the app
///   edits.
///
/// The provider contributes its implementation of `AuthService` as a
/// [RoleImplementation], created with the app or asynchronously.
///
/// ## The session
///
/// The code of an app reaches sign-in only through `appSession`, a
/// `ValueListenable<AppSession>`: its `signIn`, `signUp`,
/// `sendPasswordReset`, `signOut` and `deleteAccount` call the service and
/// do what is the same with every provider. No module, and no template of
/// another role, calls `createAuthService()` or imports [serviceFile]. The
/// role registers nothing in a DI container: `appSession` is a top-level
/// variable, which a guard of the routes reads synchronously and which the
/// state of a screen takes as it is.
///
/// `Future<void> initAuth()` creates the service with the provider's
/// function and starts the session with it. `bootstrap()` awaits it in its
/// platform phase, so who is signed in is known before the first frame, and
/// nothing else in the app calls it. It may run again, which only tests do,
/// to see what the next launch of the app finds.
///
/// A call of `appSession` fails only with an `AuthFailure`. The provider
/// maps its errors to the reasons, and the session turns any other error
/// into the reason `unknown`, with the error as the `developerHint`. The
/// app shows a text of its own for each reason, and the hint in debug mode
/// only.
///
/// The calls of `appSession` run one after another, in the order they were
/// made, and none runs next to an anonymous sign-in that is on its way. So
/// the user of the app is the result of the call that was made last, and a
/// sign-up finds the anonymous user that it gives the account.
///
/// `appSession.allowsApp` and `appSession.hasAccount` are the two
/// `ValueListenable<bool>` that guards of the routes read. Both are
/// computed from the session when they are read, and their listeners are
/// those of the session, so no listener sees one of them changed and the
/// other not.
///
/// ## The mode
///
/// [modeOption], `--auth-mode`, says who may use the app without an
/// account. The template writes the choice into [sessionFile] as the
/// constant `authMode`, and `appSession` works by it:
/// - `required`, the default: `allowsApp` is true only for the user of an
///   account;
/// - `guest`: `allowsApp` is always true, and the app has no user until
///   someone signs in;
/// - `anonymous`: `allowsApp` is always true, and an app without a user
///   signs in anonymously when it starts, so that code has the id of a
///   user from the first frame. The start waits for that sign-in for at
///   most 3 seconds. When it fails or takes longer, the app starts without
///   a user and tries again each time the user comes back to the app, and
///   after a sign-out or the deletion of an account. `signUp` then gives
///   the anonymous user the account, with the same id.
///
/// The mode gates nothing on its own. A module with the screens of sign-in
/// declares the guards of the routes, with functions of its own that
/// return `appSession.allowsApp` and `appSession.hasAccount`. In an app
/// without such a module, the mode sets only `authMode` and what
/// `allowsApp` says, and the developer's own guard reads
/// `appSession.allowsApp`.
///
/// A provider reads the mode in its render hook with [modeIn]. A module
/// that is no provider has no hook, so its code is the same in every mode
/// and reads `authMode` when the app runs.
///
/// ## The data of a guest
///
/// When an anonymous user signs in to an account that exists already, the
/// user of the app changes. `appSession.signIn` calls `takeGuestData` with
/// the id of the anonymous user before it calls the service, and then
/// calls the function that it got back with the id of the account. An
/// error of the first fails the call before the service is called. An
/// error of the second is reported with `FlutterError.reportError`, and
/// the call completes, since the user is signed in. `signUp` of an
/// anonymous user keeps the id, so it moves nothing.
///
/// ## What a provider keeps to
///
/// The contract of `AuthService` is in [serviceFile]. In short:
/// - the function of the implementation returns a service whose
///   `currentUser` is the user of the device already, without a request to
///   the server, and it may be called again;
/// - when a call completes, `currentUser` is its result, and `userChanges`
///   tells of every change, also of one that no call made;
/// - every failure is an `AuthFailure`, and every call ends, with the
///   reason `network` when the server does not answer. A wrong password and
///   an address without an account are both `invalidCredentials`, and
///   `sendPasswordReset` completes whether the address has an account or
///   not. `notConfigured` has the provider's `developerHint`;
/// - `linkPassword` keeps the id of the user;
/// - `deleteAccount` may fail with `recentSignInRequired`, and succeeds
///   once the user has signed in again, in whichever way. The role has no
///   call that asks for the password again;
/// - a call for a user whose session has ended on the server signs that
///   user out on the device and fails with `recentSignInRequired`.
///
/// Only a running app shows whether a provider keeps to it.
///
/// ## Tests
///
/// A call of `appSession` made before the first `initAuth()` waits for it,
/// and `initAuth()` completes after such calls. So a test that needs an
/// account before the app starts calls `appSession.signUp` before
/// `bootstrap()`, without awaiting it, and the app then starts with that
/// account. The tests of a module whose guard asks for an account open the
/// guard for the tests of the other modules this way. A test gives
/// `appSession.start()` a service of its own to script what a provider
/// answers, and creates an `AppSessionController` of its own to see
/// another mode.
final class AuthRole extends Role<RoleImplementation> {
  const AuthRole._();

  /// The path of the file with `AuthService`, which the provider
  /// implements.
  static const serviceFile = 'lib/core/auth/auth_service.dart';

  /// The path of the file with `appSession` and `authMode`, which the code
  /// of the app uses.
  static const sessionFile = 'lib/core/auth/app_session.dart';

  /// The path of the file with `takeGuestData`, which the developer of the
  /// app edits.
  static const guestDataFile = 'lib/core/auth/guest_data.dart';

  /// `--auth-mode`, who may use the app without an account: `required`, the
  /// default, `guest` or `anonymous`, the names of the [AuthMode]s.
  static const modeOption = RoleOption.mode(
    name: 'auth-mode',
    help: 'Who may use the app without an account: nobody (required, the '
        'default), everyone (guest), or everyone as an anonymous user '
        '(anonymous).',
    values: ['required', 'guest', 'anonymous'],
  );

  /// The implementation of `AuthService`, which the template renders from
  /// the provider's [RoleImplementation]; modules do not contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    authRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'auth';

  @override
  String get description => 'Authentication';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  List<RoleOption> get options => const [modeOption];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [serviceFile, sessionFile, guestDataFile],
      );

  @override
  RoleTemplate<RoleImplementation> get template => const _AuthTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'auth.factory_calls',
          description: 'Only the provider of the role calls '
              'createAuthService() or imports the file of AuthService: the '
              'code of the app signs in through appSession.',
          check: _checkAuthService,
        ),
        StructuralRule(
          id: 'auth.start_calls',
          description: 'Only bootstrap() calls initAuth().',
          check: _checkAuthStart,
        ),
        StructuralRule(
          id: 'auth.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
      ];

  /// The mode of the app: the choice of the role in [input], the input of
  /// a render hook of the role or of its provider.
  AuthMode modeIn(RoleHookInput<RoleImplementation> input) =>
      input.choice! as AuthMode;
}

/// What the owner of a file does rather than reach the service of the
/// provider.
const _sessionHint = 'Sign in, up and out through appSession of '
    '${AuthRole.sessionFile}, which also exports AuthFailure and '
    'AuthFailureReason.';

/// The problems with the service of the provider in [input]: a file of a
/// module that does not provide the role, or of the template of another
/// role, that calls `createAuthService()` or imports the file of
/// `AuthService`.
///
/// Such code would sign in around the session, which is what links an
/// anonymous user on sign-up, moves the data of a guest and turns every
/// error into an `AuthFailure`.
List<SmfIssue> _checkAuthService(
  StructuralRuleInput<RoleImplementation> input,
) {
  final issues = <SmfIssue>[];
  for (final MapEntry(key: path, value: index) in input.files.entries) {
    final owner = input.owners[path];
    final mayUse = switch (owner) {
      ModuleOrigin(:final module) =>
        input.module(module)?.provides.contains(authRole) ?? false,
      RoleTemplateOrigin(:final role) => identical(role, authRole),
      _ => true,
    };
    if (mayUse) continue;
    if (usesSymbols(index, {'createAuthService'}, AuthRole.sessionFile)) {
      issues.add(
        SmfIssue(
          '$path calls createAuthService(), which only the provider of the '
          '$authRole may call.',
          hint: _sessionHint,
          origin: owner,
          path: path,
        ),
      );
    }
    if (importsLibrary(index, AuthRole.serviceFile)) {
      issues.add(
        SmfIssue(
          '$path imports ${AuthRole.serviceFile}, the file of AuthService, '
          'which only the provider of the $authRole implements.',
          hint: _sessionHint,
          origin: owner,
          path: path,
        ),
      );
    }
  }
  return issues;
}

/// The problems with the calls of `initAuth()` in [input]: one in any file
/// of the app but that of `bootstrap()`, which awaits it once, before the
/// first frame.
List<SmfIssue> _checkAuthStart(
  StructuralRuleInput<RoleImplementation> input,
) =>
    [
      for (final MapEntry(key: path, value: index) in input.files.entries)
        if (path != AppEntryRole.bootstrapFile &&
            usesSymbols(index, {'initAuth'}, AuthRole.sessionFile))
          SmfIssue(
            '$path calls initAuth(), which only bootstrap() calls.',
            hint: 'The role starts the session in bootstrap(), before the '
                'first frame. Read who is signed in from appSession.',
            origin: input.owners[path],
            path: path,
          ),
    ];

final class _AuthTemplate extends _ServiceTemplate {
  const _AuthTemplate();

  @override
  Role<RoleImplementation> get role => authRole;

  @override
  MasonBundle get bundle => authRoleBundle;

  @override
  String get file => AuthRole.sessionFile;

  @override
  String get service => 'AuthService';

  @override
  String get factory => 'createAuthService';

  @override
  String get initFunction => 'initAuth';

  @override
  String get variable => '_authService';

  @override
  SocketRef<CodeSocket> get implementations => AuthRole.implementations;

  /// The note of the role in the guide for coding agents: that the code of
  /// an app signs in through the session, how it shows a failure, what the
  /// mode does and does not do, where the data of a guest moves, and which
  /// functions of the role are not for the code of the app.
  @override
  String get agentNote => '''
- `appSession` in `$file` tells who uses the app, and knows it before the first frame. Its `value` is a `SignedOutSession`, an `AnonymousSession` or an `AccountSession`, and `appSession.value.uid` is the id of the user. Sign in, sign up, sign out and delete the account only through `appSession`. The app has one, so create no other `AppSessionController`.
- A call of `appSession` fails only with an `AuthFailure`. Catch it and show a text of the app for its `reason`. Show its `developerHint` in debug mode only. After `recentSignInRequired`, tell the user to sign out and sign in again.
- `authMode` in that file says who may use the app without an account. It gates nothing on its own. What keeps a user from a screen is a guard of the routes, which reads `appSession.allowsApp`, or `appSession.hasAccount` for a screen that needs an account. In an app without such a guard every screen is open, whatever the mode. A screen does not redirect itself.
- When an anonymous user signs in to an account that exists already, `takeGuestData()` in `${AuthRole.guestDataFile}` says what moves from that user to the account. As generated it moves nothing: write there what the app keeps under the id of a user.
- A new provider implements `$service` of `${AuthRole.serviceFile}`. In the code of the app, do not call `$initFunction()` or `$factory()`, and do not import that file: `$file` exports `AuthFailure` and `AuthFailureReason`.
''';

  /// The brick and the note of the role. The role registers nothing in a DI
  /// container: the code of an app reaches sign-in through `appSession`,
  /// not through the service of the provider.
  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(agentNote),
        ),
      ];

  /// The mode of the app: the value of [AuthRole.modeOption], or its first
  /// value, which the question offers first and which a run without a
  /// terminal takes without asking.
  @override
  Future<Object?> choose(RoleChoiceContext<RoleImplementation> context) async {
    final given = context.option(AuthRole.modeOption.name);
    if (given != null) return AuthMode.values.byName(given);
    final environment = context.environment;
    if (!environment.interactive) return AuthMode.values.first;
    return environment.prompter.select<AuthMode>(
      'Who may use the app without an account?',
      AuthMode.values,
      display: (mode) => mode.label,
      defaultValue: AuthMode.values.first,
    );
  }

  @override
  Map<String, String> optionsOf(Object? choice) =>
      {AuthRole.modeOption.name: (choice! as AuthMode).name};

  /// The implementation, and the mode of the app as the value of the
  /// constant `authMode`.
  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) => RoleOutput(
        fragments: super.render(input).fragments,
        vars: {'auth_mode': 'AuthMode.${authRole.modeIn(input).name}'},
      );

  /// `bootstrap()` always awaits `initAuth()`, which also starts the
  /// session, whether the implementation is created asynchronously or not.
  @override
  String bootstrap({required bool hasAsync}) => 'await $initFunction();';

  /// The service of the provider, and `initAuth()`, which creates it with
  /// the only implementation in [all] and starts the session of the app
  /// with it.
  ///
  /// It may run again, so the variable is not final.
  @override
  String _single(List<_Prefixed> all) {
    final (:implementation, :prefix) = all.single;
    final factory = implementation.factory.codeWith(prefix);
    final create = implementation.isAsync ? 'await $factory()' : '$factory()';
    return '''
late $service $variable;

/// Creates the service of the provider of sign-in and starts the session of
/// the app with it; `bootstrap()` awaits it before the first frame, and
/// nothing else in the app calls it.
///
/// It may run again, as a test does to see what the next launch of the app
/// finds: it creates the service anew, with the user who is signed in, and
/// starts the session with it.
Future<void> $initFunction() async {
  $variable = $create;
  await appSession.start($variable);
}''';
  }
}
