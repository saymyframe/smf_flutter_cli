part of '../services.dart';

/// The REST role; see [RestRole].
const restRole = RestRole._();

/// The role of REST: the requests of the app to its REST API, with
/// guarantees that hold whichever module provides the role.
///
/// The role is one for one protocol. Another protocol, such as GraphQL, is a
/// role of its own, with a client, a key and files of its own beside these,
/// and reads the token of the user from the session of the [AuthRole] too.
///
/// The role's template generates these files, whichever module provides the
/// role:
/// - [clientFile] with `appRest`, the `AppRestClient` of the app, through
///   which code makes its requests, and the types of its answers:
///   `RestResponse`, `RestFailure` with its `RestFailureReason`, `RestCancel`
///   and `RestTokens`;
/// - [transportFile] with `RestTransport`, the interface that the provider
///   implements, and `RestExchange`, `RestReply` and `RestConnectionFailed`;
/// - [testServerFile] with `RestTestServer`, a local server for the tests of
///   the app, and [clientTestFile], a test that makes a real request to it, so
///   that every app makes one under `flutter test`, whichever provider it has;
/// - in an app with the [AuthRole], [sessionTokensFile] with
///   `SessionRestTokens`, the token of the user of `appSession`.
///
/// The provider contributes its implementation of `RestTransport` as a
/// [RoleImplementation] that is created with the app: the role has no start-up
/// phase, and its template refuses an implementation that is created
/// asynchronously. So the role adds nothing to `bootstrap()`, and an app that
/// makes no request pays nothing. The role registers nothing in a DI
/// container: one client is what keeps the guarantees, and a module that makes
/// requests then needs no DI container.
///
/// The role requires the [EnvRole], since the address of the API is a value
/// that the developer fills in: [baseAddressKey], which the template gives the
/// env role. The template also gives the app entry the permission
/// [internetPermission], writes the section [readmeHeading] of the README of
/// the app from its render hook, since the section tells of the token in an
/// app with the [AuthRole], and writes the note of the role in the guide for
/// coding agents, with a note of the token in an app with the [AuthRole].
///
/// ## What the template guarantees
///
/// The client is the same code in every app, over a thin transport, so a
/// second provider keeps all of this by construction:
/// - a relative path joins the address of [baseAddressKey], with or without a
///   leading slash and keeping the path of the address. A path that climbs out
///   of it with `..`, written as it is or encoded, fails with `rejected` before
///   anything is sent, so the token goes to no other service behind one host.
///   Only `http://` and `https://` make a path an address of its own, which
///   goes where it says, so `//other.example/x` stays on the server of the app.
///   Without a usable address, a relative path fails with `notConfigured`,
///   whose hint names the key, and the transport is not called;
/// - a call fails only with a `RestFailure`, of a closed set of reasons;
/// - in an app with the [AuthRole], the token of the user goes only to the
///   origin of the address: the same scheme, host and port. A redirect to
///   another origin takes it away, with the `authorization`, `cookie` and
///   `proxy-authorization` of the caller, and only a hop back gets the token
///   again. A header `authorization` of the caller stays, in place of the
///   token. A token over `http://` in a release build is up to the developer,
///   and the README says to use `https`;
/// - a 401 of a request with that token gets a new token once and repeats
///   once, for every method, since the server refused before it did anything.
///   Requests at the same time share one refresh, in the session. A second
///   401, no new token, and another user than the one who made the request
///   fail with `unauthorized`, and the client never signs anyone out. The wait
///   for a token has its own bound, `tokenWait`, since a forced read without a
///   network may take a minute before it fails;
/// - `GET` and `HEAD` repeat twice at most after a connection that failed and
///   after 429, 502, 503 and 504, keeping to `Retry-After` up to 30 seconds.
///   Other methods never repeat. A timeout is never repeated;
/// - the timeout is per attempt, with one timer in the client, which also
///   answers the call when a provider does not stop. So a `GET` with its
///   repeats may take longer than the timeout. A `RestCancel` ends a call and
///   wakes its waits at once, and does not stop a refresh that others share;
/// - a debug build prints one line for each attempt, with the origin and the
///   path alone: no query, no header and no body. No hint has a token.
///
/// A request made while the app starts, before `initAuth()` is over, waits for
/// the start at most the `anonymousWait` of the session. With no service by
/// then, the session answers `null`, and the request goes without a token.
///
/// ## What a provider keeps to
///
/// The contract of `RestTransport` is in [transportFile]: one attempt, no
/// redirect followed, any status a reply, a failed connection as
/// `RestConnectionFailed`, a connection closed when `RestExchange.stop`
/// completes, no credential or cookie added, nothing written to a log, a client
/// of the stack that follows `HttpOverrides`, the headers of a coding only on a
/// body in that coding, and a function that takes no arguments and never
/// throws. Only a running app shows whether a provider keeps to it. On
/// `dart:io` the call ends at once, but a TLS handshake on its way cannot be
/// ended, not even by `close(force: true)`: its socket closes when the
/// handshake ends or the server ends it. A provider that shares one
/// `HttpClient` cannot end a TCP connect on its way either: the system ends it.
///
/// ## Rules
///
/// The structural rules of the role read the index of each Dart file of an
/// app, so they see what a file itself imports and calls:
/// - `rest.factory_calls`: no file of a module, and none of the template of
///   another role, calls `createRestTransport()`, and of such files only those
///   of the provider's implementation, the files of its class and of its
///   function, import or export [transportFile]. So a module cannot make a
///   second client, which needs a transport;
/// - `rest.use_calls`: no file of a module, and none of the template of
///   another role, calls `appRest.use()`, which is for tests;
/// - `rest.implementation_factories`: the function of the implementation is in
///   its file and takes no arguments.
///
/// They do not see a `part` file of a library that imports [clientFile], a
/// file that reaches it through an export of another file, or `appRest` under
/// another name.
///
/// ## Tests
///
/// A test gives `appRest.use()` a transport of its own to script what a server
/// answers, or starts a `RestTestServer` and gives the client its address. The
/// doc of that class tells of the two traps of `flutter test`: its binding
/// answers 400 to every `HttpClient`, and a real socket never completes in the
/// fake time of `testWidgets`, so such a request runs in `tester.runAsync`. A
/// request that is still running when a `testWidgets` body ends fails the test
/// with a pending timer, the timer of its attempt.
///
/// No test of an app reaches the network, so a module that makes no request
/// needs nothing. A module whose start-up or services make requests declares
/// mocks that call `appRest.use(transport: …)`, so that the tests of the other
/// modules of the app see an answer.
final class RestRole extends Role<RoleImplementation> {
  const RestRole._();

  /// The path of the file with `appRest`, which the code of the app uses.
  static const clientFile = 'lib/core/rest/app_rest.dart';

  /// The path of the file with `RestTransport`, which the provider implements.
  static const transportFile = 'lib/core/rest/rest_transport.dart';

  /// The path of the file with `SessionRestTokens`, which only an app with the
  /// [AuthRole] has. So it is no file of the [interface] of the role.
  static const sessionTokensFile = 'lib/core/rest/session_tokens.dart';

  /// The path of the file with `RestTestServer`, a local server for the tests
  /// of the app.
  static const testServerFile = 'test/core/rest/rest_test_server.dart';

  /// The path of the test that every app with the role has, which makes a real
  /// request through the provider of the role to a `RestTestServer`.
  static const clientTestFile = 'test/core/rest/app_rest_test.dart';

  /// The key of the address that the relative paths of the requests join.
  static const baseAddressKey = EnvKey(
    'REST_BASE_URL',
    description:
        'The address of the REST API of the app, such as https://api.example.com/v1',
  );

  /// The heading of the section of the README of the app in which the template
  /// tells how the app makes requests. The section of a provider can refer to
  /// it.
  static const readmeHeading = 'REST API';

  /// The permission of the Android app that a request needs in a release
  /// build: the template of the app entry has it only in the manifests of
  /// debug and profile builds.
  static const internetPermission = 'android.permission.INTERNET';

  /// The implementation of `RestTransport`, which the template renders from
  /// the provider's [RoleImplementation]; modules do not contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    restRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'rest';

  @override
  String get description => 'REST API';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  /// The address of the API is a value of the app.
  @override
  Set<Role> get requires => const {envRole};

  /// The sign-in, whose token goes with the requests.
  @override
  Set<Role> get uses => const {authRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [clientFile, transportFile, testServerFile, clientTestFile],
      );

  @override
  RoleTemplate<RoleImplementation> get template => const _RestTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'rest.factory_calls',
          description: 'No module calls createRestTransport(), and only the '
              'files of the implementation of the provider import the file of '
              'RestTransport: the code of the app makes its requests through '
              'appRest.',
          check: _checkRestTransport,
        ),
        StructuralRule(
          id: 'rest.use_calls',
          description: 'No module calls appRest.use(), which is for tests.',
          check: _checkRestUse,
        ),
        StructuralRule(
          id: 'rest.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
      ];
}

/// What the rules of the role tell the owner of a file to do instead.
const _restHint = 'Make requests through appRest of ${RestRole.clientFile}.';

/// The problems with the transport of the provider in [input]; see
/// [_checkServiceReach].
///
/// Code that reached the transport would make requests around `appRest`,
/// which is what keeps the guarantees of the role.
List<SmfIssue> _checkRestTransport(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkServiceReach(
      input,
      factory: 'createRestTransport',
      service: 'RestTransport',
      serviceFile: RestRole.transportFile,
      controllerFile: RestRole.clientFile,
      hint: _restHint,
    );

/// The problems with `appRest.use()` in [input]: a call in a file of a module
/// or of the template of another role would change the client of every other
/// request of the app.
List<SmfIssue> _checkRestUse(StructuralRuleInput<RoleImplementation> input) => [
      for (final MapEntry(key: path, value: index) in input.files.entries)
        if (_usesController(input.owners[path], input.roleInput.role) &&
            invokesOn(index, 'appRest', 'use', RestRole.clientFile))
          SmfIssue(
            '$path calls appRest.use(), which only a test calls.',
            hint: _restHint,
            origin: input.owners[path],
            path: path,
          ),
    ];

/// What the role adds to its note in an app with sign-in: where the token goes,
/// what a 401 does, and what a request at start-up meets.
const String _restTokenNote = '''
- `appRest` adds the token of `appSession` to each request to the origin of `REST_BASE_URL`, through `${RestRole.sessionTokensFile}`, and to nothing else. A header `authorization` that a call gives stays in its place.
- On a 401 it gets a new token once and repeats once, for any method. Then it fails with `unauthorized`, which signs nobody out: decide in the app what that means.
- A request made while the app starts, before `initAuth()` is over, waits for the start at most `anonymousWait`, and goes without a token if there is still no session. So make a request that needs the user after `bootstrap()`.
''';

/// The section of the role in the README of an app: how a request is made, the
/// address, the failures, what repeats, the timeout, the token in an app with
/// [auth], the body as a type and the tests. It holds with every provider and
/// names none.
String _restReadme({required bool auth}) => '''
`appRest` in `${RestRole.clientFile}` makes the requests of the app:

```dart
final notes = (await appRest.get('notes', query: {'page': '1'})).decoded(
  (List<dynamic> json) => [for (final item in json) Note.fromJson(item as Map<String, dynamic>)],
);
```

A path is relative to the address of the API, with or without a leading slash, and keeps the path of that address. One that climbs out of it with `..` fails with `rejected` before anything is sent, so encode what a user types with `Uri.encodeComponent`. A full address with `http://` or `https://` goes where it says, such as a link to the next page or an upload address.

The address is `${RestRole.baseAddressKey.name}` in `.env`, as the section "${EnvRole.readmeHeading}" says. It is no secret, and a change takes a new `flutter run`. While it is empty, a relative path fails with `notConfigured`, whose hint names the key, and the app still builds and starts. Use `https` in a release. On a device, `http://10.0.2.2:8080` is your computer on the Android emulator and `http://127.0.0.1:8080` on the iOS simulator, and a phone reaches it at its address on your network. Each environment has an address of its own: change the value by hand, or have CI write `.env` for its job.

A call fails only with a `RestFailure`. Show a text of the app for its `reason`, and its `developerHint` in debug mode only. `failure.response` has the body of a refusal. The `headers` of a response join several values of one header, so several `set-cookie` values cannot be told apart there.

`GET` and `HEAD` repeat twice at most after a connection that broke and after 429, 502, 503 and 504, keeping to a `Retry-After` of up to 30 seconds. Other methods never repeat, since the server may have done what they asked, and their failure has the `retryAfter` that the server named.

The `timeout` of a call is per attempt, 30 seconds by default, so a `GET` with its repeats may take longer. A `RestCancel` ends a call at once: cancel it where the state of a screen is disposed of.
${auth ? '''

In this app, each request to the origin of `${RestRole.baseAddressKey.name}` carries the token of `appSession` as `Authorization: Bearer <token>`, and no other request does, also after a redirect. Your server checks the token itself. On a 401, the client gets a new token once and repeats the request once, for any method. Then it fails with `unauthorized`, which signs nobody out, since a server may refuse for other reasons: decide in the app what that means. A request made while the app starts, before the session is known, may go without a token, so make a request that needs the user after `bootstrap()`.
''' : ''}
`response.decoded(Note.fromJson)` turns the JSON of the body into your type, and a body that it does not take fails with `invalidResponse`. A list of JSON is a `List<dynamic>`, so a function of a list takes that and casts its items inside, as above. For generated models, run `flutter pub add json_annotation dev:json_serializable dev:build_runner` and pass the `fromJson` of the model.

In a test, `RestTestServer` of `${RestRole.testServerFile}` is a local server, and `appRest.use(transport: …)` scripts the answers. `flutter test` otherwise answers 400 to every request, and inside `testWidgets` a real request runs in `tester.runAsync`. A request that is still running when a `testWidgets` body ends fails the test with a pending timer. `${RestRole.clientTestFile}` shows the first.
''';

/// The template of the [RestRole]: the files of the role, the implementation
/// of the provider, the key of the address, the permission of the Android app,
/// the section of the role in the README of the app and its notes for coding
/// agents.
final class _RestTemplate extends _ServiceTemplate<RoleImplementation> {
  const _RestTemplate();

  @override
  Role<RoleImplementation> get role => restRole;

  @override
  MasonBundle get bundle => restRoleBundle;

  @override
  String get file => RestRole.clientFile;

  @override
  String get service => 'RestTransport';

  @override
  String get factory => 'createRestTransport';

  /// No app has this function: [validate] refuses an implementation that is
  /// created asynchronously.
  @override
  String get initFunction => 'initRest';

  @override
  String get variable => '_restTransport';

  @override
  SocketRef<CodeSocket> get implementations => RestRole.implementations;

  /// The note of the role in the guide for coding agents: how code makes a
  /// request and reads its answer, what a failure is, what repeats and how
  /// long an attempt takes, what a provider implements, and how a test gets an
  /// answer.
  @override
  String get agentNote => '''
- `appRest` in `$file` makes the requests of the app: `appRest.get('notes')`, `post`, `put`, `patch`, `delete`, `head`. A path is relative to `REST_BASE_URL` in `.env`, with or without a leading slash, and one that climbs out of it with `..` fails with `rejected`. A full address goes where it says. Call it from the state of a screen or from a repository, never from a widget, and create no other `AppRestClient` in the code of the app.
- `response.decoded(Note.fromJson)` turns the JSON of the body into your type, and a body that it does not take fails with `invalidResponse`. A list of JSON is a `List<dynamic>`, so a function of a list takes that and casts its items inside.
- A call fails only with a `RestFailure`: show a text of the app for its `reason`, and its `developerHint` in debug mode only. `failure.response` has the body of a refusal. While `REST_BASE_URL` is empty, a relative path fails with `notConfigured`, and the app still builds and starts.
- `GET` and `HEAD` repeat by themselves after a broken connection and after 429, 502, 503 and 504, keeping to `Retry-After`. Other methods never do. Never wrap a call in a loop of your own.
- The `timeout` of a call is per attempt, 30 seconds by default, so a `GET` with its repeats may take longer. `RestCancel` ends a call: cancel it where the state of a screen is disposed of.
- A new provider implements `$service` of `${RestRole.transportFile}`, and only the files of that implementation import it. The code of the app calls neither `$factory()` nor `appRest.use()`, which is for tests.
- In a test, `RestTestServer` of `${RestRole.testServerFile}` is a local server, or `appRest.use(transport: …)` scripts the answers. `flutter test` otherwise answers 400 to every request, and inside `testWidgets` a request to that server runs in `tester.runAsync`. A request that is still running when a `testWidgets` body ends fails the test with a pending timer.
''';

  /// The bricks, the key, the permission and the notes of the role. The role
  /// registers nothing in a DI container: the code of an app uses `appRest`.
  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        BrickContribution(restRoleSessionBundle, when: const {authRole}),
        envRole.data(RestRole.baseAddressKey),
        AppEntryRole.androidManifestPermissions
            .key(RestRole.internetPermission),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(agentNote),
        ),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(_restTokenNote),
          when: const {authRole},
        ),
      ];

  /// Also refuses an implementation that is created asynchronously: the role
  /// has no start-up phase, and `appRest` works from the first call.
  @override
  List<SmfIssue> validate(RoleHookInput<RoleImplementation> input) => [
        ...super.validate(input),
        for (final (:implementation, :origin) in _implementationsIn(input))
          if (implementation.isAsync)
            SmfIssue(
              'The ${implementation.factory.name} of the $role starts '
              'asynchronously, but the role has no start-up phase.',
              hint: 'Create the transport with the app, and let it open what '
                  'it needs at its first request.',
              origin: origin,
            ),
      ];

  /// The implementation, the tokens of the session in an app with sign-in, and
  /// the section of the role in the README of the app.
  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) => RoleOutput(
        fragments: [
          ...super.render(input).fragments,
          AppEntryRole.readmeSections.entry(
            RestRole.readmeHeading,
            _restReadme(auth: input.has(authRole)),
          ),
        ],
        vars: {
          'rest_tokens': input.has(authRole)
              ? const Fragment(
                  'const SessionRestTokens()',
                  imports: [ImportRef.app('core/rest/session_tokens.dart')],
                )
              : 'null',
        },
      );

  /// The role adds nothing to `bootstrap()`.
  @override
  String? bootstrap({required bool hasAsync}) => null;
}
