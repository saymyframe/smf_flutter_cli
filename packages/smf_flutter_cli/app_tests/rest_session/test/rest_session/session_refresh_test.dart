// A test that continuous integration runs in the apps with the REST role and
// the auth role, whichever modules provide them, in each mode of the auth role:
// a token that a server refuses is replaced once, whatever the number of
// requests that it refused at the same time. A refresh that fails ends the call
// with what the session says, a request of one user never repeats as another,
// and a second 401 signs nobody out.
//
// It knows only the roles. The start-up of the app runs first, with the mocks of
// every module of the app, and each test then gives the session the service of
// the provider behind a counter of the refreshes. Each test uses an email
// address of its own.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import '../auth_role/auth_role.dart';
import '../core/rest/rest_test_server.dart';
import 'rest_session.dart';

/// Matches a failure with [reason].
Matcher _failsWith(RestFailureReason reason) =>
    isA<RestFailure>().having((failure) => failure.reason, 'reason', reason);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Timeout(Duration(minutes: 2));

  /// Runs [body] for the user of a new account with the address of [name], with
  /// a server of the test as the address of the client of the app and with the
  /// service of the provider behind a counter.
  Future<void> withUser(
    WidgetTester tester,
    String name,
    Future<void> Function(RestTestServer server, TokenCounter service) body,
  ) async {
    await startUp(tester);
    await inRealTime(tester, 'the requests of the test', () async {
      final server = await RestTestServer.start();
      try {
        appRest.use(baseAddress: server.address);
        final service = TokenCounter(createAuthService());
        await appSession.start(service);
        await appSession.signOut();
        await appSession.signUp(email: addressOf(name), password: password);
        await body(server, service);
      } finally {
        await server.close();
      }
    });
  }

  testWidgets(
    'requests that a server refuses at the same time share one refresh, and '
    'each repeats once',
    (tester) async {
      const count = 8;
      late List<Object> outcomes;
      late int refreshes;
      late int later;
      late int requests;

      await withUser(tester, 'rest-together', (server, service) async {
        final first = await appSession.userToken();
        var refused = 0;
        final allRefused = Completer<void>();
        server.answer('GET', '/notes', (request) async {
          // The server holds its answers until every request has the token of
          // before, so all of them are refused for the same token.
          if (request.headers.value('authorization') == 'Bearer $first') {
            if (++refused == count) allRefused.complete();
            await allRefused.future;
            request.response.statusCode = 401;
          }
          await request.response.close();
        });

        outcomes = await Future.wait([
          for (var call = 0; call < count; call++)
            outcomeOf(appRest.get('notes')),
        ]);
        refreshes = service.refreshes;
        requests = server.requests.length;
        // A request that the server refused a moment later takes the token of
        // that refresh, and asks for no other.
        await appSession.userTokenAfter(first ?? '');
        later = service.refreshes;
      });

      expect(
        outcomes,
        everyElement(isA<RestResponse>()),
        reason: 'A request that a server refused repeats with the new token.',
      );
      expect(
        refreshes,
        1,
        reason: 'Requests at the same time share one refresh.',
      );
      expect(requests, count * 2, reason: 'Each request repeats once.');
      expect(later, 1, reason: 'A later request needs no other refresh.');
    },
    timeout: timeout,
  );

  testWidgets(
    'a refresh that fails for the network ends the call with the reason '
    'network, and the session stays',
    (tester) async {
      Object? outcome;
      String? uid;
      String? uidAfter;

      await withUser(tester, 'rest-offline', (server, service) async {
        server.answerJson('GET', '/notes', null, status: 401);
        uid = appSession.value.uid;
        service.onRefresh =
            () async => throw const AuthFailure(AuthFailureReason.network);
        outcome = await outcomeOf(appRest.get('notes'));
        uidAfter = appSession.value.uid;
      });

      expect(
        outcome,
        _failsWith(RestFailureReason.network),
        reason: 'A token that does not come for want of a network is the '
            'reason of a request without a network.',
      );
      expect(uidAfter, uid, reason: 'The user stays signed in.');
    },
    timeout: timeout,
  );

  testWidgets(
    'a session that ended on the server ends the call with unauthorized, and '
    'the session has signed the user out',
    (tester) async {
      Object? outcome;
      String? uid;
      String? uidAfter;

      await withUser(tester, 'rest-ended', (server, service) async {
        server.answerJson('GET', '/notes', null, status: 401);
        uid = appSession.value.uid;
        service.onRefresh = () async {
          // A provider signs a user out whose session has ended.
          await service.signOut();
          throw const AuthFailure(AuthFailureReason.recentSignInRequired);
        };
        outcome = await outcomeOf(appRest.get('notes'));
        await waitForNextUser();
        uidAfter = appSession.value.uid;
      });

      expect(
        outcome,
        _failsWith(RestFailureReason.unauthorized),
        reason: 'The request has no user any more.',
      );
      expect(
        uidAfter == uid,
        isFalse,
        reason: 'The session follows the provider, which signed the user out.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a request of one user does not repeat as the user who signs in while it '
    'waits for a new token',
    (tester) async {
      Object? outcome;
      late int requests;

      await withUser(tester, 'rest-first-user', (server, service) async {
        server.answerJson('GET', '/notes', null, status: 401);
        service.onRefresh = () async {
          await service.signOut();
          await service.signUp(
            email: addressOf('rest-next-user'),
            password: password,
          );
          await waitForNextUser();
          return service.userToken();
        };
        outcome = await outcomeOf(appRest.get('notes'));
        requests = server.requests.length;
      });

      expect(
        outcome,
        _failsWith(RestFailureReason.unauthorized),
        reason: 'The user changed during the call.',
      );
      expect(
        requests,
        1,
        reason: 'A request of one user never repeats as another.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a second 401 fails with unauthorized, and signs nobody out',
    (tester) async {
      Object? outcome;
      late int refreshes;
      String? uid;
      String? uidAfter;

      await withUser(tester, 'rest-refused', (server, service) async {
        server.answerJson('GET', '/notes', null, status: 401);
        uid = appSession.value.uid;
        outcome = await outcomeOf(appRest.get('notes'));
        refreshes = service.refreshes;
        uidAfter = appSession.value.uid;
      });

      expect(
        outcome,
        _failsWith(RestFailureReason.unauthorized),
        reason: 'A server may refuse for other reasons than the token.',
      );
      expect(refreshes, 1, reason: 'A call refreshes once.');
      expect(
        uidAfter,
        uid,
        reason: 'The client signs nobody out: the app decides what a second '
            '401 means.',
      );
    },
    timeout: timeout,
  );
}

/// Gives what the provider tells of a change of the user the time to reach the
/// session.
Future<void> waitForNextUser() =>
    Future<void>.delayed(const Duration(milliseconds: 50));
