@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/bundles/rest_role_bundle.dart';
import 'package:smf_contracts/bundles/rest_role_session_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// The file of the fake provider of REST in the test app.
const _fakeFile = ImportRef.app('fakes/fake_rest.dart');

/// The file of the fake provider of sign-in in the test app.
const _fakeAuthFile = ImportRef.app('fakes/fake_auth.dart');

/// The template of the role, as the origin of what it contributes.
const _template = RoleTemplateOrigin(restRole);

/// The implementation of the transport of the test app.
const _implementation = RoleImplementation(
  type: TypeRef('FakeRest', import: _fakeFile),
  create: FactoryRef('createFakeRest', import: _fakeFile),
);

/// What the template of the role contributes.
List<Contribution> _contributions() =>
    restRole.template.contribute(testContext);

/// The files of the role in an app with [auth] or without it, and what the
/// template puts into other sockets.
Future<RenderedTemplate> _rendered({bool auth = false}) => renderTemplate(
      restRole,
      data: [dataOf(restRole, _implementation, module: 'fake_rest')],
      present: {envRole, if (auth) authRole},
    );

/// A provider of REST for the test app, which keeps to the contract of
/// `RestTransport` and answers what a test puts into `FakeRest.answers`: a
/// reply, or what the exchange does instead. Without an answer, it answers
/// 200.
const _fakeRest = '''
import 'dart:async';
import 'dart:convert';

import '../core/rest/rest_transport.dart';

/// What the app has as its transport.
final FakeRest fakeRest = FakeRest();

RestTransport createFakeRest() => fakeRest;

/// The exchange waits until it has to stop, and then fails as a provider does
/// whose connection closed.
const Object hang = 'hang';

/// The exchange never ends, whatever its stop tells: a provider with a bug.
const Object deaf = 'deaf';

/// The transport throws [error] when it is called, and returns no future.
final class ThrowsAtOnce {
  const ThrowsAtOnce(this.error);

  final Object error;
}

/// The exchange waits for its delay, and then gives [reply].
final class Slowly {
  const Slowly(this.delay, this.reply);

  final Duration delay;
  final RestReply reply;
}

RestReply reply(
  int status, {
  Map<String, String> headers = const {},
  String body = '',
}) =>
    RestReply(status: status, headers: headers, bytes: utf8.encode(body));

final class FakeRest implements RestTransport {
  /// What the next exchanges answer, in order.
  final List<Object> answers = [];

  /// The exchanges that reached the transport, in order.
  final List<RestExchange> exchanges = [];

  /// How many exchanges saw their stop complete.
  int stops = 0;

  /// What happens once, when the first exchange reaches the transport.
  void Function()? onFirstExchange;

  @override
  Future<RestReply> send(RestExchange exchange) {
    exchanges.add(exchange);
    onFirstExchange?.call();
    onFirstExchange = null;
    unawaited(exchange.stop.then((_) => stops++));
    final answer = answers.isEmpty ? reply(200) : answers.removeAt(0);
    switch (answer) {
      case final RestReply reply:
        return Future.value(reply);
      case ThrowsAtOnce(:final error):
        throw error;
      case Slowly(:final delay, :final reply):
        return Future.delayed(delay, () => reply);
      case 'hang':
        return exchange.stop.then(
          (_) => throw const RestConnectionFailed('The connection closed.'),
        );
      case 'deaf':
        return Completer<RestReply>().future;
      default:
        return Future.error(answer);
    }
  }
}
''';

/// A provider of sign-in for the test app, with the calls that the session of
/// an app makes for a sign-in and a sign-out and for the token of the user. A
/// token is `<uid>-<turn>`, with a new turn at each forced refresh.
const _fakeAuth = r'''
import 'dart:async';

import '../core/auth/auth_service.dart';

/// What the app has as its service.
final FakeAuth fakeAuth = FakeAuth();

AuthService createFakeAuth() => fakeAuth;

final class FakeAuth implements AuthService {
  final StreamController<AuthUser?> _changes = StreamController.broadcast();

  int _turn = 0;

  /// How many forced refreshes reached the service.
  int refreshes = 0;

  /// What a read throws, once.
  Object? failure;

  /// What a forced refresh throws, once.
  Object? refreshFailure;

  /// Whether a failure signs the user out first, as for a session that ended.
  bool failureSignsOut = false;

  /// What a refresh waits for.
  Completer<void>? refreshHold;

  @override
  AuthUser? currentUser;

  @override
  Stream<AuthUser?> get userChanges => _changes.stream;

  void putOnDevice(String uid) {
    currentUser = AuthUser(uid: uid, isAnonymous: false, email: '$uid@x.test');
  }

  void change(String? uid) {
    currentUser = uid == null
        ? null
        : AuthUser(uid: uid, isAnonymous: false, email: '$uid@x.test');
    _changes.add(currentUser);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    change(email.split('@').first);
  }

  @override
  Future<void> signOut() async => change(null);

  @override
  Future<String?> userToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshes++;
      await refreshHold?.future;
      _turn++;
      if (refreshFailure case final error?) {
        refreshFailure = null;
        throw error;
      }
    }
    if (failure case final error?) {
      failure = null;
      if (failureSignsOut) change(null);
      throw error;
    }
    final user = currentUser;
    return user == null ? null : '${user.uid}-$_turn';
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
''';

/// Code of an app that makes requests as the note of the role tells, so the
/// analyzer checks that the types of the answers take it: a named constructor
/// and a function of the JSON that they take, a function of any JSON, the body
/// of a refusal, and a client that a test creates.
const _usage = r'''
import '../core/rest/app_rest.dart';

final class Note {
  Note.fromJson(Map<String, dynamic> json) : text = json['text'] as String;

  final String text;

  static List<Note> listFromJson(List<Object?> json) => [
        for (final item in json) Note.fromJson(item! as Map<String, dynamic>),
      ];
}

Future<String> firstNote() async {
  try {
    final List<Note> notes =
        (await appRest.get('notes', query: {'page': '1'}))
            .decoded(Note.listFromJson);
    final Note note = (await appRest.post('notes', json: {'text': 'a'}))
        .decoded(Note.fromJson);
    final int count = (await appRest.head('notes'))
        .decoded((json) => (json as List<Object?>).length);
    return '${notes.first.text} ${note.text} $count';
  } on RestFailure catch (failure) {
    return failure.response?.text ?? failure.reason.name;
  }
}
''';

/// A stand-in for the part of `flutter_test` that the generated tests use, so
/// that the analyzer checks them against the real signatures.
const _flutterTest = '''
class TestWidgetsFlutterBinding {
  static TestWidgetsFlutterBinding ensureInitialized() =>
      TestWidgetsFlutterBinding();
}

void setUp(dynamic Function() body) {}

void tearDown(dynamic Function() body) {}

void test(Object description, dynamic Function() body) {}

void expect(Object? actual, Object? matcher) {}

Future<void> expectLater(Object? actual, Object? matcher) async {}

class Matcher {}

class TypeMatcher<T> extends Matcher {
  TypeMatcher<T> having(
    Object? Function(T) feature,
    String description,
    Object? matcher,
  ) =>
      this;
}

TypeMatcher<T> isA<T>() => TypeMatcher<T>();

Matcher throwsA(Object? matcher) => Matcher();
''';

/// The class that a provider of the env role generates, with the key of the
/// role.
const _appEnv = '''
abstract final class AppEnv {
  static String? get restBaseUrl => 'https://env.example.com/v1';
}
''';

/// The files of the test app: the files of the role, as its template generates
/// them in an app with sign-in, or without it, those of the auth role in the
/// first in [mode], and the fakes. The app runs in debug mode, or in a release
/// build without [debug].
Future<DartFiles> _app({
  bool auth = false,
  bool debug = true,
  AuthMode mode = AuthMode.required,
}) async {
  final rest = await _rendered(auth: auth);
  final session = auth
      ? await renderTemplate(
          authRole,
          data: [
            dataOf(
              authRole,
              const AuthImplementation(
                type: TypeRef('FakeAuth', import: _fakeAuthFile),
                create: FactoryRef('createFakeAuth', import: _fakeAuthFile),
              ),
              module: 'fake_auth',
            ),
          ],
          choice: mode,
        )
      : null;
  return DartFiles.write(
    {
      ...rest.files,
      ...?session?.files,
      EnvRole.readerFile: _appEnv,
      'lib/fakes/fake_rest.dart': _fakeRest,
      'lib/fakes/usage.dart': _usage,
      if (auth) 'lib/fakes/fake_auth.dart': _fakeAuth,
    },
    flutter: {
      'foundation.dart': debug
          ? sessionFoundation
          : sessionFoundation.replaceFirst(
              'const bool kDebugMode = true;',
              'const bool kDebugMode = false;',
            ),
      'widgets.dart': sessionWidgets,
    },
    packages: {'flutter_test': _flutterTest},
  );
}

/// What the scripts for the test app share. `clientOf` creates a client whose
/// timers wait an hour, so that `fast` tells them from the waits for a repeat,
/// `failureOf` tells the failure of a call, and `FakeTokens` scripts the user.
const _prelude = r'''
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:my_app/core/rest/app_rest.dart';
import 'package:my_app/core/rest/rest_transport.dart';
import 'package:my_app/fakes/fake_rest.dart';

final result = <String, Object?>{};

const hour = Duration(hours: 1);

const home = 'https://api.example.com/v1';

final class FakeTokens implements RestTokens {
  FakeTokens({this.owner = 'ada', this.token = 't0', this.next = 't1'});

  @override
  String? owner;

  String? token;
  String? next;

  /// What the reads wait for.
  Future<void>? currentHold;
  Future<void>? afterHold;

  /// What a read or a refresh throws.
  Object? currentFailure;
  Object? afterFailure;

  /// Runs while the first read waits, as a sign-in that lands then.
  void Function()? duringRead;

  /// Runs while the refresh waits.
  void Function()? duringAfter;

  final List<String> calls = [];

  @override
  Future<String?> current() async {
    calls.add('current');
    await currentHold;
    duringRead?.call();
    duringRead = null;
    if (currentFailure case final failure?) throw failure;
    return token;
  }

  @override
  Future<String?> after(String rejected) async {
    calls.add('after $rejected');
    await afterHold;
    duringAfter?.call();
    if (afterFailure case final failure?) throw failure;
    return next;
  }
}

AppRestClient clientOf(
  RestTransport transport, {
  String? base = home,
  RestTokens? tokens,
  Duration timeout = hour,
  Duration tokenWait = hour,
}) =>
    AppRestClient(
      transport: transport,
      baseAddress: base,
      tokens: tokens,
      timeout: timeout,
      tokenWait: tokenWait,
    );

/// The failure of [call], as its reason, its status and its hint.
Future<String> failureOf(Future<Object?> Function() call) async {
  try {
    await call();
    return 'no failure';
  } on RestFailure catch (failure) {
    return [
      failure.reason.name,
      if (failure.status != null) '${failure.status}',
      if (failure.developerHint != null) '(${failure.developerHint})',
    ].join(' ');
  }
}

/// What the failure of [call] has, as text, or `no failure`.
Future<RestFailure?> caught(Future<Object?> Function() call) async {
  try {
    await call();
    return null;
  } on RestFailure catch (failure) {
    return failure;
  }
}

String? authorizationOf(RestExchange exchange) =>
    exchange.headers['authorization'];

/// The timers that a [fast] call created and did not cancel or run.
final class _Timer implements Timer {
  _Timer(this._timer, this._live) {
    _live.add(this);
  }

  final Timer _timer;
  final Set<Timer> _live;

  @override
  void cancel() {
    _live.remove(this);
    _timer.cancel();
  }

  @override
  bool get isActive => _timer.isActive;

  @override
  int get tick => _timer.tick;
}

/// What [fast] saw: the waits under an hour, in milliseconds, which it did not
/// wait for, how many timers of an hour it saw, and how many it left running.
final class Waits {
  final List<int> waits = [];
  int limits = 0;
  final Set<Timer> live = {};

  Map<String, Object?> get note =>
      {'waits': waits, 'limits': limits, 'timers left': live.length};
}

/// Runs [body] in a zone that fires a timer of under an hour at once and notes
/// it, and tracks the timers of an hour, which are the limits of the client.
Future<T> fast<T>(Waits seen, Future<T> Function() body) => runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          if (duration >= hour) {
            seen.limits++;
            return _Timer(parent.createTimer(zone, duration, callback), seen.live);
          }
          seen.waits.add(duration.inMilliseconds);
          return parent.createTimer(zone, Duration.zero, callback);
        },
      ),
    );
''';

/// How a relative path joins the address, and where a full address goes.
const _addresses = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  Future<String> uriOf(
    String path, {
    String base = home,
    Map<String, String>? query,
  }) async {
    final fake = FakeRest();
    await clientOf(fake, base: base).get(path, query: query);
    return '${fake.exchanges.single.uri}';
  }

  result['no leading slash'] = await uriOf('notes');
  result['a leading slash'] = await uriOf('/notes');
  result['an address that ends with a slash'] =
      await uriOf('notes', base: '$home/');
  result['an address without a path'] =
      await uriOf('/notes', base: 'https://api.example.com');
  result['no path'] = await uriOf('');
  result['a path that names another server'] =
      await uriOf('//evil.example/x');
  result['a path that names a user of the server'] =
      await uriOf('@evil.example/x', base: 'https://api.example.com');
  result['a path with another scheme'] = await uriOf('ftp://evil.example/x');
  result['a query'] =
      await uriOf('notes', query: {'x': 'a b', 'y': 'c&d', 'z+': '1'});
  result['a query in the path and another one'] =
      await uriOf('notes?a=1%202', query: {'b': '2'});
  result['a fragment'] = await uriOf('notes#top');
  result['a full address'] =
      await uriOf('https://files.example.com/a?sig=1', base: '');
  result['a full address with capitals'] =
      await uriOf('HTTPS://files.example.com/a');
  result['a full address with a query'] =
      await uriOf('http://other.example:8080/a?b=1', query: {'c': '2'});

  final problems = <String, Object?>{};
  for (final base in [
    null,
    '',
    'api.example.com/v1',
    'ftp://api.example.com',
    'https://',
    'https://api.example.com/v1?key=1',
    'https://api.example.com/v1#top',
    'https://user:secret@api.example.com/v1',
  ]) {
    final fake = FakeRest();
    final client = clientOf(fake, base: base);
    final failure = await caught(() => client.get('notes'));
    await client.get('https://files.example.com/a');
    problems['$base'] = {
      'reason': failure?.reason.name,
      'names the key': failure!.developerHint!.contains('REST_BASE_URL'),
      'quotes the value': failure.developerHint!.contains('secret'),
      'only the full address reached the transport': [
        for (final exchange in fake.exchanges) '${exchange.uri}',
      ],
    };
  }
  result['addresses that a relative path cannot join'] = problems;

  // The value of the role reaches the client of the app.
  await appRest.get('notes');
  result['the client of the app'] = '${fakeRest.exchanges.single.uri}';
  appRest.use(baseAddress: 'https://test.example.com');
  await appRest.get('notes');
  result['after use'] = '${fakeRest.exchanges.last.uri}';
  final other = FakeRest();
  appRest.use(transport: other);
  await appRest.get('notes');
  result['after use of a transport'] = '${other.exchanges.single.uri}';
  port.send(result);
}
''';

/// What a request carries, and what each status and error of a transport
/// becomes.
const _failures = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  // What a request carries.
  final sent = FakeRest();
  final client = clientOf(sent);
  await client.post('notes', json: {'text': 'é'}, headers: {'X-Mixed': 'a'});
  await client.put('notes', bytes: const [1, 2]);
  await client.patch(
    'notes',
    json: const <String, Object?>{},
    headers: {'Content-Type': 'application/vnd.note+json'},
  );
  await client.delete('notes');
  await client.delete('notes', json: 1);
  await client.head('notes');
  await client.get('notes');
  result['what a request carries'] = [
    for (final exchange in sent.exchanges)
      {
        'method': exchange.method,
        'headers': exchange.headers,
        'body': exchange.body,
      },
  ];

  // Each status, with a method that does not repeat.
  final statuses = <String, Object?>{};
  for (final status in [
    200,
    201,
    204,
    304,
    100,
    300,
    400,
    401,
    403,
    404,
    409,
    410,
    418,
    429,
    500,
    501,
    502,
    503,
    504,
    600,
  ]) {
    final fake = FakeRest()..answers.add(reply(status, body: '{"why":"no"}'));
    final failure = await caught(() => clientOf(fake).post('notes'));
    statuses['$status'] = failure == null
        ? 'answer'
        : {
            'reason': failure.reason.name,
            'status': failure.status,
            'the body': failure.response?.text,
            'decoded': failure.response?.decoded(
              (Map<String, dynamic> json) => json['why'],
            ),
          };
  }
  result['each status'] = statuses;

  // The errors of a transport and of a caller.
  Future<String> errorOf(Object answer) async {
    final fake = FakeRest()..answers.add(answer);
    return failureOf(() => clientOf(fake).post('notes'));
  }

  result['a connection that failed'] =
      await errorOf(const RestConnectionFailed('It broke.'));
  result['an exception of a provider'] =
      await errorOf(StateError('Bearer secret'));
  result['an object that a provider threw'] = await errorOf('Bearer secret');
  result['an error that a provider throws at once'] =
      await errorOf(const ThrowsAtOnce(FormatException('Bearer secret')));
  result['a body and bytes'] = await failureOf(
    () => client.post('notes', json: 1, bytes: const [1]),
  );
  result['a body that is no JSON value'] =
      await failureOf(() => client.post('notes', json: Object()));
  result['an address that is no address'] =
      await failureOf(() => client.get('https://[oops/a'));

  // What decoded does.
  RestResponse answer(String body) =>
      RestResponse(status: 200, headers: const {}, bytes: utf8.encode(body));
  Future<String> decodeFailure(String body, Object? Function(RestResponse) d) =>
      failureOf(() async => d(answer(body)));
  result['decoded'] = answer('{"a":1}').decoded(
    (Map<String, dynamic> json) => json['a'],
  );
  result['decoded with any JSON'] = answer('[1,2]').decoded(
    (json) => (json! as List<Object?>).length,
  );
  result['a body that is no JSON'] = await decodeFailure(
    'secret',
    (response) => response.decoded((json) => json),
  );
  result['a body of another type'] = await decodeFailure(
    '[1]',
    (response) => response.decoded((Map<String, dynamic> json) => json),
  );
  result['a parse that fails'] = await decodeFailure(
    '{"a":1}',
    (response) => response.decoded(
      (Map<String, dynamic> json) => json['a']! as String,
    ),
  );
  result['the failure of a parse has the answer'] = (await caught(
    () async => answer('nope').decoded((json) => json),
  ))!
      .response!
      .text;
  result['a body that is no UTF-8'] =
      RestResponse(status: 200, headers: const {}, bytes: const [0xff]).text;

  // What the types say of themselves.
  result['as text'] = [
    '${const RestFailure(RestFailureReason.cancelled)}',
    '${const RestFailure(RestFailureReason.notFound, status: 404, developerHint: 'No.')}',
    '${answer('')}',
    '${const RestConnectionFailed('It broke.')}',
    '${sent.exchanges.first}',
    RestExchange(
      method: 'GET',
      uri: Uri.parse('https://user:secret@x.example/a?key=secret'),
      headers: const {'authorization': 'Bearer secret'},
      stop: Completer<void>().future,
    ).toString(),
  ];
  port.send(result);
}
''';

/// Where the token goes.
const _tokens = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  Future<Map<String, Object?>> call(
    String path, {
    List<Object> answers = const [],
    Map<String, String>? headers,
    String? base = home,
    FakeTokens? tokens,
    bool post = false,
  }) async {
    final fake = FakeRest()..answers.addAll(answers);
    final used = tokens ?? FakeTokens();
    final client = clientOf(fake, base: base, tokens: used);
    final failure = await failureOf(
      () => post
          ? client.post(path, headers: headers)
          : client.get(path, headers: headers),
    );
    return {
      'sent': [
        for (final exchange in fake.exchanges)
          '${exchange.uri.origin} ${authorizationOf(exchange)} '
              '${exchange.headers['cookie']} '
              '${exchange.headers['proxy-authorization']} '
              '${exchange.headers['x-mine']}',
      ],
      'reads': used.calls,
      'failure': failure,
    };
  }

  RestReply goTo(String location, [int status = 302]) =>
      reply(status, headers: {'location': location});

  const other = 'https://other.example/x';
  result['the origin of the app'] = await call('notes');
  result['a full address of that origin'] =
      await call('https://api.example.com/elsewhere');
  result['another host'] = await call(other);
  result['a subdomain'] = await call('https://sub.api.example.com/x');
  result['another port'] = await call('https://api.example.com:8443/x');
  result['another scheme'] = await call('http://api.example.com/x');
  result['nobody signed in'] =
      await call('notes', tokens: FakeTokens(owner: null, token: null));
  result['an address without an origin of the app'] =
      await call(other, base: null);
  result['a header of the caller'] =
      await call('notes', headers: {'Authorization': 'Bearer mine'});
  const mine = {'cookie': 'c', 'Proxy-Authorization': 'p', 'X-Mine': 'm'};
  result['a redirect in the origin of the app'] = await call(
    'notes',
    answers: [goTo('/v1/moved')],
    headers: mine,
  );
  result['a redirect to another host, and back to the app'] = await call(
    'notes',
    answers: [goTo(other, 301), goTo('$home/back', 307)],
    headers: mine,
  );
  result['a redirect to a subdomain'] = await call(
    'notes',
    answers: [goTo('https://sub.api.example.com/x', 308)],
  );
  result['a redirect from https to http on the host'] = await call(
    'notes',
    answers: [goTo('http://api.example.com/v1/notes', 303)],
  );
  result['a redirect of a full address to the app'] =
      await call(other, answers: [goTo('$home/notes')]);
  result['a redirect of a call with a header of its own'] = await call(
    'notes',
    answers: [goTo(other), goTo('$home/back')],
    headers: {'authorization': 'Bearer mine'},
  );
  result['a redirect of a POST'] =
      await call('notes', answers: [goTo(other)], post: true);
  result['a redirect without a location'] =
      await call('notes', answers: [reply(302)]);
  result['a redirect to another scheme'] =
      await call('notes', answers: [goTo('ftp://other.example/x')]);
  result['five redirects'] = (await call(
    'notes',
    answers: [for (var hop = 0; hop < 5; hop++) goTo('/v1/hop$hop')],
  ))['failure'];
  result['six redirects'] = (await call(
    'notes',
    answers: [for (var hop = 0; hop < 6; hop++) goTo('/v1/hop$hop')],
  ))['failure'];
  result['a status of 3xx that is no redirect'] =
      (await call('notes', answers: [reply(300)]))['failure'];
  port.send(result);
}
''';

/// What a 401 does.
const _refreshes = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  Future<Map<String, Object?>> call(
    FakeTokens tokens,
    List<Object> answers, {
    Map<String, String>? headers,
    Duration tokenWait = hour,
    String path = 'notes',
  }) async {
    final fake = FakeRest()..answers.addAll(answers);
    final client = clientOf(fake, tokens: tokens, tokenWait: tokenWait);
    final failure = await failureOf(
      () => client.post(path, json: 'body', headers: headers),
    );
    return {
      'sent': [
        for (final exchange in fake.exchanges)
          '${authorizationOf(exchange)} ${utf8.decode(exchange.body!)}',
      ],
      'reads': tokens.calls,
      'failure': failure,
    };
  }

  final refused = reply(401);
  result['one 401'] = await call(FakeTokens(), [refused]);
  result['a second 401'] = await call(FakeTokens(), [refused, refused]);
  result['a refresh that finds nobody'] =
      await call(FakeTokens(next: null), [refused]);
  final tokens = FakeTokens();
  tokens.duringAfter = () => tokens.owner = 'grace';
  result['another user during the refresh'] = await call(tokens, [refused]);
  result['a refresh that fails'] = await call(
    FakeTokens()
      ..afterFailure = const RestFailure(
        RestFailureReason.network,
        developerHint: 'No network.',
      ),
    [refused],
  );
  result['a refresh that throws something else'] = await call(
    FakeTokens()..afterFailure = StateError('Bearer secret'),
    [refused],
  );
  result['a read that fails'] = await call(
    FakeTokens()
      ..currentFailure = const RestFailure(RestFailureReason.tooManyRequests),
    const [],
  );
  result['a 401 without a token'] =
      await call(FakeTokens(owner: null, token: null), [refused]);
  result['a 401 of a header of the caller'] = await call(
    FakeTokens(),
    [refused],
    headers: {'authorization': 'Bearer mine'},
  );
  result['a 401 of another origin'] = await call(
    FakeTokens(),
    [refused],
    path: 'https://other.example/x',
  );
  result['a refresh that takes too long'] = await call(
    FakeTokens()..afterHold = Completer<void>().future,
    [refused],
    tokenWait: const Duration(milliseconds: 10),
  );
  result['a read that takes too long'] = await call(
    FakeTokens()..currentHold = Completer<void>().future,
    const [],
    tokenWait: const Duration(milliseconds: 10),
  );

  // A repeat of a GET, and the user.
  Future<Map<String, Object?>> repeat(FakeTokens tokens, void Function() now) async {
    final fake = FakeRest()
      ..answers.add(reply(503))
      ..onFirstExchange = now;
    final failure = await fast(
      Waits(),
      () => failureOf(() => clientOf(fake, tokens: tokens).get('notes')),
    );
    return {
      'sent': [for (final e in fake.exchanges) authorizationOf(e)],
      'failure': failure,
    };
  }

  final other = FakeTokens();
  result['another user before a repeat'] = await repeat(other, () {
    other.owner = 'grace';
    other.token = 'of grace';
  });
  final late = FakeTokens(owner: null, token: null);
  result['a user who came before a repeat of a request of nobody'] =
      await repeat(late, () {
    late.owner = 'ada';
    late.token = 'of ada';
  });
  final signedOut = FakeTokens();
  result['nobody before a repeat'] = await repeat(signedOut, () {
    signedOut.owner = null;
    signedOut.token = null;
  });

  // A user who comes during the first read, as when the app starts: the token
  // that the read gives may be of the user before.
  final starting = FakeTokens(owner: null, token: 'of nobody');
  starting.duringRead = () {
    starting.owner = 'ada';
    starting.token = 'of ada';
  };
  result['a user who comes during the first read'] =
      await call(starting, const []);
  port.send(result);
}
''';

/// What repeats, and how long it waits.
const _repeats = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  const every = ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'];

  Future<Object?> send(AppRestClient client, String method) => switch (method) {
        'GET' => client.get('notes'),
        'HEAD' => client.head('notes'),
        'POST' => client.post('notes'),
        'PUT' => client.put('notes'),
        'PATCH' => client.patch('notes'),
        _ => client.delete('notes'),
      };

  Future<Map<String, Object?>> run(
    String method,
    List<Object> answers,
  ) async {
    final fake = FakeRest()..answers.addAll(answers);
    final seen = Waits();
    final failure = await fast(
      seen,
      () => caught(() => send(clientOf(fake), method)),
    );
    return {
      'exchanges': fake.exchanges.length,
      'reason': failure?.reason.name,
      'retryAfter': failure?.retryAfter?.inSeconds,
      ...seen.note,
    };
  }

  const broken = RestConnectionFailed('It broke.');
  result['a connection that failed'] = {
    for (final method in every)
      method: await run(method, const [broken, broken, broken, broken]),
  };
  result['a connection that comes back'] =
      await run('GET', const [broken]);

  result['each status of a repeat'] = {
    for (final status in [429, 502, 503, 504])
      '$status': {
        for (final method in every)
          method: await run(method, [
            for (var answer = 0; answer < 4; answer++) reply(status),
          ]),
      },
  };
  result['each other status'] = {
    for (final status in [400, 401, 403, 404, 409, 500, 501])
      '$status': await run('GET', [reply(status)]),
  };

  RestReply wait(String value, [int status = 503]) =>
      reply(status, headers: {'retry-after': value});
  result['Retry-After in seconds'] = await run('GET', [wait('7'), reply(200)]);
  result['Retry-After of no wait'] = await run('GET', [wait('0'), reply(200)]);
  result['Retry-After at the limit'] =
      await run('GET', [wait('30'), reply(200)]);
  result['Retry-After over the limit'] = await run('GET', [wait('31')]);
  result['Retry-After in the past'] =
      await run('GET', [wait('Sun, 06 Nov 1994 08:49:37 GMT'), reply(200)]);
  result['Retry-After in a form of no use'] =
      await run('GET', [wait('soon'), reply(200)]);
  result['Retry-After below zero'] = await run('GET', [wait('-1'), reply(200)]);
  result['Retry-After with a month of no use'] =
      await run('GET', [wait('Sun, 06 Non 2094 08:49:37 GMT'), reply(200)]);
  result['Retry-After after the repeats'] = await run(
    'GET',
    [wait('1'), wait('2'), wait('3')],
  );
  result['Retry-After of a POST'] = await run('POST', [wait('5', 429)]);

  // An HTTP date some seconds from now.
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String two(int value) => value.toString().padLeft(2, '0');
  final at = DateTime.now().toUtc().add(const Duration(seconds: 20));
  final dated = await run('GET', [
    wait(
      'Sun, ${two(at.day)} ${months[at.month - 1]} ${at.year} '
      '${two(at.hour)}:${two(at.minute)}:${two(at.second)} GMT',
    ),
    reply(200),
  ]);
  final waited = (dated['waits']! as List<int>).single;
  result['Retry-After as a date'] = waited > 15000 && waited <= 20000;
  port.send(result);
}
''';

/// What the timeout and a cancel do.
const _stops = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  const short = Duration(milliseconds: 20);
  final uncaught = <String>[];
  final done = Completer<void>();
  runZonedGuarded(
    () async {
      // An exchange that takes too long.
      final fake = FakeRest()..answers.add(hang);
      result['no answer in time'] = {
        'failure': await failureOf(
          () => clientOf(fake, timeout: short).get('notes'),
        ),
        'exchanges': fake.exchanges.length,
        'stops': fake.stops,
      };
      // A provider with a bug still leaves the call its end.
      final deafOne = FakeRest()..answers.add(deaf);
      result['a provider that does not stop'] = await failureOf(
        () => clientOf(deafOne, timeout: short).post('notes'),
      );
      // The timeout of the call is before that of the client.
      final named = FakeRest()..answers.add(hang);
      result['the timeout of a call'] = await failureOf(
        () => clientOf(named).get('notes', timeout: short),
      );
      // Per attempt: three attempts that take most of it each.
      const part = Duration(milliseconds: 80);
      final again = reply(503, headers: {'retry-after': '0'});
      final slow = FakeRest()
        ..answers.addAll([
          Slowly(part, again),
          Slowly(part, again),
          Slowly(part, reply(200)),
        ]);
      result['the timeout is per attempt'] = await failureOf(
        () => clientOf(slow, timeout: const Duration(milliseconds: 150)).get(
          'notes',
        ),
      );
      result['the attempts of that call'] = slow.exchanges.length;

      // The timers of a call: one for each attempt, none left at its end.
      Future<Map<String, Object?>> timers(
        List<Object> answers, {
        FakeTokens? tokens,
      }) async {
        final seen = Waits();
        final transport = FakeRest()..answers.addAll(answers);
        final failure = await fast(
          seen,
          () => failureOf(
            () => clientOf(transport, tokens: tokens).get('notes'),
          ),
        );
        return {'failure': failure, ...seen.note};
      }

      result['the timers of an answer'] = await timers(const []);
      result['the timers of repeats'] = await timers([reply(503), reply(200)]);
      result['the timers of a refresh'] = await timers(
        [reply(401)],
        tokens: FakeTokens(),
      );
      result['the timers of a failure'] = await timers([reply(404)]);

      // A cancel.
      final before = RestCancel()..cancel();
      final none = FakeRest();
      result['a cancel before the call'] = {
        'failure': await failureOf(
          () => clientOf(none).get('notes', cancel: before),
        ),
        'exchanges': none.exchanges.length,
        'cancelled': before.isCancelled,
      };

      final during = RestCancel();
      final open = FakeRest()..answers.add(hang);
      final call = failureOf(() => clientOf(open).get('notes', cancel: during));
      await Future<void>.delayed(Duration.zero);
      during
        ..cancel()
        ..cancel();
      result['a cancel during the exchange'] = {
        'failure': await call,
        'stops': open.stops,
      };

      final deafCancel = RestCancel();
      final deafFake = FakeRest()..answers.add(deaf);
      final deafCall =
          failureOf(() => clientOf(deafFake).get('notes', cancel: deafCancel));
      await Future<void>.delayed(Duration.zero);
      deafCancel.cancel();
      result['a cancel of a provider that does not stop'] = await deafCall;

      final waiting = RestCancel();
      final wait = FakeRest()
        ..answers.add(reply(503, headers: {'retry-after': '30'}));
      final waitingCall =
          failureOf(() => clientOf(wait).get('notes', cancel: waiting));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      waiting.cancel();
      result['a cancel of a wait for a repeat'] = {
        'failure': await waitingCall,
        'exchanges': wait.exchanges.length,
      };

      // A cancel wakes a call that waits for a refresh, which goes on for the
      // others who share it.
      final hold = Completer<void>();
      final sharing = FakeTokens()..afterHold = hold.future;
      final refreshing = RestCancel();
      final refused = FakeRest()..answers.add(reply(401));
      final refreshCall = failureOf(
        () => clientOf(refused, tokens: sharing).get(
          'notes',
          cancel: refreshing,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      refreshing.cancel();
      result['a cancel of a wait for a refresh'] = {
        'failure': await refreshCall,
        'reads': sharing.calls,
      };
      hold.complete();

      // What comes after the end of a call goes nowhere.
      final late = Completer<RestReply>();
      final lateFake = _Late(late.future);
      result['an error after the timeout'] = await failureOf(
        () => clientOf(lateFake, timeout: short).get('notes'),
      );
      late.completeError(StateError('Too late.'));
      await Future<void>.delayed(Duration.zero);
      done.complete();
    },
    (error, stackTrace) => uncaught.add('$error'),
  );
  await done.future;
  result['uncaught'] = uncaught;
  port.send(result);
}

final class _Late implements RestTransport {
  _Late(this._answer);

  final Future<RestReply> _answer;

  @override
  Future<RestReply> send(RestExchange exchange) => _answer;
}
''';

/// What a debug build prints of a call with a token, a 401, a secret in the
/// query and failures.
const _log = r'''
Future<void> main(List<String> arguments, SendPort port) async {
  final fake = FakeRest()
    ..answers.addAll([
      reply(401),
      reply(200),
      const RestConnectionFailed('It broke.'),
      'hang',
    ]);
  final client = clientOf(
    fake,
    tokens: FakeTokens(token: 'secret-t0', next: 'secret-t1'),
  );
  await client.get('notes?key=secret-q', headers: {'x-key': 'secret-h'});
  final hints = <String>[
    await failureOf(() => client.post('notes', bytes: utf8.encode('secret-b'))),
    await failureOf(
      () => client.get('notes', timeout: const Duration(milliseconds: 5)),
    ),
  ];
  final seen = [...debugPrinted];
  result['the lines'] = [
    for (final line in seen) line.replaceFirst(RegExp(r'\d+ ms'), 'N ms'),
  ];
  result['what has a secret'] = [
    for (final text in [...seen, ...hints, for (final e in fake.exchanges) '$e'])
      if (text.contains('secret')) text,
  ];
  port.send(result);
}
''';

/// The client over the session of the app: one refresh for the requests at the
/// same time, what each failure of the provider becomes, and the token at each
/// moment of the session.
const _session = r'''
import 'package:my_app/core/auth/app_session.dart';
import 'package:my_app/core/rest/session_tokens.dart';
import 'package:my_app/fakes/fake_auth.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  final fake = FakeRest();
  final client = clientOf(fake, tokens: const SessionRestTokens());

  // Before the first start: a request waits at most the wait of the session,
  // and goes without a token when no service came.
  final seen = Waits();
  await fast(seen, () => client.get('before'));
  result['a request before the start'] = {
    'authorization': authorizationOf(fake.exchanges.removeLast()),
    'waits': seen.waits,
  };

  fakeAuth.putOnDevice('ada');
  await initAuth();
  result['the client of the app has the session'] =
      '${appRest.runtimeType}';

  await client.get('notes');
  result['the user on the device'] = authorizationOf(fake.exchanges.removeLast());

  // Eight requests at the same time.
  fake.answers.addAll([for (var call = 0; call < 8; call++) reply(401)]);
  await Future.wait([
    for (var call = 0; call < 8; call++) client.post('notes', json: call),
  ]);
  result['eight 401s'] = {
    'refreshes': fakeAuth.refreshes,
    'first tokens': {
      for (final exchange in fake.exchanges.take(8)) authorizationOf(exchange),
    },
    'tokens of the repeats': {
      for (final exchange in fake.exchanges.skip(8)) authorizationOf(exchange),
    },
    'exchanges': fake.exchanges.length,
  };
  fake.exchanges.clear();

  // A later 401 of the token that was refused needs no refresh.
  final rejected = await appSession.userToken();
  fakeAuth.refreshes = 0;
  fake.answers.add(reply(401));
  await client.get('notes');
  await appSession.userTokenAfter(rejected!);
  result['a 401 and a read of the same token'] = fakeAuth.refreshes;
  fake.exchanges.clear();

  // What each failure of the provider becomes, with the session as it is
  // after it, in a read and in a refresh.
  final reasons = <String, Object?>{};
  for (final reason in AuthFailureReason.values) {
    fakeAuth.failure = AuthFailure(reason, developerHint: 'From the provider.');
    final read = await failureOf(() => client.get('notes'));
    fakeAuth.refreshFailure =
        AuthFailure(reason, developerHint: 'From the provider.');
    fake.answers.add(reply(401));
    final refresh = await failureOf(() => client.get('notes'));
    reasons[reason.name] = {'read': read, 'refresh': refresh};
  }
  result['each failure'] = reasons;
  fakeAuth.failure = StateError('It broke.');
  result['another error of the provider'] =
      await failureOf(() => client.get('notes'));
  result['the session after those'] = appSession.value.uid;

  // A session that ended on the server: the provider signs the user out.
  fakeAuth
    ..failure = const AuthFailure(AuthFailureReason.recentSignInRequired)
    ..failureSignsOut = true;
  fake.exchanges.clear();
  result['a session that ended'] = {
    'failure': await failureOf(() => client.get('notes')),
    'exchanges': fake.exchanges.length,
    'session': appSession.value.uid,
  };
  fakeAuth.failureSignsOut = false;

  // Nobody is signed in now: no header, and a 401 refreshes nothing.
  fakeAuth.refreshes = 0;
  fake.answers.add(reply(401));
  result['nobody signed in'] = {
    'failure': await failureOf(() => client.get('notes')),
    'authorization': authorizationOf(fake.exchanges.last),
    'refreshes': fakeAuth.refreshes,
  };
  fake.exchanges.clear();

  // A user who changes while a 401 waits for its refresh.
  await appSession.signIn(email: 'ada@x.test', password: 'secret');
  final hold = fakeAuth.refreshHold = Completer<void>();
  fake.answers.add(reply(401));
  final changing = failureOf(() => client.post('notes', json: 1));
  await Future<void>.delayed(const Duration(milliseconds: 5));
  await appSession.signIn(email: 'grace@x.test', password: 'secret');
  hold.complete();
  result['another user during a refresh'] = {
    'failure': await changing,
    'exchanges': fake.exchanges.length,
    'session': appSession.value.uid,
  };
  fakeAuth.refreshHold = null;

  // The wait for a refresh has its bound, also when the provider takes a
  // minute to fail, as a forced read without a network does.
  final stuck = fakeAuth.refreshHold = Completer<void>();
  fake.answers.add(reply(401));
  final bounded = clientOf(
    fake,
    tokens: const SessionRestTokens(),
    tokenWait: const Duration(milliseconds: 10),
  );
  result['a refresh that does not end'] =
      await failureOf(() => bounded.get('notes'));
  stuck.complete();
  fakeAuth.refreshHold = null;
  port.send(result);
}
''';

/// A request that the app makes while it starts, and a request in the mode in
/// which the app signs in anonymously.
const _startUp = '''
import 'package:my_app/core/auth/app_session.dart';
import 'package:my_app/core/rest/session_tokens.dart';
import 'package:my_app/fakes/fake_auth.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  final fake = FakeRest();
  final client = clientOf(fake, tokens: const SessionRestTokens());
  fakeAuth.putOnDevice('ada');
  final request = client.get('early');
  await Future<void>.delayed(Duration.zero);
  result['it has reached the transport before the start'] =
      fake.exchanges.isNotEmpty;
  await initAuth();
  await request;
  result['it has the token of the user that the start found'] =
      authorizationOf(fake.exchanges.single);
  await appSession.signOut();
  await client.get('after');
  result['after a sign-out'] = authorizationOf(fake.exchanges.last);
  port.send(result);
}
''';

/// A call in an app built as a release build.
const _release = '''
Future<void> main(List<String> arguments, SendPort port) async {
  await clientOf(FakeRest()).get('notes');
  result['printed'] = debugPrinted;
  port.send(result);
}
''';

/// [script], a script of [_prelude] that has imports of its own, with them
/// among the imports of [_prelude].
String _withImports(String script) {
  const marker = 'Future<void> main(';
  final at = script.indexOf(marker);
  final imports = script.substring(0, at);
  final body = script.substring(at);
  const last = "import 'package:my_app/fakes/fake_rest.dart';\n";
  return '${_prelude.replaceFirst(last, '$last$imports')}\n$body';
}

const _providerModule = ModuleDescriptor(
  id: ModuleId('fake_rest'),
  description: 'REST',
  kind: ModuleKinds.infrastructure,
  providers: [RoleProvider.plain(restRole)],
);

const _feature = ModuleDescriptor(
  id: ModuleId('notes'),
  description: 'Notes',
  kind: ModuleKinds.feature,
  requires: {restRole},
);

/// The template of another role whose code could reach the transport.
final _otherRole = TestRole<NoDsl>('shop', requires: {restRole});

/// The implementation of the provider of the apps of the rules: its class in
/// one file and its function in another.
const _providerImplementation = RoleImplementation(
  type: TypeRef(
    'WireRestTransport',
    import: ImportRef.app('core/rest/wire_rest_transport.dart'),
  ),
  create: FactoryRef(
    'createWireRestTransport',
    import: ImportRef.app('core/rest/wire.dart'),
  ),
);

/// The file of the function of [_providerImplementation], which imports the
/// file of `RestTransport`, as the file of an implementation may.
const _factoryFile = DartFileIndex(
  path: 'lib/core/rest/wire.dart',
  imports: [IndexedImport('rest_transport.dart')],
  declarations: [
    IndexedDeclaration(
      name: 'createWireRestTransport',
      kind: DeclarationKind.function,
    ),
  ],
);

/// The issues of the structural rules of the role in an app of the provider
/// with [_providerImplementation] and with [files], each with its owner.
List<SmfIssue> _structureIssues(
  Map<DartFileIndex, ContributionOrigin?> files,
) =>
    restRole.checkStructure(
      StructuralRuleRequest(
        hook: RoleHookRequest(
          data: [
            dataOf(restRole, _providerImplementation, module: 'fake_rest'),
          ],
          presentRoles: {restRole},
          context: testContext,
        ),
        files: {
          _factoryFile.path: _factoryFile,
          for (final file in files.keys) file.path: file,
        },
        owners: {
          _factoryFile.path: ModuleOrigin(_providerModule.id),
          for (final MapEntry(key: file, value: owner) in files.entries)
            if (owner != null) file.path: owner,
        },
        modules: const [_providerModule, _feature],
      ),
    );

/// The index of the file at [path] that imports the file of `appRest` and
/// calls [function] of it, on [target] if it names one.
DartFileIndex _calling(String path, String function, {String? target}) =>
    DartFileIndex(
      path: path,
      imports: const [
        IndexedImport('package:my_app/core/rest/app_rest.dart'),
      ],
      invocations: [IndexedInvocation(function, target: target)],
    );

void main() {
  group('the REST role', () {
    test(
        'takes one provider, requires the values of the app, works with '
        'sign-in, and names no package', () {
      expect(restRole.id, 'rest');
      expect(restRole.description, 'REST API');
      expect(restRole.presenceFlag, 'has_rest');
      expect('$restRole', 'REST API role');
      expect(restRole.cardinality, RoleCardinality.atMostOne);
      expect(restRole.requires, {envRole});
      expect(restRole.uses, {authRole});
      // Its provider has what the role has, so the contract harness builds the
      // apps of a provider with sign-in and without.
      expect(_providerModule.effectiveUses, {authRole});
      expect(_providerModule.effectiveRequires, {envRole});
      expect(restRole.sockets, const [RestRole.implementations]);
      expect(RestRole.implementations.tag, 'smf_rest__implementations');
      expect(restRole.options, isEmpty);
      expect(
        [for (final rule in restRole.moduleRules) rule.id],
        ['services.implementations'],
      );
      expect(
        [for (final rule in restRole.structuralRules) rule.id],
        [
          'rest.factory_calls',
          'rest.use_calls',
          'rest.implementation_factories',
        ],
      );
    });

    test(
        'guarantees the files of the client, of the transport and of the '
        'tests, but not the file of the tokens of the session', () {
      expect(restRole.interface.files, [
        'lib/core/rest/app_rest.dart',
        'lib/core/rest/rest_transport.dart',
        'test/core/rest/rest_test_server.dart',
        'test/core/rest/app_rest_test.dart',
      ]);
      expect(restRole.interface.symbols, isEmpty);
      expect(RestRole.sessionTokensFile, 'lib/core/rest/session_tokens.dart');
      expect(RestRole.readmeHeading, 'REST API');
    });

    test(
        'has a key of its own for the address, which the env role takes from '
        'its template, and writes into the values of the app', () async {
      expect(RestRole.baseAddressKey.name, 'REST_BASE_URL');
      expect(RestRole.baseAddressKey.getter, 'restBaseUrl');
      final key = _contributions()
          .whereType<RoleData<EnvData>>()
          .single
          .withOrigin(_template);
      expect(key.role, same(envRole));
      expect(key.value, same(RestRole.baseAddressKey));
      expect(key.when, isEmpty);

      final data = <RoleData<Object>>[key];
      expect(envRole.template.validate(inputOf(envRole, data: data)), isEmpty);
      final values = await renderTemplate(envRole, data: data);
      for (final file in [EnvRole.dotEnvFile, EnvRole.exampleFile]) {
        expect(values.files[file], contains('\nREST_BASE_URL=\n'));
        expect(
          values.files[file],
          contains(
            '# The address of the REST API of the app, such as '
            'https://api.example.com/v1\n',
          ),
        );
      }
      expect(
        envRole.keysIn(inputOf(envRole, data: data)).single.owner,
        _template,
      );
    });

    test('lets the code of its template read the key, and no module', () {
      List<SmfIssue> read(ContributionOrigin owner) => envRole.checkStructure(
            StructuralRuleRequest(
              hook: RoleHookRequest(
                data: [
                  envRole.data(RestRole.baseAddressKey).withOrigin(_template),
                ],
                presentRoles: {envRole, restRole},
                context: testContext,
              ),
              files: const {
                'lib/file.dart': DartFileIndex(
                  path: 'lib/file.dart',
                  imports: [IndexedImport('core/env/app_env.dart')],
                  memberAccesses: [
                    IndexedMemberAccess('AppEnv', 'restBaseUrl'),
                  ],
                ),
              },
              owners: {'lib/file.dart': owner},
              modules: const [
                ModuleDescriptor(
                  id: ModuleId('notes'),
                  description: 'Notes',
                  kind: ModuleKinds.feature,
                  requires: {envRole},
                ),
              ],
            ),
          );

      expect(
        read(_template)
            .where((issue) => issue.message.contains('reads AppEnv')),
        isEmpty,
      );
      expect(
        read(const ModuleOrigin(ModuleId('notes')))
            .where((issue) => issue.message.contains('reads AppEnv')),
        hasLength(1),
      );
    });

    test('asks for the permission that a request needs in a release build', () {
      final socket =
          _contributions().whereType<SocketContribution>().singleWhere(
                (entry) =>
                    entry.socket == AppEntryRole.androidManifestPermissions,
              );
      expect(socket.entryKey, 'android.permission.INTERNET');
      expect(socket.when, isEmpty);
      expect(RestRole.internetPermission, 'android.permission.INTERNET');
    });

    test(
        'registers nothing in a DI container, has no step by hand and adds '
        'nothing to the start-up of the app', () async {
      final contributions = _contributions();
      expect(contributions.whereType<RoleData<DiRegistration>>(), isEmpty);
      expect(contributions.whereType<ManualStep>(), isEmpty);
      final rendered = await _rendered(auth: true);
      expect(
        rendered.elsewhere.where(
          (entry) =>
              entry.socket == AppEntryRole.bootstrapPlatform ||
              entry.socket == AppEntryRole.bootstrapLate,
        ),
        isEmpty,
      );
    });
  });

  group('the REST template', () {
    test(
        'generates the files of the role in every app, and the tokens of the '
        'session only in an app with sign-in', () async {
      final bricks = _contributions().whereType<BrickContribution>().toList();
      expect(
        [for (final brick in bricks) brick.bundle.name],
        [restRoleBundle.name, restRoleSessionBundle.name],
      );
      expect(
        [for (final brick in bricks) brick.when],
        [
          isEmpty,
          {authRole},
        ],
      );
      for (final auth in [false, true]) {
        final rendered = await _rendered(auth: auth);
        expect(
          rendered.files.keys.toSet(),
          {
            ...restRole.interface.files,
            if (auth) RestRole.sessionTokensFile,
          },
          reason: 'auth: $auth',
        );
        for (final MapEntry(key: path, value: text) in rendered.files.entries) {
          expectParses(text, reason: path);
        }
      }
    });

    test('renders the transport of the provider for the client of the app',
        () async {
      final rendered = await _rendered();
      final code = rendered.files[RestRole.clientFile]!;
      final unit = parseString(content: code).unit;

      expect(
        code,
        contains("import 'package:my_app/fakes/fake_rest.dart' as impl0;"),
      );
      expect(
        [
          for (final declaration
              in unit.declarations.whereType<TopLevelVariableDeclaration>())
            declaration.toSource(),
        ],
        contains(
          'final RestTransport _restTransport = impl0.createFakeRest();',
        ),
      );
    });

    test(
        'gives the client the tokens of the session in an app with sign-in, '
        'and none in another', () async {
      String tokensOf(String code) {
        final unit = parseString(content: code).unit;
        final variable = unit.declarations
            .whereType<TopLevelVariableDeclaration>()
            .singleWhere(
              (declaration) =>
                  declaration.variables.variables.single.name.lexeme ==
                  'appRest',
            );
        final call = variable.variables.variables.single.initializer!
            as MethodInvocation;
        return [
          for (final argument in call.argumentList.arguments)
            if (argument
                case NamedArgument(:final name, :final argumentExpression)
                when name.lexeme == 'tokens')
              argumentExpression.toSource(),
        ].single;
      }

      final without = await _rendered();
      final withAuth = await _rendered(auth: true);
      expect(tokensOf(without.files[RestRole.clientFile]!), 'null');
      expect(
        tokensOf(withAuth.files[RestRole.clientFile]!),
        'const SessionRestTokens()',
      );
      expect(
        withAuth.files[RestRole.clientFile],
        contains("import 'package:my_app/core/rest/session_tokens.dart';"),
      );
      expect(
        without.files[RestRole.clientFile],
        isNot(contains('session_tokens.dart')),
      );
    });

    test('generates the interface that a provider implements, with no import',
        () async {
      final rendered = await _rendered();
      final code = rendered.files[RestRole.transportFile]!;
      final unit = parseString(content: code).unit;
      final transport =
          unit.declarations.whereType<ClassDeclaration>().singleWhere(
                (declaration) =>
                    declaration.namePart.typeName.lexeme == 'RestTransport',
              );

      expect(unit.directives, isEmpty);
      expect(transport.abstractKeyword, isNotNull);
      expect(transport.interfaceKeyword, isNotNull);
      expect(
        declarationsOf(code),
        containsAll([
          'RestTransport.send',
          'RestExchange.method',
          'RestExchange.uri',
          'RestExchange.headers',
          'RestExchange.body',
          'RestExchange.stop',
          'RestReply.status',
          'RestReply.headers',
          'RestReply.bytes',
          'RestConnectionFailed.hint',
        ]),
      );
    });

    test('has the closed set of reasons of a failure', () async {
      final rendered = await _rendered();
      final reasons = parseString(content: rendered.files[RestRole.clientFile]!)
          .unit
          .declarations
          .whereType<EnumDeclaration>()
          .singleWhere(
            (declaration) =>
                declaration.namePart.typeName.lexeme == 'RestFailureReason',
          )
          .body
          .constants
          .map((constant) => constant.name.lexeme);

      expect(reasons, [
        'notConfigured',
        'network',
        'timeout',
        'cancelled',
        'unauthorized',
        'forbidden',
        'notFound',
        'conflict',
        'rejected',
        'tooManyRequests',
        'server',
        'invalidResponse',
        'unknown',
      ]);
    });

    test('names no package of a provider and no other protocol', () async {
      final rendered = await _rendered(auth: true);
      for (final MapEntry(key: path, value: text) in rendered.files.entries) {
        for (final word in ['dio', 'firebase', 'graphql', 'retrofit']) {
          expect(
            text,
            isNot(contains(RegExp('\\b$word\\b', caseSensitive: false))),
            reason: '$path: $word',
          );
        }
      }
      for (final note in [
        agentNoteOf(restRole),
        agentNoteOf(restRole, when: {authRole}),
      ]) {
        expect(note.text, isNot(contains(RegExp(r'\bdio\b'))));
      }
    });

    test(
        'refuses an implementation that is created asynchronously, since the '
        'role has no start-up phase, and the problems of an implementation',
        () async {
      const asynchronous = RoleImplementation.async(
        type: TypeRef('FakeRest', import: _fakeFile),
        init: FactoryRef('openFakeRest', import: _fakeFile),
      );
      final data = [dataOf(restRole, asynchronous, module: 'fake_rest')];

      final issue = restRole.template
          .validate(
            inputOf(restRole, data: data),
          )
          .single;
      expect(
        issue.message,
        'The openFakeRest of the REST API role starts asynchronously, but the '
        'role has no start-up phase.',
      );
      expect(issue.origin, const ModuleOrigin(ModuleId('fake_rest')));

      // Validation stops such an app, so nothing else reads what its render
      // hook gives: bootstrap() of the app gets nothing either way.
      final rendered = restRole.template.render(inputOf(restRole, data: data));
      expect(
        rendered.fragments.whereType<SocketContribution>().where(
              (entry) => entry.socket == AppEntryRole.bootstrapPlatform,
            ),
        isEmpty,
      );
      expect(
        rendered.fragments
            .whereType<SocketContribution>()
            .singleWhere((entry) => entry.socket == RestRole.implementations)
            .fragment!
            .code,
        contains('initRest'),
      );

      expect(
        restRole.template
            .validate(
              inputOf(
                restRole,
                data: [
                  dataOf(
                    restRole,
                    const RoleImplementation(
                      type: TypeRef('_Private'),
                      create: FactoryRef('create', import: _fakeFile),
                    ),
                    module: 'fake_rest',
                  ),
                ],
              ),
            )
            .single
            .origin,
        const ModuleOrigin(ModuleId('fake_rest')),
      );
    });
  });

  group('the generated client without sign-in', () {
    late DartFiles app;

    setUpAll(() async => app = await _app());

    tearDownAll(() => app.delete());

    test('is code that type-checks, with the tests and the code that uses it',
        () async {
      expect(await app.analysisProblems(), isEmpty);
    });

    test(
        'joins a relative path to the address, keeps a full address, and '
        'fails with notConfigured and the key without a usable address',
        () async {
      expect(await app.run('$_prelude$_addresses'), {
        'no leading slash': 'https://api.example.com/v1/notes',
        'a leading slash': 'https://api.example.com/v1/notes',
        'an address that ends with a slash': 'https://api.example.com/v1/notes',
        'an address without a path': 'https://api.example.com/notes',
        'no path': 'https://api.example.com/v1',
        'a path that names another server':
            'https://api.example.com/v1/evil.example/x',
        'a path that names a user of the server':
            'https://api.example.com/@evil.example/x',
        'a path with another scheme':
            'https://api.example.com/v1/ftp://evil.example/x',
        'a query': 'https://api.example.com/v1/notes?x=a%20b&y=c%26d&z%2B=1',
        'a query in the path and another one':
            'https://api.example.com/v1/notes?a=1%202&b=2',
        'a fragment': 'https://api.example.com/v1/notes',
        'a full address': 'https://files.example.com/a?sig=1',
        'a full address with capitals': 'https://files.example.com/a',
        'a full address with a query': 'http://other.example:8080/a?b=1&c=2',
        'addresses that a relative path cannot join': {
          for (final base in [
            'null',
            '',
            'api.example.com/v1',
            'ftp://api.example.com',
            'https://',
            'https://api.example.com/v1?key=1',
            'https://api.example.com/v1#top',
            'https://user:secret@api.example.com/v1',
          ])
            base: {
              'reason': 'notConfigured',
              'names the key': true,
              'quotes the value': false,
              'only the full address reached the transport': [
                'https://files.example.com/a',
              ],
            },
        },
        // AppEnv of the test app has this value.
        'the client of the app': 'https://env.example.com/v1/notes',
        'after use': 'https://test.example.com/notes',
        'after use of a transport': 'https://test.example.com/notes',
      });
    });

    test(
        'sends what the call gives, with its body as JSON or as bytes, and '
        'fails only with a RestFailure, of a closed set of reasons', () async {
      final result =
          (await app.run('$_prelude$_failures'))! as Map<Object?, Object?>;

      expect(result['what a request carries'], [
        {
          'method': 'POST',
          'headers': {'x-mixed': 'a', 'content-type': 'application/json'},
          'body': [123, 34, 116, 101, 120, 116, 34, 58, 34, 195, 169, 34, 125],
        },
        {
          'method': 'PUT',
          'headers': <String, String>{},
          'body': [1, 2],
        },
        {
          'method': 'PATCH',
          'headers': {'content-type': 'application/vnd.note+json'},
          'body': [123, 125],
        },
        {'method': 'DELETE', 'headers': <String, String>{}, 'body': null},
        {
          'method': 'DELETE',
          'headers': {'content-type': 'application/json'},
          'body': [49],
        },
        {'method': 'HEAD', 'headers': <String, String>{}, 'body': null},
        {'method': 'GET', 'headers': <String, String>{}, 'body': null},
      ]);

      Map<String, Object?> refusal(String reason, int status) => {
            'reason': reason,
            'status': status,
            'the body': '{"why":"no"}',
            'decoded': 'no',
          };
      expect(result['each status'], {
        '200': 'answer',
        '201': 'answer',
        '204': 'answer',
        // The answer to a conditional request that the caller made.
        '304': 'answer',
        '100': refusal('unknown', 100),
        '300': refusal('unknown', 300),
        '400': refusal('rejected', 400),
        // No token went with the request, so there is nothing to refresh.
        '401': refusal('unauthorized', 401),
        '403': refusal('forbidden', 403),
        '404': refusal('notFound', 404),
        '409': refusal('conflict', 409),
        '410': refusal('rejected', 410),
        '418': refusal('rejected', 418),
        '429': refusal('tooManyRequests', 429),
        '500': refusal('server', 500),
        '501': refusal('server', 501),
        '502': refusal('server', 502),
        '503': refusal('server', 503),
        '504': refusal('server', 504),
        '600': refusal('unknown', 600),
      });

      expect(result['a connection that failed'], 'network (It broke.)');
      // The text of an error may quote a header, so a hint has only its type.
      expect(
        result['an exception of a provider'],
        'unknown (The call ended with a StateError.)',
      );
      expect(
        result['an object that a provider threw'],
        'unknown (The call ended with a String.)',
      );
      expect(
        result['an error that a provider throws at once'],
        'unknown (The call ended with a FormatException.)',
      );
      expect(
        result['a body and bytes'],
        'unknown (A call takes json or bytes, not both.)',
      );
      expect(
        result['a body that is no JSON value'],
        'unknown (The call ended with a JsonUnsupportedObjectError.)',
      );
      expect(
        result['an address that is no address'],
        startsWith('unknown (The call ended with a FormatException'),
      );

      expect(result['decoded'], 1);
      expect(result['decoded with any JSON'], 2);
      // No hint has the text of an error, which may quote the body.
      expect(
        result['a body that is no JSON'],
        'invalidResponse 200 (The body does not fit: FormatException.)',
      );
      expect(result['a body of another type'], startsWith('invalidResponse'));
      expect(result['a parse that fails'], startsWith('invalidResponse'));
      expect(result['the failure of a parse has the answer'], 'nope');
      expect(result['a body that is no UTF-8'], '�');

      expect(result['as text'], [
        'RestFailure(cancelled)',
        'RestFailure(notFound, 404: No.)',
        'RestResponse(200)',
        'RestConnectionFailed: It broke.',
        'RestExchange(POST https://api.example.com/v1/notes)',
        // No user, no query and no header.
        'RestExchange(GET https://x.example/a)',
      ]);
    });

    test(
        'gives the token to the origin of the app alone, also over redirects, '
        'and leaves a header of the caller', () async {
      final result =
          (await app.run('$_prelude$_tokens'))! as Map<Object?, Object?>;

      Map<String, Object?> sent(
        List<String> sent, {
        List<String> reads = const ['current'],
        String failure = 'no failure',
      }) =>
          {'sent': sent, 'reads': reads, 'failure': failure};
      const app_ = 'https://api.example.com';
      const none = 'null null null null';
      const token = 'Bearer t0 null null null';

      expect(result['the origin of the app'], sent(['$app_ $token']));
      expect(result['a full address of that origin'], sent(['$app_ $token']));
      expect(
        result['another host'],
        sent(['https://other.example $none'], reads: const []),
      );
      expect(
        result['a subdomain'],
        sent(['https://sub.api.example.com $none'], reads: const []),
      );
      expect(
        result['another port'],
        sent(['$app_:8443 $none'], reads: const []),
      );
      expect(
        result['another scheme'],
        sent(['http://api.example.com $none'], reads: const []),
      );
      expect(result['nobody signed in'], sent(['$app_ $none']));
      expect(
        result['an address without an origin of the app'],
        sent(['https://other.example $none'], reads: const []),
      );
      expect(
        result['a header of the caller'],
        sent(['$app_ Bearer mine null null null'], reads: const []),
      );
      expect(
        result['a redirect in the origin of the app'],
        sent(
          ['$app_ Bearer t0 c p m', '$app_ Bearer t0 c p m'],
          reads: const ['current', 'current'],
        ),
      );
      // The headers of the caller stay away, and only a hop back to the app
      // gets its token.
      expect(
        result['a redirect to another host, and back to the app'],
        sent(
          [
            '$app_ Bearer t0 c p m',
            'https://other.example null null null m',
            '$app_ Bearer t0 null null m',
          ],
          reads: const ['current', 'current'],
        ),
      );
      expect(
        result['a redirect to a subdomain'],
        sent(['$app_ $token', 'https://sub.api.example.com $none']),
      );
      expect(
        result['a redirect from https to http on the host'],
        sent(['$app_ $token', 'http://api.example.com $none']),
      );
      expect(
        result['a redirect of a full address to the app'],
        sent(['https://other.example $none', '$app_ $token']),
      );
      // The header of the caller stops at the other host, and no token takes
      // its place on the way back.
      expect(
        result['a redirect of a call with a header of its own'],
        sent(
          [
            '$app_ Bearer mine null null null',
            'https://other.example $none',
            '$app_ $none',
          ],
          reads: const [],
        ),
      );
      expect(
        (result['a redirect of a POST']! as Map)['failure'],
        startsWith('unknown 302 (The server answered a POST with a redirect'),
      );
      expect(
        (result['a redirect of a POST']! as Map)['sent'],
        hasLength(1),
      );
      expect(
        (result['a redirect without a location']! as Map)['failure'],
        'unknown 302 (A redirect without a location.)',
      );
      expect(
        (result['a redirect to another scheme']! as Map)['failure'],
        'unknown 302 (A redirect to an address that is no http or https one.)',
      );
      expect(result['five redirects'], 'no failure');
      expect(
        result['six redirects'],
        'unknown 302 (More than 5 redirects.)',
      );
      expect(
        result['a status of 3xx that is no redirect'],
        'unknown 300 (The server answered with the status 300.)',
      );
    });

    test(
        'gets a new token once on a 401 and repeats once, for every method, '
        'and for the same user alone', () async {
      final result =
          (await app.run('$_prelude$_refreshes'))! as Map<Object?, Object?>;
      const otherUser = 'unauthorized 401 (The user of the session changed '
          'during the call, so it did not repeat for the new user.)';

      expect(result['one 401'], {
        'sent': ['Bearer t0 "body"', 'Bearer t1 "body"'],
        'reads': ['current', 'after t0'],
        'failure': 'no failure',
      });
      // No second refresh, and no repeat of it. The client signs nobody out.
      expect(result['a second 401'], {
        'sent': ['Bearer t0 "body"', 'Bearer t1 "body"'],
        'reads': ['current', 'after t0'],
        'failure': 'unauthorized 401',
      });
      expect(result['a refresh that finds nobody'], {
        'sent': ['Bearer t0 "body"'],
        'reads': ['current', 'after t0'],
        'failure': otherUser,
      });
      expect(result['another user during the refresh'], {
        'sent': ['Bearer t0 "body"'],
        'reads': ['current', 'after t0'],
        'failure': otherUser,
      });
      expect(result['a refresh that fails'], {
        'sent': ['Bearer t0 "body"'],
        'reads': ['current', 'after t0'],
        'failure': 'network (No network.)',
      });
      expect(
        (result['a refresh that throws something else']! as Map)['failure'],
        'unknown (The call ended with a StateError.)',
      );
      // A read that fails sends nothing.
      expect(result['a read that fails'], {
        'sent': <Object?>[],
        'reads': ['current'],
        'failure': 'tooManyRequests',
      });
      expect(result['a 401 without a token'], {
        'sent': ['null "body"'],
        'reads': ['current'],
        'failure': 'unauthorized 401',
      });
      expect(result['a 401 of a header of the caller'], {
        'sent': ['Bearer mine "body"'],
        'reads': <Object?>[],
        'failure': 'unauthorized 401',
      });
      expect(result['a 401 of another origin'], {
        'sent': ['null "body"'],
        'reads': <Object?>[],
        'failure': 'unauthorized 401',
      });
      // A forced read without a network may take a minute before it fails.
      expect(result['a refresh that takes too long'], {
        'sent': ['Bearer t0 "body"'],
        'reads': ['current', 'after t0'],
        'failure': 'timeout (The token of the user did not come within 10 ms.)',
      });
      expect(result['a read that takes too long'], {
        'sent': <Object?>[],
        'reads': ['current'],
        'failure': 'timeout (The token of the user did not come within 10 ms.)',
      });

      // A repeat is for the user who made the request.
      expect(result['another user before a repeat'], {
        'sent': ['Bearer t0'],
        'failure': otherUser.replaceFirst(' 401', ''),
      });
      expect(result['nobody before a repeat'], {
        'sent': ['Bearer t0'],
        'failure': otherUser.replaceFirst(' 401', ''),
      });
      // A request of nobody was made for no user, as when the app starts.
      expect(result['a user who came before a repeat of a request of nobody'], {
        'sent': [null, 'Bearer of ada'],
        'failure': 'no failure',
      });
      expect(result['a user who comes during the first read'], {
        'sent': ['Bearer of ada "body"'],
        'reads': ['current', 'current'],
        'failure': 'no failure',
      });
    });

    test(
        'repeats GET and HEAD after a connection that failed and after 429, '
        '502, 503 and 504, and no other method', () async {
      final result =
          (await app.run('$_prelude$_repeats'))! as Map<Object?, Object?>;

      void expectFirstWaits(Object? run) {
        final waits = (run! as Map)['waits'] as List;
        expect(waits, hasLength(2));
        expect(waits[0], inInclusiveRange(500, 749));
        expect(waits[1], inInclusiveRange(1000, 1249));
      }

      final connection =
          result['a connection that failed']! as Map<Object?, Object?>;
      for (final method in ['GET', 'HEAD']) {
        expectFirstWaits(connection[method]);
        expect(without(connection[method]! as Map, 'waits'), {
          'exchanges': 3,
          'reason': 'network',
          'retryAfter': null,
          'limits': 3,
          'timers left': 0,
        });
      }
      for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
        expect(connection[method], {
          'exchanges': 1,
          'reason': 'network',
          'retryAfter': null,
          'waits': <Object?>[],
          'limits': 1,
          'timers left': 0,
        });
      }
      expect(
        (result['a connection that comes back']! as Map)['reason'],
        isNull,
      );

      final statuses =
          result['each status of a repeat']! as Map<Object?, Object?>;
      for (final MapEntry(key: status, value: methods) in statuses.entries) {
        final reason = status == '429' ? 'tooManyRequests' : 'server';
        final each = methods! as Map<Object?, Object?>;
        for (final method in ['GET', 'HEAD']) {
          expectFirstWaits(each[method]);
          expect(
            (each[method]! as Map)['exchanges'],
            3,
            reason: '$status $method',
          );
          expect((each[method]! as Map)['reason'], reason);
        }
        for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
          expect((each[method]! as Map)['exchanges'], 1, reason: '$status');
          expect((each[method]! as Map)['reason'], reason);
          expect((each[method]! as Map)['waits'], isEmpty);
        }
      }
      for (final run
          in (result['each other status']! as Map<Object?, Object?>).values) {
        expect((run! as Map)['exchanges'], 1);
        expect((run as Map)['waits'], isEmpty);
      }

      Map<String, Object?> repeated(List<int> waits) => {
            'exchanges': 2,
            'reason': null,
            'retryAfter': null,
            'waits': waits,
            'limits': 2,
            'timers left': 0,
          };
      expect(result['Retry-After in seconds'], repeated([7000]));
      expect(result['Retry-After of no wait'], repeated([0]));
      expect(result['Retry-After at the limit'], repeated([30000]));
      expect(result['Retry-After in the past'], repeated([0]));
      expect(result['Retry-After as a date'], isTrue);
      expect(result['Retry-After over the limit'], {
        'exchanges': 1,
        'reason': 'server',
        'retryAfter': 31,
        'waits': <Object?>[],
        'limits': 1,
        'timers left': 0,
      });
      for (final form in [
        'Retry-After in a form of no use',
        'Retry-After below zero',
        'Retry-After with a month of no use',
      ]) {
        final run = result[form]! as Map;
        expect(run['exchanges'], 2, reason: form);
        expect((run['waits'] as List).single, inInclusiveRange(500, 749));
      }
      expect(result['Retry-After after the repeats'], {
        'exchanges': 3,
        'reason': 'server',
        'retryAfter': 3,
        'waits': [1000, 2000],
        'limits': 3,
        'timers left': 0,
      });
      expect(result['Retry-After of a POST'], {
        'exchanges': 1,
        'reason': 'tooManyRequests',
        'retryAfter': 5,
        'waits': <Object?>[],
        'limits': 1,
        'timers left': 0,
      });
    });

    test(
        'has a timeout for each attempt, which no provider can get around, '
        'and ends a call at a cancel, and leaves no timer behind', () async {
      final result =
          (await app.run('$_prelude$_stops'))! as Map<Object?, Object?>;
      const late = 'timeout (No complete answer within 20 ms.)';

      // Never repeated: the user has waited long enough.
      expect(result['no answer in time'], {
        'failure': late,
        'exchanges': 1,
        'stops': 1,
      });
      expect(result['a provider that does not stop'], late);
      expect(result['the timeout of a call'], late);
      // Each attempt has the whole timeout, so the call takes longer.
      expect(result['the timeout is per attempt'], 'no failure');
      expect(result['the attempts of that call'], 3);

      expect(result['the timers of an answer'], {
        'failure': 'no failure',
        'waits': <Object?>[],
        'limits': 1,
        'timers left': 0,
      });
      expect(
        without(result['the timers of repeats']! as Map, 'waits'),
        {'failure': 'no failure', 'limits': 2, 'timers left': 0},
      );
      // The read, the exchange, the wait for the refresh and its token, and
      // the repeat: each with a timer that ended.
      final refresh = result['the timers of a refresh']! as Map;
      expect(refresh['failure'], 'no failure');
      expect(refresh['timers left'], 0);
      expect(result['the timers of a failure'], {
        'failure': 'notFound 404',
        'waits': <Object?>[],
        'limits': 1,
        'timers left': 0,
      });

      expect(result['a cancel before the call'], {
        'failure': 'cancelled',
        'exchanges': 0,
        'cancelled': true,
      });
      expect(result['a cancel during the exchange'], {
        'failure': 'cancelled',
        'stops': 1,
      });
      expect(result['a cancel of a provider that does not stop'], 'cancelled');
      expect(result['a cancel of a wait for a repeat'], {
        'failure': 'cancelled',
        'exchanges': 1,
      });
      // The refresh that others share goes on.
      expect(result['a cancel of a wait for a refresh'], {
        'failure': 'cancelled',
        'reads': ['current', 'after t0'],
      });
      expect(result['an error after the timeout'], late);
      expect(result['uncaught'], isEmpty);
    });

    test(
        'prints one line for each attempt in debug mode, with no token, no '
        'query, no header and no body', () async {
      expect(await app.run('$_prelude$_log'), {
        'the lines': [
          'REST GET https://api.example.com/v1/notes 401 (N ms)',
          'REST GET https://api.example.com/v1/notes 200 (N ms)',
          'REST POST https://api.example.com/v1/notes network (N ms)',
          'REST GET https://api.example.com/v1/notes timeout (N ms)',
        ],
        'what has a secret': <Object?>[],
      });
    });
  });

  group('the generated client in a release build', () {
    late DartFiles app;

    setUpAll(() async => app = await _app(debug: false));

    tearDownAll(() => app.delete());

    test('prints nothing', () async {
      expect(
        await app.run('$_prelude$_release'),
        {'printed': <Object?>[]},
      );
    });
  });

  group('the generated client with the session of the app', () {
    late DartFiles app;

    setUpAll(() async => app = await _app(auth: true));

    tearDownAll(() => app.delete());

    test('is code that type-checks, and the client of the app has the session',
        () async {
      expect(await app.analysisProblems(), isEmpty);
    });

    test(
        'makes one refresh for requests at the same time, maps every failure '
        'of the token, and repeats nothing for another user', () async {
      final result =
          (await app.run(_withImports(_session)))! as Map<Object?, Object?>;

      // No service by the end of the wait: no header.
      expect(result['a request before the start'], {
        'authorization': null,
        'waits': [3000],
      });
      expect(result['the user on the device'], 'Bearer ada-0');
      expect(result['eight 401s'], {
        'refreshes': 1,
        'first tokens': {'Bearer ada-0'},
        'tokens of the repeats': {'Bearer ada-1'},
        'exchanges': 16,
      });
      // The client refreshed once, and the read after it finds the new token.
      expect(result['a 401 and a read of the same token'], 1);

      const hint = ' (From the provider.)';
      final failures = result['each failure']! as Map<Object?, Object?>;
      String reasonOf(String auth) => switch (auth) {
            'network' => 'network',
            'tooManyAttempts' => 'tooManyRequests',
            'recentSignInRequired' || 'userDisabled' => 'unauthorized',
            _ => 'unknown',
          };
      expect(failures.keys, hasLength(12));
      for (final MapEntry(key: reason, value: outcome) in failures.entries) {
        final mapped = '${reasonOf(reason! as String)}$hint';
        expect(
          outcome,
          {'read': mapped, 'refresh': mapped},
          reason: '$reason',
        );
      }
      expect(
        result['another error of the provider'],
        'unknown (Bad state: It broke.)',
      );
      expect(result['the session after those'], 'ada');
    });

    test(
        'fails a request when the session ended on the server, and sends none '
        'for a user who is gone', () async {
      final result =
          (await app.run(_withImports(_session)))! as Map<Object?, Object?>;

      expect(result['a session that ended'], {
        'failure': 'unauthorized',
        'exchanges': 0,
        'session': null,
      });
      expect(result['nobody signed in'], {
        'failure': 'unauthorized 401',
        'authorization': null,
        'refreshes': 0,
      });
      expect(result['another user during a refresh'], {
        'failure': 'unauthorized 401 (The user of the session changed during '
            'the call, so it did not repeat for the new user.)',
        'exchanges': 1,
        'session': 'grace',
      });
      expect(
        result['a refresh that does not end'],
        'timeout (The token of the user did not come within 10 ms.)',
      );
    });

    test('takes the token that the start found, for a request at the start-up',
        () async {
      expect(await app.run(_withImports(_startUp)), {
        'it has reached the transport before the start': false,
        'it has the token of the user that the start found': 'Bearer ada-0',
        'after a sign-out': null,
      });
    });
  });

  group('the notes of the REST role for coding agents', () {
    late Map<String, String> files;

    setUpAll(() async {
      final rest = await _rendered(auth: true);
      final session = await renderTemplate(
        authRole,
        data: [
          dataOf(
            authRole,
            const AuthImplementation(
              type: TypeRef('FakeAuth', import: _fakeAuthFile),
              create: FactoryRef('createFakeAuth', import: _fakeAuthFile),
            ),
            module: 'fake_auth',
          ),
        ],
        choice: AuthMode.required,
      );
      files = {...rest.files, ...session.files};
    });

    test('name what the files of the role declare', () {
      expectNamesOfCode(
        agentNoteOf(restRole),
        {
          RestRole.clientFile: [
            'appRest',
            'AppRestClient',
            'AppRestClient.get',
            'AppRestClient.post',
            'AppRestClient.put',
            'AppRestClient.patch',
            'AppRestClient.delete',
            'AppRestClient.head',
            'AppRestClient.use',
            'AppRestClient.timeout',
            'RestResponse.decoded',
            'RestFailure',
            'RestFailure.reason',
            'RestFailure.response',
            'RestFailure.developerHint',
            'RestFailureReason.invalidResponse',
            'RestFailureReason.notConfigured',
            'RestCancel',
            'createRestTransport',
          ],
          RestRole.transportFile: ['RestTransport'],
          RestRole.testServerFile: ['RestTestServer'],
        },
        files: files,
      );
      expectNamesOfCode(
        agentNoteOf(restRole, when: {authRole}),
        {
          AuthRole.sessionFile: [
            'appSession',
            'AppSessionController.anonymousWait',
            'initAuth',
          ],
          RestRole.clientFile: ['RestFailureReason.unauthorized'],
        },
        files: files,
      );
    });

    test(
        'say that the timeout is per attempt, name the key, and tell what a '
        'request at the start-up meets', () {
      final note = agentNoteOf(restRole).text;
      expect(note, contains('per attempt'));
      expect(note, contains('`${RestRole.baseAddressKey.name}`'));
      expect(note, contains('`${EnvRole.dotEnvFile}`'));

      final token = agentNoteOf(restRole, when: {authRole}).text;
      expect(token, contains('`${RestRole.sessionTokensFile}`'));
      expect(token, contains('before `initAuth()` is over'));
      expect(token, contains('without a token'));
    });
  });

  group('the section of the REST role in the README of the app', () {
    /// The section in an app with sign-in, or without it.
    Future<String> sectionWith({required bool auth}) async {
      final rendered = await _rendered(auth: auth);
      final sections = rendered.elsewhere.where(
        (entry) => entry.socket == AppEntryRole.readmeSections,
      );
      expect(sections.single.entryKey, RestRole.readmeHeading);
      return sections.single.entryValue! as String;
    }

    test('names the key, the section of the values and says to use https',
        () async {
      final section = await sectionWith(auth: false);
      expect(section, contains('`REST_BASE_URL`'));
      expect(section, contains('"${EnvRole.readmeHeading}"'));
      expect(section, contains('`notConfigured`'));
      expect(section, contains('Use `https` in a release.'));
      expect(section, contains('`${RestRole.testServerFile}`'));
      expect(section, contains('per attempt'));
    });

    test('tells of the token in an app with sign-in alone', () async {
      final without = await sectionWith(auth: false);
      final withAuth = await sectionWith(auth: true);
      expect(without, isNot(contains('appSession')));
      expect(withAuth, contains('`appSession`'));
      expect(withAuth, contains('signs nobody out'));
      // The same text around it, with one empty line between the paragraphs.
      expect(without, isNot(contains('\n\n\n')));
      expect(withAuth, isNot(contains('\n\n\n')));
    });

    test('gives only names that the files of the role declare', () async {
      final rest = await _rendered(auth: true);
      expectNamesOfCodeIn(
        await sectionWith(auth: false),
        {
          RestRole.clientFile: [
            'appRest',
            'RestFailure',
            'RestFailure.reason',
            'RestFailure.developerHint',
            'RestFailure.response',
            'RestFailure.retryAfter',
            'RestCancel',
            'RestResponse.decoded',
            'AppRestClient.use',
            'AppRestClient.timeout',
          ],
          RestRole.testServerFile: ['RestTestServer'],
        },
        files: rest.files,
      );
    });
  });

  group('the rules of the REST role', () {
    const providerFile = 'lib/core/rest/wire_rest_transport.dart';
    const screen = 'lib/features/notes/notes_state.dart';
    const ofProvider = ModuleOrigin(ModuleId('fake_rest'));
    const ofFeature = ModuleOrigin(ModuleId('notes'));
    const hint = 'Make requests through appRest of '
        'lib/core/rest/app_rest.dart.';

    test(
        'let each provider contribute one implementation, and no module put '
        'code into the socket of the implementation', () {
      List<SmfIssue> issuesOf(
        ModuleDescriptor module, {
        List<RoleImplementation> implementations = const [],
        List<Contribution> contributions = const [],
      }) =>
          restRole.checkModule(
            ModuleRuleRequest(
              hook: RoleHookRequest(
                data: [
                  for (final implementation in implementations)
                    restRole
                        .data(implementation)
                        .withOrigin(ModuleOrigin(module.id)),
                ],
                presentRoles: {restRole},
                context: testContext,
              ),
              module: module,
              contributions: contributions,
            ),
          );

      expect(
        issuesOf(_providerModule, implementations: [_implementation]),
        isEmpty,
      );
      expect(issuesOf(_feature), isEmpty);
      expect(
        issuesOf(_providerModule).single.message,
        contains('exactly one implementation, but the module contributes 0'),
      );
      expect(
        issuesOf(_feature, implementations: [_implementation]).single.message,
        contains('which only its providers do'),
      );
      expect(
        issuesOf(
          _providerModule,
          implementations: [_implementation],
          contributions: const [
            SocketContribution.code(
              RestRole.implementations,
              Fragment('final RestTransport _restTransport = Wire();'),
            ),
          ],
        ).single.message,
        contains('socket rest.implementations'),
      );
    });

    test(
        'rest.factory_calls: a file of a module, or of the template of another '
        'role, that calls createRestTransport() is reported', () {
      final issues = _structureIssues({
        _calling(providerFile, 'createRestTransport'): ofProvider,
        _calling(screen, 'createRestTransport'): ofFeature,
        _calling('lib/core/shop/shop.dart', 'createRestTransport'):
            RoleTemplateOrigin(_otherRole),
        // A file of the template of the role itself, and files that neither a
        // module nor the template of a role owns.
        _calling('lib/core/rest/more.dart', 'createRestTransport'): _template,
        _calling('lib/generated.dart', 'createRestTransport'):
            const PipelineOrigin(),
        _calling('lib/mine.dart', 'createRestTransport'): null,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (providerFile, ofProvider),
          (screen, ofFeature),
          ('lib/core/shop/shop.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      for (final issue in issues) {
        expect(
          issue.message,
          '${issue.path} calls createRestTransport(), which no module may '
          'call.',
        );
        expect(issue.hint, hint);
      }
    });

    test(
        'rest.factory_calls: only the files of the implementation of the '
        'provider import the file of RestTransport, so a module has no way to '
        'a second client', () {
      const ofClass = DartFileIndex(
        path: providerFile,
        imports: [IndexedImport('rest_transport.dart')],
      );
      const other = DartFileIndex(
        path: screen,
        imports: [
          IndexedImport('package:my_app/core/rest/rest_transport.dart'),
        ],
      );
      const exporting = DartFileIndex(
        path: 'lib/core/shop/shop.dart',
        exports: [IndexedImport('../rest/rest_transport.dart')],
      );

      final issues = _structureIssues({
        ofClass: ofProvider,
        other: ofFeature,
        exporting: RoleTemplateOrigin(_otherRole),
      });

      expect(
        [for (final issue in issues) issue.path],
        [screen, 'lib/core/shop/shop.dart'],
      );
      expect(
        issues.first.message,
        '$screen imports lib/core/rest/rest_transport.dart, the file of '
        'RestTransport, which only the files of the implementation of the '
        'provider of the REST API role import.',
      );
    });

    test(
        'rest.use_calls: a file of a module, or of the template of another '
        'role, that calls appRest.use() is reported', () {
      final issues = _structureIssues({
        _calling(screen, 'use', target: 'appRest'): ofFeature,
        _calling('lib/core/shop/shop.dart', 'use', target: 'appRest'):
            RoleTemplateOrigin(_otherRole),
        // The template of the role itself, and code of the developer.
        _calling('lib/core/rest/more.dart', 'use', target: 'appRest'):
            _template,
        _calling('lib/mine.dart', 'use', target: 'appRest'): null,
        // Another object, and another method.
        _calling('lib/features/notes/a.dart', 'use', target: 'other'):
            ofFeature,
        _calling('lib/features/notes/b.dart', 'get', target: 'appRest'):
            ofFeature,
      });

      expect(
        [for (final issue in issues) (issue.path, issue.origin)],
        [
          (screen, ofFeature),
          ('lib/core/shop/shop.dart', RoleTemplateOrigin(_otherRole)),
        ],
      );
      expect(
        issues.first.message,
        '$screen calls appRest.use(), which only a test calls.',
      );
      expect(issues.first.hint, hint);
    });

    test('rest.implementation_factories: the function is in its file', () {
      final issues = restRole.checkStructure(
        StructuralRuleRequest(
          hook: RoleHookRequest(
            data: [
              dataOf(restRole, _providerImplementation, module: 'fake_rest'),
            ],
            presentRoles: {restRole},
            context: testContext,
          ),
          files: const {},
        ),
      );

      expect(issues, hasLength(1));
      expect(issues.single.origin, const ModuleOrigin(ModuleId('fake_rest')));
      expect(issues.single.hint, contains('without arguments'));
    });
  });
}

/// [map] without [key].
Map<Object?, Object?> without(Map<Object?, Object?> map, String key) =>
    {...map}..remove(key);
