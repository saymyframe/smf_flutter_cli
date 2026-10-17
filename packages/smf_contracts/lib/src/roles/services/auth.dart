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
/// The role's template generates four files, whichever module provides
/// the role:
/// - [serviceFile] with `AuthService`, the interface that the provider
///   implements, `AuthUser`, `AuthFailure` with its `AuthFailureReason`,
///   and the sealed `SignInCredential` with `IdTokenCredential`;
/// - [sessionFile] with `appSession`, the `AppSessionController` of the
///   app, the sealed `AppSession` with `SignedOutSession`,
///   `AnonymousSession` and `AccountSession`, and `authMode`, the mode of
///   the app as an `AuthMode`. The file exports `AuthFailure`,
///   `AuthFailureReason`, `SignInCredential` and `IdTokenCredential`, so
///   the code of the app imports this file alone;
/// - [guestDataFile] with `takeGuestData`, which the developer of the app
///   edits;
/// - [methodsFile] with the class [signInMethod] and the list
///   [appSignInMethods] of the ways to sign in with an identity provider
///   that the modules of the app give the role; see below.
///
/// The provider contributes its implementation of `AuthService` as an
/// [AuthImplementation], created with the app or asynchronously.
///
/// The template also writes the section [readmeHeading] of the README of
/// the app, from its render hook, since the section tells the mode of the
/// app: what each mode means, that the mode gates nothing on its own and
/// which guard keeps a user from what, how to change the mode, and where
/// the data of a guest moves. A provider tells in a section of its own
/// what its side needs for a mode. In the guide for coding agents of the
/// app, the template writes the note of the role under its description.
///
/// ## The session
///
/// The code of an app reaches sign-in only through `appSession`, a
/// `ValueListenable<AppSession>`: its `signIn`, `signUp`, `signInWith`,
/// `sendPasswordReset`, `signOut` and `deleteAccount` call the service and
/// do what is the same with every provider. No module, and no template of
/// another role, calls `createAuthService()` or `appSession.start()`, and
/// only the file of the provider's implementation imports [serviceFile].
/// The role registers nothing in a DI container: `appSession` is a
/// top-level variable, which a guard of the routes reads synchronously and
/// which the state of a screen takes as it is.
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
/// sign-up finds the anonymous user that it gives the account. A start of
/// the session after the first one takes its turn among the calls too.
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
///   most 3 seconds, also when the user comes back to the app meanwhile.
///   When it fails or takes longer, the app starts without a user and
///   tries again each time the user comes back to the app, and after each
///   call that leaves nobody signed in: a sign-out or the deletion of an
///   account, which wait for it as the start does, and a call that failed
///   after the provider signed the user out, which does not, so that its
///   failure is not late. `signUp` then gives the anonymous user the
///   account, with the same id. An anonymous user whom the provider has on
///   the device in another mode gets the account in the same way.
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
/// The declaration of `authMode` keeps the form in which the template
/// writes it, `const AuthMode authMode = AuthMode.required;`, on a line
/// that it starts, and the developer of the app changes the mode there. So
/// a tool of the app that `dart` runs, which cannot load a file that
/// imports Flutter, reads the mode from the text of [sessionFile], with
/// [modeDeclaration]; [modeWrittenIn] reads it so.
///
/// ## A route that needs an account
///
/// [account] is the condition of a route whose screen is only for the user
/// of an account, such as an account screen. A feature asks for it on such
/// a route ([Route.conditions]) and lists the role among its roles. A
/// module with the screens of sign-in stands for it with a guard
/// ([RouteGuard.condition]) whose function returns
/// `appSession.hasAccount`. So the feature and the module with the guard
/// know the role and not each other.
///
/// The role uses the router role for it, so its hooks and those of its
/// provider may read the routes and the guards of the app
/// ([RouterRole.facadeOf]). When the app is generated, the template warns
/// of the routes that ask for [account] while no guard of the app stands
/// for it, each by its full name: such a route shows to every user, as the
/// router role says of a condition without a guard. An app with a provider
/// and such a feature, and without a module with the screens of sign-in,
/// is such an app. It is a warning and no error, since the developer of
/// the app may write the guard later. A gate is no guard for the
/// condition, so an app whose only guard reads `appSession.allowsApp` gets
/// the warning too: in the modes `guest` and `anonymous` that gate lets a
/// user without an account in. In an app without a router no route of a
/// module applies, and the role warns of nothing.
///
/// ## Ways to sign in
///
/// A module that requires the role, or its provider, may give it a
/// [SignInMethod]: a way to sign in with an identity provider, such as the
/// account of the user at another service, with the label and the icon of
/// its button, the platforms that it works on, the function of the module
/// that asks the identity provider for a [SignInMethod.credential], and
/// the issuer of the tokens of the identity provider. The template renders
/// the ways to sign in of the app into [appSignInMethods] of [methodsFile],
/// in the order of the modules, as the layout role renders the
/// destinations: the label is a top-level function of a `BuildContext`
/// that reads the text of the module (see [LocalizationRole.expressionOf]),
/// so the role uses the [LocalizationRole], and the list is a constant.
/// The file imports the file of the function of a way to sign in with a
/// prefix of its own, such as `method0`. In an app without ways to sign in
/// the list is empty. The hooks of the role, of its provider and of a role
/// that requires or uses the role read them with [methodsIn].
///
/// A screen of sign-in shows a button for each way to sign in of the list
/// that is available on the platform of the app. Its state calls the
/// function of the way to sign in, which returns a `SignInCredential`, or
/// `null` when the user closed the sheet of the identity provider, which is
/// no failure, and gives the credential to `appSession.signInWith`. The
/// session gives an anonymous user the identity with `linkWith` of the
/// service, so the user keeps the id. When that fails with
/// `credentialInUse` or `accountExistsWithOtherMethod`, the identity has
/// an account already, and the session signs in to it with `signInWith`
/// and the same credential, moving the data of the guest as it does for
/// `signIn`. The user of an account, and nobody, signs in with
/// `signInWith` at once.
///
/// For an account with a way to sign in that [SignInMethod.revokesOnDeletion]
/// and is available on the platform, `appSession.deleteAccount()` calls the
/// function of that way to sign in itself, within its own call, and gives
/// what it returns to `deleteAccount(fresh:)` of the service, so that the
/// provider can revoke the tokens that the identity provider gave the app.
/// When the function returns `null`, the call completes and deletes
/// nothing. So the function of a way to sign in calls no method of
/// `appSession`, which would wait for that call.
///
/// A provider reads the ways to sign in of the app in its hooks, meets what
/// each [SignInMethod.needs] from its backend, and reports in its
/// `validate` hook a way to sign in whose identity provider its backend
/// does not take. Its service fails a credential that it does not take
/// with `notConfigured`.
///
/// The App Store asks an app on iOS that offers a login service of a third
/// party to offer an equivalent one too (App Store Review Guideline 4.8).
/// The template warns of an app that does not, from the
/// [SignInMethod.appStore] of its ways to sign in
/// ([noEquivalentSignInWarning]), and the section of the role in the
/// README of the app says so too.
///
/// ## The data of a guest
///
/// When an anonymous user signs in to an account that exists already, the
/// user of the app changes. `appSession.signIn`, and `appSession.signInWith`
/// for an identity that has an account, call `takeGuestData` with the id
/// of the anonymous user before they call the service, and then call the
/// function that they got back with the id of the account. An
/// error of the first fails the call before the service is called. An
/// error of the second is reported with `FlutterError.reportError`, and
/// the call completes, since the user is signed in. `signUp` of an
/// anonymous user keeps the id, so it moves nothing. Neither function
/// calls `appSession`: the sign-in is one of its calls, which run one
/// after another, so the two would wait for each other.
///
/// ## What a provider keeps to
///
/// The contract of `AuthService` is in [serviceFile]. It is the same in
/// every mode of the app, whatever the provider renders by the mode. In
/// short:
/// - the function of the implementation returns a service whose
///   `currentUser` is the user of the device already, without a request to
///   the server, and it may be called again;
/// - when a call completes, `currentUser` is its result, and `userChanges`
///   tells of every change, also of one that no call made. When it tells
///   of a user, `currentUser` is that user. An error that the stream sends
///   changes nothing: the session reports it with
///   `FlutterError.reportError` and goes on listening;
/// - `signIn` is also called while a user is signed in, an anonymous one
///   or the user of another account, and `signUp` while the user of
///   another account is: the user of the call then replaces that user on
///   the device;
/// - every failure is an `AuthFailure`, and every call ends, with the
///   reason `network` when the server does not answer. A wrong password and
///   an address without an account are both `invalidCredentials`, and
///   `sendPasswordReset` completes whether the address has an account or
///   not. `notConfigured` has the provider's `developerHint`;
/// - `signUp` and `linkPassword` with an address that has an account fail
///   with `emailInUse` and change nothing;
/// - a call that fails leaves the user who is signed in as that user was,
///   but for the call of the last point: an anonymous user stays signed in
///   when `linkPassword` fails, and so does whoever is signed in when
///   `signIn` or `signUp` fails;
/// - `signInAnonymously` creates a user with an id of its own, and
///   `linkPassword` and `linkWith` keep the id of the user;
/// - `linkWith` of an identity that another user has fails with
///   `credentialInUse`, and of one whose email address has an account of
///   another user with `accountExistsWithOtherMethod`, and changes nothing.
///   `signInWith` then takes the same credential, which an identity
///   provider may take only once;
/// - a credential whose identity provider the provider does not take fails
///   with `notConfigured`, with the issuer in the hint;
/// - `deleteAccount(fresh:)` signs the user in again with the credential
///   first and revokes the tokens of the identity provider where it can. A
///   credential of another user fails with `invalidCredentials`, and a
///   revocation that fails with `notConfigured`, and neither deletes
///   anything;
/// - `deleteAccount` succeeds for a user who has just signed in, and for
///   an anonymous user who was just created. For a user who signed in
///   longer ago, such as one whom the service found on the device, it may
///   fail with `recentSignInRequired`, and succeeds once the user has
///   signed in again, in whichever way. The role has no call that asks for
///   the password again;
/// - `currentUser` lists the issuers of the identities of the user;
/// - a call for a user whose session has ended on the server signs that
///   user out on the device and fails with `recentSignInRequired`.
///
/// Only a running app shows whether a provider keeps to it.
///
/// ## Rules
///
/// The structural rules of the role read the index of each Dart file of
/// an app, so they see what a file itself imports and calls:
/// - `auth.factory_calls`: no file of a module, and none of the template of
///   another role, calls `createAuthService()`, and of such files only
///   those of the provider's implementation, the files of its class and of
///   its function, import or export [serviceFile]. So a widget of a
///   provider signs in through `appSession` too;
/// - `auth.start_calls`: only the file of `bootstrap()` calls `initAuth()`,
///   and no file of a module or of the template of another role calls
///   `appSession.start()`, which `initAuth()` and tests call;
/// - `auth.implementation_factories`: the function of the implementation
///   is in its file and takes no arguments;
/// - `auth.method_functions`: the function of every way to sign in is a
///   top-level function in a file of its module that takes no arguments,
///   returns a `Future` of a credential that may be `null`, and whose file
///   does not use `appSession`.
///
/// The module rule `auth.methods` checks the ways to sign in of a module:
/// only a module that requires or provides the role gives one, with a
/// label, an icon, platforms and an issuer of an https URL, a function in
/// a file that the bricks of the module generate, and each issuer once.
/// The template reports two modules with ways to sign in of one issuer.
///
/// They do not see a `part` file of a library that imports [sessionFile],
/// a file that reaches [sessionFile] through an export of another file of
/// the app, or `appSession` under another name, such as a variable that it
/// was assigned to.
///
/// ## Tests
///
/// A call of `appSession` made before the first `initAuth()` waits for it,
/// and `initAuth()` completes after such calls. So a test that needs an
/// account before the app starts calls `appSession.signUp` before
/// `bootstrap()`, without awaiting it, and the app then starts with that
/// account. It makes the call outside the body of a test, as in a
/// `setUpAll`: a call made in the body of a widget test waits in the fake
/// time of that body, and a start that runs in real time then never
/// completes. The tests of a module whose guard asks for an account open
/// the guard for the tests of the other modules this way. A test gives
/// `appSession.start()` a service of its own to script what a provider
/// answers, and creates an `AppSessionController` of its own to see
/// another mode. A test that brings the user back to the app may go
/// through any state of the lifecycle: the session looks only at
/// `AppLifecycleState.resumed`.
final class AuthRole extends Role<AuthData> {
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

  /// The path of the file with [signInMethod] and [appSignInMethods].
  static const methodsFile = 'lib/core/auth/sign_in_methods.dart';

  /// The class of a way to sign in in the app, which the role's template
  /// generates: `SignInMethod(label: ..., icon: ..., platforms: ...,
  /// credential: ..., issuer: ..., revokesOnDeletion: ...)`, with a label of
  /// the type `String Function(BuildContext context)`, which returns the
  /// text in the language of the app, a constant `Widget` as the icon, a
  /// `Set<TargetPlatform>`, a `credential` of the type
  /// `Future<SignInCredential?> Function()`, the issuer as a `String`, and
  /// `revokesOnDeletion`, `false` unless it is given. Its getter
  /// `isAvailable` tells whether the way to sign in works on the platform
  /// that the app runs on.
  ///
  /// Its constructor is `const`, and the template creates the ways to sign
  /// in as constants in [appSignInMethods], each with top-level functions.
  static const signInMethod = RequiredClass(
    'SignInMethod',
    path: methodsFile,
    namedParameters: [
      'label',
      'icon',
      'platforms',
      'credential',
      'issuer',
      'revokesOnDeletion',
    ],
    constConstructor: true,
    getters: [
      'label',
      'icon',
      'platforms',
      'credential',
      'issuer',
      'revokesOnDeletion',
      'isAvailable',
    ],
  );

  /// The name of the list of the ways to sign in of the app, which the
  /// role's template generates in [methodsFile] as
  /// `const List<SignInMethod> appSignInMethods`: a [signInMethod] for each
  /// way to sign in of [methodsIn], in their order. The list is empty in an
  /// app whose modules give the role no way to sign in.
  static const appSignInMethods = 'appSignInMethods';

  /// The heading of the section of the README of the app in which the
  /// template tells the mode of the app and what it does. The section of a
  /// provider on what its side needs for a mode can refer to it.
  static const readmeHeading = 'Sign-in';

  /// `--auth-mode`, who may use the app without an account: `required`, the
  /// default, `guest` or `anonymous`, the names of the [AuthMode]s.
  static const modeOption = RoleOption.mode(
    name: 'auth-mode',
    help: 'Who may use the app without an account: nobody (required, the '
        'default), everyone (guest), or everyone as an anonymous user '
        '(anonymous).',
    values: ['required', 'guest', 'anonymous'],
  );

  /// A user with an account: the condition that a route asks for when its
  /// screen is only for such a user, such as an account screen
  /// ([Route.conditions]). An anonymous user has no account.
  ///
  /// A feature marks its route with it and lists the role among its roles.
  /// It knows no module with a guard. A module with the screens of sign-in
  /// stands for the condition with a guard ([RouteGuard.condition]), whose
  /// function returns `appSession.hasAccount` from a file of that module:
  /// the role has no function for a guard, since the template of the
  /// router imports the files of the modules that give it data and no file
  /// of the template of another role.
  ///
  /// In an app without a guard for it, a route that asks for it shows to
  /// every user, and the template of the role warns of each such route when
  /// the app is generated; see [AuthRole].
  static const account = RouteCondition(authRole, 'account');

  /// The code of the warning that routes of the app ask for [account] while
  /// no guard of the app stands for it, so every user gets to them.
  static const openAccountRoutesWarning = 'auth.open_account_routes';

  /// The code of the warning that the app offers a login service of a third
  /// party on iOS ([AppStoreLogin.thirdParty]) and no way to sign in that
  /// the App Store takes as its equivalent there
  /// ([AppStoreLogin.privacyFocused]), as its guideline 4.8 asks.
  static const noEquivalentSignInWarning = 'auth.no_equivalent_sign_in';

  /// The implementation of `AuthService`, which the template renders from
  /// the provider's [AuthImplementation]; modules do not contribute to it.
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

  /// The router, whose routes ask for [account]: the template of the role
  /// reads the routes and the guards of the app to warn of a route that
  /// asks for it without a guard. An app without a router has no routes,
  /// and the role works there as it is.
  ///
  /// The localization, whose texts the labels of the ways to sign in are:
  /// the template reads the label of a way to sign in from the texts of the
  /// app when its module gave them the text, and otherwise it is the
  /// English text.
  @override
  Set<Role> get uses => {routerRole, localizationRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  List<RoleOption> get options => const [modeOption];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [serviceFile, sessionFile, guestDataFile, methodsFile],
        symbols: [signInMethod],
      );

  @override
  RoleTemplate<AuthData> get template => const _AuthTemplate();

  @override
  List<ModuleRule<AuthData>> get moduleRules => const [
        ModuleRule(
          id: _implementationsRuleId,
          description: _implementationsRuleDescription,
          check: _checkImplementations,
        ),
        ModuleRule(
          id: 'auth.methods',
          description: 'Only a module that requires or provides the role '
              'gives it ways to sign in, each with a label whose texts have '
              'translations only if the module lists the localization role, '
              'an icon, platforms, an issuer that is an https URL, a '
              'function in a file of the app that the bricks of the module '
              'generate, and an issuer of its own among the ways to sign in '
              'of the module.',
          check: _checkMethods,
        ),
      ];

  @override
  List<StructuralRule<AuthData>> get structuralRules => const [
        StructuralRule(
          id: 'auth.factory_calls',
          description: 'No module calls createAuthService(), and only the '
              'files of the implementation of the provider import the file '
              'of AuthService: the code of the app signs in through '
              'appSession.',
          check: _checkAuthService,
        ),
        StructuralRule(
          id: 'auth.start_calls',
          description: 'Only bootstrap() calls initAuth(), and no module '
              'calls appSession.start().',
          check: _checkAuthStart,
        ),
        StructuralRule(
          id: 'auth.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
        StructuralRule(
          id: 'auth.method_functions',
          description: 'The function of every way to sign in is a top-level '
              'function in a file of its module that requires no arguments '
              'and returns a Future of a credential that may be null, and '
              'its file does not use appSession, which calls it within its '
              'own calls.',
          check: _checkMethodFunctions,
        ),
      ];

  /// The mode of the app: the choice of the role in [input], the input of
  /// a render hook of the role or of its provider.
  AuthMode modeIn(RoleHookInput<AuthData> input) => input.choice! as AuthMode;

  /// The ways to sign in of the app in [input], the input of a hook of this
  /// role, of its provider, or of a role that requires or uses this role,
  /// in the order of the data of the role ([RoleHookInput.data]): that of
  /// the modules, in the order the modules were selected. Those of one
  /// module keep its order.
  List<AppSignInMethod> methodsIn(RoleHookInput<Object> input) => [
        for (final data in dataIn(input))
          if (data.value case final SignInMethod method)
            // Every data that a hook gets has an origin.
            AppSignInMethod._(_methodOwnerOf(data.origin!), method),
      ];

  /// How a tool reads the mode of an app from the text of [sessionFile]:
  /// the source of a regular expression for a search over the lines of the
  /// file, `RegExp(AuthRole.modeDeclaration, multiLine: true)`.
  ///
  /// A provider whose side has to be set up for the mode, such as with a
  /// way to sign in that only one mode needs, may give the app a tool for
  /// that, a script that `dart` runs. `dart` cannot load [sessionFile],
  /// which imports Flutter. And the mode that the render hook of the
  /// provider knows ([modeIn]) is the one that the app was generated in,
  /// which a script would have wrong from the first time the developer of
  /// the app changes `authMode`. So such a tool reads the declaration.
  ///
  /// Each match of the expression is a comment of the file, or a
  /// declaration of `authMode` that starts its line and has a mode as its
  /// value. Only a declaration has the first group, the name of its mode.
  /// The file tells the mode when exactly one match has that group; a tool
  /// stops otherwise, rather than guess. [modeWrittenIn] reads the mode so.
  ///
  /// The expression takes the declaration as the template writes it and as
  /// `dart format` leaves it, and as a developer may leave it: without the
  /// type, with `final`, with its value on the next line, and with a
  /// comment after it. It takes no value that is not the name of an
  /// [AuthMode], no computed value, no declaration within a comment, and
  /// none that does not start its line, as that of a local variable. It
  /// follows a block comment within a block comment, but not one within
  /// that.
  static final String modeDeclaration =
      // A block comment, which may have block comments within it.
      r'/\*(?:[^*/]|\*(?!/)|/(?!\*)|/\*(?:[^*]|\*(?!/))*\*/)*\*/'
      // A comment to the end of its line.
      r'|//[^\n]*'
      // The declaration, which starts its line.
      r'|^(?:const|final)\s+(?:AuthMode\s+)?authMode\s*=\s*AuthMode\.'
      '(${[for (final mode in AuthMode.values) mode.name].join('|')})'
      r'\s*;';

  /// The mode that [source], the text of [sessionFile] of an app, declares
  /// as `authMode`, or `null` if it does not tell the mode: it has no
  /// declaration that [modeDeclaration] takes, or more than one.
  AuthMode? modeWrittenIn(String source) {
    final declared = [
      for (final match
          in RegExp(modeDeclaration, multiLine: true).allMatches(source))
        if (match[1] case final name?) name,
    ];
    return declared.length == 1
        ? AuthMode.values.byName(declared.single)
        : null;
  }
}

/// What the [AuthRole] takes from the modules of the app: the
/// [AuthImplementation] of its provider, and a [SignInMethod] for each way
/// to sign in with an identity provider that a module gives it.
@immutable
sealed class AuthData {
  const AuthData();
}

/// The implementation of `AuthService` that the provider of the [AuthRole]
/// contributes, created with the app or asynchronously, as a
/// [RoleImplementation] is for the other service roles:
///
/// ```dart
/// authRole.data(
///   const AuthImplementation(
///     type: TypeRef('BackendAuthService', import: file),
///     create: FactoryRef('createBackendAuthService', import: file),
///   ),
/// )
/// ```
@immutable
final class AuthImplementation extends AuthData {
  /// An implementation of [type] that [create] returns.
  const AuthImplementation({
    required this.type,
    required FactoryRef this.create,
  }) : init = null;

  /// An implementation of [type] created asynchronously: [init] returns a
  /// `Future` of it, which `initAuth()` awaits in the platform phase of
  /// `bootstrap()`.
  const AuthImplementation.async({
    required this.type,
    required FactoryRef this.init,
  }) : create = null;

  /// The class of the implementation.
  final TypeRef type;

  /// The function that returns the implementation, if it is created
  /// synchronously.
  final FactoryRef? create;

  /// The function that returns a `Future` of the implementation, if it is
  /// created asynchronously.
  final FactoryRef? init;

  /// The implementation as the service roles take one.
  RoleImplementation get implementation => switch (init) {
        final init? => RoleImplementation.async(type: type, init: init),
        null => RoleImplementation(type: type, create: create!),
      };

  @override
  String toString() => 'implementation $type';
}

/// A platform that an app runs on, as a [SignInMethod] names those that it
/// works on.
enum AppPlatform {
  /// Android.
  android,

  /// iOS.
  ios,
}

/// What a way to sign in is for the App Store, whose guideline 4.8 asks an
/// app on iOS that offers a login service of a third party to offer an
/// equivalent one too. The template of the [AuthRole] warns of an app that
/// does not ([AuthRole.noEquivalentSignInWarning]).
enum AppStoreLogin {
  /// A login service of a third party, such as the account of the user at
  /// another service.
  thirdParty,

  /// A login service that the App Store takes as the equivalent of one of
  /// a third party: one that asks for no more than the name and the email
  /// address of the user, lets the user keep the address private, and
  /// collects no interactions with the app for advertising without the
  /// consent of the user.
  privacyFocused,
}

/// What a way to sign in needs from the backend of the provider of the
/// [AuthRole], which the provider sets up, such as with a step after the
/// app is generated, or tells the developer of the app in its section of
/// the README. A provider whose backend cannot meet a need reports the way
/// to sign in in its `validate` hook.
enum SignInNeed {
  /// The identity provider knows the Android app by the name of its package
  /// and the fingerprint of each certificate that signs it.
  androidCertificate,

  /// The identity provider has a client for the iOS app, whose id the way
  /// to sign in finds where the provider of sign-in puts it, and whose
  /// reversed id is a URL scheme of the app.
  iosClient,

  /// The identity provider issues the token to the server client of the
  /// backend, whose id the way to sign in finds where the provider of
  /// sign-in puts it.
  serverClient,
}

/// A way to sign in with an identity provider, such as the account of the
/// user at another service, which a module that requires the [AuthRole]
/// gives the role:
///
/// ```dart
/// authRole.data(
///   const SignInMethod(
///     label: LocalizedText('label', en: 'Continue with Example'),
///     icon: Fragment(
///       'Icon(Icons.key)',
///       imports: [ImportRef('package:flutter/material.dart')],
///     ),
///     platforms: {AppPlatform.android, AppPlatform.ios},
///     credential: FunctionRef(
///       'exampleCredential',
///       import: ImportRef.app('core/example_sign_in/example_sign_in.dart'),
///     ),
///     issuer: 'https://accounts.example.com',
///     appStore: AppStoreLogin.thirdParty,
///   ),
/// )
/// ```
///
/// The template of the role renders it into `appSignInMethods` of
/// [AuthRole.methodsFile] (see [AuthRole]). The module generates the file
/// of its function in a brick of its own; the module rule `auth.methods`
/// reports a function in a file that the bricks of the module do not
/// generate.
///
/// The label is a text of the module (see [DataWithTexts]). A module that
/// lists the [LocalizationRole] among its roles gives that role the text
/// too, and the app shows it in its language.
@immutable
final class SignInMethod extends AuthData implements DataWithTexts {
  /// Creates a way to sign in with the identity provider [issuer].
  const SignInMethod({
    required this.label,
    required this.icon,
    required this.platforms,
    required this.credential,
    required this.issuer,
    required this.appStore,
    this.needs = const {},
    this.revokesOnDeletion = false,
  });

  /// The label of the button, such as `Continue with Example`.
  final LocalizedText label;

  /// The icon of the button, a constant expression of the type `Widget`
  /// with the imports it needs: an `Icon`, which takes the colour of the
  /// label, such as `Icon(Icons.key)` of `package:flutter/material.dart`,
  /// or an image of the module, which keeps its own colours.
  final Fragment icon;

  /// The platforms that the way to sign in works on. The app shows its
  /// button on no other.
  final Set<AppPlatform> platforms;

  /// The function that asks the identity provider for a credential: a
  /// top-level function of a file of the app that the module generates,
  /// which requires no arguments and returns a `Future<SignInCredential?>`
  /// of `AuthRole.sessionFile`, or `null` when the user closed the sheet of
  /// the identity provider. It fails only with an `AuthFailure`, and calls
  /// no method of `appSession`, which calls it within its own calls when it
  /// deletes an account.
  ///
  /// The template of the role imports the file with a prefix of its own,
  /// so [ImportRef.prefix] and [ImportRef.show] do not apply.
  final FunctionRef credential;

  /// The identity provider: the issuer of its tokens, an https URL such as
  /// `https://accounts.example.com`, by which `AuthUser.issuers` names it
  /// and a provider of the role tells the identity providers that its
  /// backend takes.
  final String issuer;

  /// What the way to sign in is for the App Store.
  final AppStoreLogin appStore;

  /// What the way to sign in needs from the backend of the provider of the
  /// role.
  final Set<SignInNeed> needs;

  /// Whether the deletion of an account that signs in this way asks the
  /// identity provider for a credential again first, so that the provider
  /// of the role can revoke the tokens that the identity provider gave the
  /// app, as an identity provider may ask of an app.
  final bool revokesOnDeletion;

  /// The text of the way to sign in that a user sees: its label.
  @override
  Iterable<LocalizedText> get shownTexts => [label];

  /// Describes what is wrong with the way to sign in on its own, apart from
  /// its label, or returns an empty list.
  List<String> problems() {
    final what = 'The way to sign in of $issuer';
    final uri = Uri.tryParse(issuer);
    final problems = <String>[];
    if (uri == null ||
        !uri.isScheme('https') ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      problems.add(
        'The issuer "$issuer" of a way to sign in must be an https URL '
        'without a query or a fragment, such as '
        'https://accounts.example.com, as the identity provider writes it '
        'into its tokens.',
      );
    }
    if (icon.isWrapper || icon.code.trim().isEmpty) {
      problems.add(
        '$what has an icon that is not an expression, such as '
        'Icon(Icons.key).',
      );
    }
    problems.addAll(icon.problems());
    if (platforms.isEmpty) {
      problems.add('$what names no platform that it works on.');
    }
    problems.addAll(credential.problems());
    if (!credential.import.isAppFile) {
      problems.add(
        'The function ${credential.name} of the way to sign in of $issuer '
        'must be a function of a file of the app, imported with '
        'ImportRef.app.',
      );
    }
    return problems;
  }

  @override
  String toString() => 'way to sign in of $issuer';
}

/// A way to sign in of an app: a [SignInMethod] with the module that gave
/// it.
///
/// Obtain the ways to sign in of an app with [AuthRole.methodsIn].
@immutable
final class AppSignInMethod {
  const AppSignInMethod._(this.owner, this.method);

  /// Who gave the app the way to sign in: a module, also for a way to sign
  /// in of its variant. The label is a text of the owner, such as for
  /// [LocalizationRole.appTextOf].
  final ContributionOrigin owner;

  /// The way to sign in.
  final SignInMethod method;

  @override
  String toString() => '$method of $owner';
}

/// Who owns the ways to sign in that [origin] gave: a variant of a module
/// gives those of its module.
ContributionOrigin _methodOwnerOf(ContributionOrigin origin) =>
    switch (origin) {
      ModuleOrigin(:final module) => ModuleOrigin(module),
      _ => origin,
    };

/// The path of the file of [function] relative to the project root, such
/// as `lib/core/example_sign_in/example_sign_in.dart`, or `null` if it is
/// not of a file of the app.
String? _methodFileOf(FunctionRef function) =>
    function.import.isAppFile ? 'lib/${function.import.uri}' : null;

/// The problems of the ways to sign in of the module of [input], which the
/// module rule `auth.methods` reports: a module that neither requires nor
/// provides the role, those of each way to sign in on its own, those of
/// its label for the module (see [LocalizationRole.dataTextProblems]), a
/// function in a file that the bricks of the module, those that apply in
/// the app, do not generate, and two ways to sign in of one issuer.
List<SmfIssue> _checkMethods(ModuleRuleInput<AuthData> input) {
  final module = input.module;
  final origin = ModuleOrigin(module.id);
  final methods = [
    for (final data in input.data)
      if (data.value case final SignInMethod method) method,
  ];
  if (methods.isEmpty) return const [];
  final generated = textTemplatesOf(input.contributions);
  final issuers = <String>{};
  return [
    if (!module.requires.contains(authRole) &&
        !module.provides.contains(authRole))
      SmfIssue(
        'The module gives the $authRole a way to sign in, but neither '
        'requires nor provides the role, so its function would be in an app '
        'without the files of the role that it uses.',
        hint: 'Add the role to the requires of the module.',
        origin: origin,
      ),
    for (final method in methods) ...[
      for (final problem in [
        ...method.problems(),
        ...localizationRole.dataTextProblems(module, method.label),
        if (!issuers.add(method.issuer))
          'The module gives two ways to sign in of ${method.issuer}.',
      ])
        SmfIssue(problem, origin: origin),
      if (_methodFileOf(method.credential) case final path?
          when !generated.containsKey(path))
        SmfIssue(
          'The function ${method.credential.name} of the way to sign in of '
          '${method.issuer} is in $path, which the bricks of the module do '
          'not generate.',
          hint: 'Generate the file of the function in a brick of the module.',
          origin: origin,
          path: path,
        ),
    ],
  ];
}

/// Whether [type], the return type of a function as written, is a
/// `Future` of a type that may be `null`, such as
/// `Future<SignInCredential?>`, which the function of a way to sign in
/// returns: a credential, or `null` when the user closed the sheet of the
/// identity provider.
bool _returnsCredential(String? type) {
  final written = type?.replaceAll(RegExp(r'\s+'), '');
  return written != null &&
      written.startsWith('Future<') &&
      written.endsWith('?>');
}

/// The problems with the functions that the ways to sign in of [input]
/// name: a function in a file of another module, a function missing from
/// its file, one that requires arguments or does not return a `Future` of a
/// credential that may be `null`, and a file of such a function that uses
/// `appSession`, which calls the function within its own calls when it
/// deletes an account, so that a call of `appSession` there would wait for
/// itself.
///
/// The module rule `auth.methods` reports a function outside the app.
List<SmfIssue> _checkMethodFunctions(StructuralRuleInput<AuthData> input) {
  final issues = <SmfIssue>[];
  for (final data in input.roleInput.data) {
    final origin = data.origin;
    if (data.value case SignInMethod(:final credential, :final issuer)) {
      final path = _methodFileOf(credential);
      if (path == null) continue;
      final owner = input.owners[path];
      if (owner != null && !isContributor(owner, origin)) {
        issues.add(
          SmfIssue(
            'The function ${credential.name} of the way to sign in of '
            '$issuer of $origin is in $path, a file of $owner; a way to sign '
            'in calls a function of its own module.',
            origin: origin,
            path: path,
          ),
        );
        continue;
      }
      const hint = 'The screens of sign-in and appSession.deleteAccount() '
          'call it without arguments, and await a credential or null.';
      final symbol = RequiredFunction(credential.name, path: path);
      final problems = [
        for (final issue in symbol.checkIn(input.files)) issue.message,
      ];
      final file = input.files[path];
      final declaration = file?.declaration(credential.name);
      if (declaration?.kind == DeclarationKind.function &&
          !_returnsCredential(declaration!.type)) {
        problems.add(
          '$symbol in $path must return a Future of a credential that may be '
          'null, such as Future<SignInCredential?>, not '
          '${declaration.type ?? 'an undeclared type'}.',
        );
      }
      for (final problem in problems) {
        issues.add(SmfIssue(problem, hint: hint, origin: origin, path: path));
      }
      if (file != null &&
          usesSymbols(file, {'appSession'}, AuthRole.sessionFile)) {
        issues.add(
          SmfIssue(
            '$path, the file of the function ${credential.name} of the way to '
            'sign in of $issuer, uses appSession, which calls that function '
            'within its own calls when it deletes an account, so a call of '
            'appSession there would wait for itself.',
            hint: 'Return the credential, and let the state of the screen give '
                'it to appSession.signInWith.',
            origin: origin,
            path: path,
          ),
        );
      }
    }
  }
  return issues;
}

/// The name of the function of [AuthRole.methodsFile] that returns [label],
/// the label of a way to sign in of [owner], for a `BuildContext`: the id
/// of the owner and the name of the text in lowerCamelCase, after an
/// underscore, such as `_exampleSignInLabel`, and then a number if [names],
/// the names that the functions before have, has that name already. The
/// name goes into [names].
String _labelFunctionOf(
  ContributionOrigin owner,
  LocalizedText label,
  Set<String> names,
) {
  final base = '_${SmfNames.lowerCamelCase('$owner')}'
      '${SmfNames.upperCamelCase(label.name)}';
  var name = base;
  for (var number = 2; !names.add(name); number++) {
    name = '$base$number';
  }
  return name;
}

/// What the owner of a file does rather than reach the service of the
/// provider.
const _sessionHint = 'Sign in, up and out through appSession of '
    '${AuthRole.sessionFile}, which also exports AuthFailure and '
    'AuthFailureReason.';

/// What the owner of a file does rather than start the session.
const _startHint = 'The role starts the session in bootstrap(), before the '
    'first frame. Read who is signed in from appSession.';

/// The problems with the service of the provider in [input]; see
/// [_checkServiceReach].
///
/// Code that reached the service would sign in around the session, which
/// is what links an anonymous user on sign-up, moves the data of a guest
/// and turns every error into an `AuthFailure`.
List<SmfIssue> _checkAuthService(StructuralRuleInput<AuthData> input) =>
    _checkServiceReach(
      input,
      factory: 'createAuthService',
      service: 'AuthService',
      serviceFile: AuthRole.serviceFile,
      controllerFile: AuthRole.sessionFile,
      hint: _sessionHint,
    );

/// The problems with the start of the session in [input]; see
/// [_checkControllerStart].
List<SmfIssue> _checkAuthStart(StructuralRuleInput<AuthData> input) =>
    _checkControllerStart(
      input,
      init: 'initAuth',
      controller: 'appSession',
      controllerFile: AuthRole.sessionFile,
      hint: _startHint,
    );

/// A warning of the routes of the app in [input] that ask for
/// [AuthRole.account] while no guard of the app stands for it, or nothing
/// for an app without such routes or with such a guard.
///
/// Such a route shows to every user, as the router role says of a
/// condition without a guard: the app has a provider of sign-in and a
/// feature with a screen for users with an account, and no module with the
/// screens of sign-in, whose guard stands for the account. It is a warning
/// and no error, since the developer of the app may write the guard later.
/// It names every route that is open, the routes below a route that asks
/// among them.
///
/// In an app without a router, the routes of the modules do not apply, so
/// the role finds none that ask.
List<SmfIssue> _openAccountRoutes(RoleHookInput<AuthData> input) {
  final facade = routerRole.facadeOf(input);
  final asking = facade.routesAsking(AuthRole.account);
  if (asking.isEmpty || facade.guardFor(AuthRole.account) != null) {
    return const [];
  }
  final names = [for (final route in asking) route.fullName].join(', ');
  final one = asking.length == 1;
  return [
    SmfIssue.warning(
      '${one ? 'The route $names is' : 'The routes $names are'} for users '
      'with an account (${one ? 'it asks' : 'they ask'} for the condition '
      '${AuthRole.account}), but no module of the app has a guard for that '
      'condition, so every user gets to ${one ? 'it' : 'them'}.',
      code: AuthRole.openAccountRoutesWarning,
      hint: 'Add a module with the screens of sign-in to the app, or keep '
          'the other users away later with a guard of your own that reads '
          'appSession.hasAccount.',
    ),
  ];
}

/// The section of the role in the README of an app in [mode]: the mode of
/// the app and where it is written, what each mode means, that the mode
/// gates nothing on its own, which guard keeps a user from the whole app
/// and which from the screens that need an account, how to change the
/// mode, and where the data of a guest moves. It holds with every provider
/// and names none.
///
/// It is the same in an app with a guard for [AuthRole.account] and in one
/// without: the warning of [_openAccountRoutes] names the routes that are
/// open, and the section only tells that there was one.
///
/// It ends with the ways to sign in of the app in [methods] (see
/// [_methodsSection]).
String _readmeSection(AuthMode mode, List<AppSignInMethod> methods) => '''
The sign-in mode of the app says who may use it without an account. This app was generated in the mode `${mode.name}`: `authMode` in `${AuthRole.sessionFile}` is `AuthMode.${mode.name}`.

- In `${AuthMode.required.name}`, nobody may. `appSession.allowsApp` is true only for a user who signed in to an account.
- In `${AuthMode.guest.name}`, everyone may. The app has no user until someone signs in, and `appSession.allowsApp` is always true.
- In `${AuthMode.anonymous.name}`, everyone may, as an anonymous user that the app signs in itself when it starts. Code then has the id of a user, `appSession.value.uid`, before anyone has an account, and signing up gives that same user the account. The app waits up to 3 seconds for that sign-in. When it fails or takes longer, the app starts without a user and tries again each time the user comes back to it. `appSession.allowsApp` is always true.

The mode keeps nobody from a screen on its own. A guard of the routes does. One that reads `appSession.allowsApp` stands before the whole app. One that reads `appSession.hasAccount` stands only before the routes that it lists, the screens that need an account. A module with the screens of sign-in declares such guards. If the app was generated without such a module, every screen is open in every mode, `${AuthMode.required.name}` too, until you write a guard of your own that reads `appSession.allowsApp`. A screen that a module made for users with an account is open then too. A warning named each such route when the app was generated, and a guard of your own for them reads `appSession.hasAccount`.

To change the mode, change the value of `authMode`. The provider of sign-in has to allow what the new mode needs, such as anonymous users for the mode `${AuthMode.anonymous.name}`. Where the provider has a section in this README, that section tells how.

When an anonymous user signs in to an account that exists already, the user of the app changes, and what the app keeps under the id of the anonymous user would be left behind. `takeGuestData()` in `${AuthRole.guestDataFile}` says what moves to the account. As generated it moves nothing.

${_methodsSection(methods)}''';

/// The platforms in [platforms] as a sentence names them, such as
/// `Android and iOS`.
String _platformsOf(Set<AppPlatform> platforms) => [
      for (final platform in AppPlatform.values)
        if (platforms.contains(platform))
          switch (platform) {
            AppPlatform.android => 'Android',
            AppPlatform.ios => 'iOS',
          },
    ].join(' and ');

/// The ways to sign in of the app in [methods] for the section of the role
/// in the README of the app: the label of each in English with the
/// platforms that it works on, and what its deletion asks; or, in an app
/// without ways to sign in, where one goes. When the App Store would ask
/// the app for a way to sign in of its own on iOS, as the warning of
/// [_noEquivalentSignIn] tells, the section says that too.
String _methodsSection(List<AppSignInMethod> methods) {
  const list = '`${AuthRole.appSignInMethods}` in `${AuthRole.methodsFile}`';
  if (methods.isEmpty) {
    return 'Besides an email address and a password, the app signs in with '
        'no identity provider, such as the account of a user at another '
        'service. Such a way to sign in is a `SignInMethod` of $list, which '
        'the module of the way to sign in adds.\n';
  }
  final buffer = StringBuffer(
    'Besides an email address and a password, the app signs in with these '
    'identity providers, the ways to sign in of $list:\n\n',
  );
  for (final AppSignInMethod(:method) in methods) {
    buffer.write('- ${method.label.en}, on ${_platformsOf(method.platforms)}.');
    if (method.revokesOnDeletion) {
      buffer.write(
        ' Deleting an account that signs in this way asks the identity '
        'provider for a credential again first, so that the provider of '
        'sign-in can revoke the tokens that it gave the app. If the user '
        'closes its sheet, nothing is deleted.',
      );
    }
    buffer.writeln();
  }
  buffer
    ..writeln()
    ..writeln(
      'A screen of sign-in shows the button of a way to sign in only on the '
      'platforms that it works on. When an anonymous user signs in this way, '
      'the user gets the identity and keeps the id if no account has it yet, '
      'and otherwise signs in to that account, as with a password, and '
      '`takeGuestData()` moves what the anonymous user had.',
    );
  if (_withoutEquivalent(methods).isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(
        'On iOS, the App Store asks an app that offers a login service of a '
        'third party to offer an equivalent one too, one that asks for no '
        'more than the name and the email address of the user and lets the '
        'user keep the address private (App Store Review Guideline 4.8). '
        'This app offers none on iOS, so the review may reject it until it '
        'does.',
      );
  }
  return '$buffer';
}

/// The ways to sign in among [methods] that are login services of a third
/// party on iOS, when none of [methods] is one that the App Store takes as
/// their equivalent on iOS, or nothing otherwise.
List<SignInMethod> _withoutEquivalent(List<AppSignInMethod> methods) {
  bool onIos(SignInMethod method, AppStoreLogin login) =>
      method.appStore == login && method.platforms.contains(AppPlatform.ios);
  final ofMethods = [for (final placed in methods) placed.method];
  if (ofMethods.any((method) => onIos(method, AppStoreLogin.privacyFocused))) {
    return const [];
  }
  return [
    for (final method in ofMethods)
      if (onIos(method, AppStoreLogin.thirdParty)) method,
  ];
}

/// A warning of the ways to sign in of the app in [input] that are login
/// services of a third party on iOS, when the app has no way to sign in
/// that the App Store takes as their equivalent there, as its guideline 4.8
/// asks; or nothing otherwise. It names each by its label in English, and
/// no module, since the warning is about what the app is made of.
List<SmfIssue> _noEquivalentSignIn(RoleHookInput<AuthData> input) {
  final alone = _withoutEquivalent(authRole.methodsIn(input));
  if (alone.isEmpty) return const [];
  final labels = [for (final method in alone) method.label.en];
  final named = labels.length == 1
      ? labels.single
      : '${labels.sublist(0, labels.length - 1).join(', ')} and '
          '${labels.last}';
  final services = labels.length == 1
      ? 'a login service of a third party'
      : 'login services of third parties';
  return [
    SmfIssue.warning(
      'The app offers $named on iOS, $services, but no way to sign in that '
      'the App Store takes as an equivalent: one that asks for no more than '
      'the name and the email address of the user and lets the user keep '
      'the address private (App Store Review Guideline 4.8).',
      code: AuthRole.noEquivalentSignInWarning,
      hint: 'Add such a way to sign in on iOS, such as Sign in with Apple.',
    ),
  ];
}

/// The problems of the ways to sign in of the app in [input] that the
/// module rule of a module cannot see: one that the template of a role
/// gives, which only a module does, and two of one issuer, which the app
/// would show two buttons for.
List<SmfIssue> _methodIssues(RoleHookInput<AuthData> input) {
  final first = <String, ContributionOrigin?>{};
  final issues = <SmfIssue>[];
  for (final RoleData(:value, :origin) in input.data) {
    if (value is! SignInMethod) continue;
    if (origin is! ModuleOrigin) {
      issues.add(
        SmfIssue(
          'The $value comes from $origin, but only a module gives the '
          '$authRole a way to sign in.',
          origin: origin,
        ),
      );
      continue;
    }
    final module = ModuleOrigin(origin.module);
    final before = first.putIfAbsent(value.issuer, () => module);
    if (before != module) {
      issues.add(
        SmfIssue(
          'The modules $before and $module both give the $authRole a way to '
          'sign in of ${value.issuer}, so the app would show two buttons for '
          'one identity provider.',
          hint: 'Leave one of the modules out of the app.',
          origin: origin,
        ),
      );
    }
  }
  return issues;
}

final class _AuthTemplate extends _ServiceTemplate<AuthData> {
  const _AuthTemplate();

  @override
  Role<AuthData> get role => authRole;

  @override
  RoleImplementation? implementationOf(AuthData data) => switch (data) {
        AuthImplementation(:final implementation) => implementation,
        SignInMethod() => null,
      };

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
  /// mode does and does not do, which guard keeps a user from the whole app
  /// and which from the screens that need an account, where the data of a
  /// guest moves, how a screen signs in with a way to sign in of the app,
  /// and which functions of the role are not for the code of the app. The
  /// section of the role in the README of the app tells the mode of the app
  /// and what each mode means, and its ways to sign in.
  @override
  String get agentNote => '''
- `appSession` in `$file` tells who uses the app, and knows it before the first frame. Its `value` is a `SignedOutSession`, an `AnonymousSession` or an `AccountSession`, and `appSession.value.uid` is the id of the user. Sign in, sign up, sign out and delete the account only through `appSession`. The app has one, so create no other `AppSessionController`.
- A call of `appSession` fails only with an `AuthFailure`. Catch it and show a text of the app for its `reason`. Show its `developerHint` in debug mode only. After `recentSignInRequired`, tell the user to sign out and sign in again.
- `authMode` in that file says who may use the app without an account. It gates nothing on its own. What keeps a user from a screen is a guard of the routes. One that reads `appSession.allowsApp` stands before the whole app, and one that reads `appSession.hasAccount` stands only before the routes that it lists, the screens that need an account. In an app without such a guard every screen is open, whatever the mode, and that includes a screen that needs an account. A screen does not redirect itself.
- When an anonymous user signs in to an account that exists already, `takeGuestData()` in `${AuthRole.guestDataFile}` says what moves from that user to the account. As generated it moves nothing: write there what the app keeps under the id of a user. Call no method of `appSession` in it, since the sign-in that calls it would wait for that call.
- `${AuthRole.appSignInMethods}` in `${AuthRole.methodsFile}` lists the ways to sign in with an identity provider that the modules of the app add, and is empty without them. A screen of sign-in shows a button for each `${AuthRole.signInMethod.name}` whose `isAvailable` is true, with its `label(context)` and its `icon`.
- On a tap, the state of the screen awaits `credential()` of the way to sign in and gives the credential to `appSession.signInWith`. `credential()` returns `null` when the user closed the sheet of the identity provider, which is no failure: the screen goes back to how it was. Call `credential()` from the state of a screen, never within a call of `appSession`.
- `appSession.signInWith` gives an anonymous user the identity with the same id, or signs in to the account that has the identity already, and `takeGuestData()` moves what the anonymous user had. `appSession.deleteAccount()` asks a way to sign in with `revokesOnDeletion` for a credential again itself, and deletes nothing when the user closes its sheet.
- `AccountSession.issuers` lists the identity providers of an account, each the `issuer` of a `${AuthRole.signInMethod.name}`. Where an account has no `email`, show the `label` of its way to sign in instead.
- A new provider implements `$service` of `${AuthRole.serviceFile}`, and only the file of that implementation imports it. The code of the app imports `$file`, which exports `AuthFailure`, `AuthFailureReason`, `SignInCredential` and `IdTokenCredential`, and calls neither `$initFunction()` nor `$factory()` nor `appSession.start()`.
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

  /// The problems of the implementation and of the ways to sign in (see
  /// [_methodIssues]), a warning of an app that offers a login service of
  /// a third party on iOS without an equivalent one (see
  /// [_noEquivalentSignIn]), and a warning of the routes that ask for an
  /// account in an app without a guard for it (see [_openAccountRoutes]).
  @override
  List<SmfIssue> validate(RoleHookInput<AuthData> input) => [
        ...super.validate(input),
        ..._methodIssues(input),
        ..._noEquivalentSignIn(input),
        ..._openAccountRoutes(input),
      ];

  /// The mode of the app: the value of [AuthRole.modeOption], or its first
  /// value, which the question offers first and which a run without a
  /// terminal takes without asking.
  @override
  Future<Object?> choose(RoleChoiceContext<AuthData> context) async {
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

  /// The implementation, the mode of the app as the value of the constant
  /// `authMode`, the ways to sign in of the app as the items of
  /// `appSignInMethods` (see [_methodsOf]), and the section of the role in
  /// the README of the app, which tells that mode and those ways.
  @override
  RoleOutput render(RoleHookInput<AuthData> input) {
    final mode = authRole.modeIn(input);
    final methods = authRole.methodsIn(input);
    return RoleOutput(
      fragments: [
        ...super.render(input).fragments,
        AppEntryRole.readmeSections.entry(
          AuthRole.readmeHeading,
          _readmeSection(mode, methods),
        ),
      ],
      vars: {
        'auth_mode': 'AuthMode.${mode.name}',
        ..._methodsOf(input, methods),
      },
    );
  }

  /// The ways to sign in of the app in [methods] as the items of the list
  /// of [AuthRole.methodsFile], `methods`, with the imports of their icons
  /// and of the files of their functions, each with a prefix of the
  /// template's own, and the functions of their labels, `labels`, each of
  /// which reads the text of the module of the way to sign in from the
  /// texts of the app, or is its English text; see
  /// [LocalizationRole.expressionOf].
  static Map<String, Fragment> _methodsOf(
    RoleHookInput<AuthData> input,
    List<AppSignInMethod> methods,
  ) {
    // A function is in a file of the app, which its path identifies.
    final files = <String, ImportRef>{};
    final items = <String>[];
    final labels = <String>[];
    final iconImports = <ImportRef>[];
    final textImports = <ImportRef>[];
    final names = <String>{};
    for (final AppSignInMethod(:owner, :method) in methods) {
      final function = _labelFunctionOf(owner, method.label, names);
      final label = localizationRole.expressionOf(input, owner, method.label);
      labels.add('String $function(BuildContext context) => ${label.code};');
      textImports.addAll(label.imports);
      final credential = method.credential;
      final prefix = files
          .putIfAbsent(
            credential.import.uri,
            () => credential.import.withPrefix('method${files.length}'),
          )
          .prefix;
      final platforms = [
        for (final platform in AppPlatform.values)
          if (method.platforms.contains(platform))
            switch (platform) {
              AppPlatform.android => 'TargetPlatform.android',
              AppPlatform.ios => 'TargetPlatform.iOS',
            },
      ];
      final item = StringBuffer()
        ..writeln('  ${AuthRole.signInMethod.name}(')
        ..writeln('    label: $function,')
        ..writeln('    icon: ${method.icon.code},')
        ..writeln('    platforms: {${platforms.join(', ')}},')
        ..writeln('    credential: ${credential.codeWith(prefix)},')
        ..writeln('    issuer: ${SmfNames.dartString(method.issuer)},');
      if (method.revokesOnDeletion) {
        item.writeln('    revokesOnDeletion: true,');
      }
      items.add('$item  ),');
      iconImports.addAll(method.icon.imports);
    }
    return {
      'methods': Fragment(
        items.join('\n'),
        imports: [...iconImports, ...files.values],
      ),
      // A blank line before each function, the first after the list.
      'labels': Fragment(
        [for (final label in labels) '\n$label'].join('\n'),
        imports: textImports,
      ),
    };
  }

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
