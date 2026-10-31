// A test that continuous integration runs in the apps with the REST role and
// the auth role, whichever modules provide them, in each mode of the auth role:
// the client of the app carries the token of the session as the mode says, and
// no token of a user who left. The server is a real one under the fake time of
// a widget test, so each request runs in real time, which is also what shows
// that a RestTestServer takes the stand-in of the binding of the tests away for
// a widget test.
//
// It knows only the roles. The start-up of the app runs first, with the mocks of
// every module of the app. Each test signs out first and uses an email address
// of its own, and each expectation gives its reason, which a provider of the
// role with a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/app_session.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import '../auth_role/auth_role.dart';
import '../core/rest/rest_test_server.dart';
import 'rest_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const timeout = Timeout(Duration(minutes: 2));

  /// Runs [body] with a server of the test as the address of the client of the
  /// app, once the app started and nobody is signed in on purpose.
  Future<void> withServer(
    WidgetTester tester,
    Future<void> Function(RestTestServer server) body,
  ) async {
    await startUp(tester);
    await inRealTime(tester, 'the requests of the test', () async {
      final server = await RestTestServer.start();
      try {
        server.answerJson('GET', '/notes', ['a']);
        appRest.use(baseAddress: server.address);
        await appSession.signOut();
        await body(server);
      } finally {
        await server.close();
      }
    });
  }

  testWidgets(
    'a request of the user of an account carries exactly the token of the '
    'session',
    (tester) async {
      Object? outcome;
      String? header;
      String? token;

      await withServer(tester, (server) async {
        await appSession.signUp(
          email: addressOf('rest-account'),
          password: password,
        );
        token = await appSession.userToken();
        outcome = await outcomeOf(appRest.get('notes'));
        header = server.requests.single.headers['authorization'];
      });

      expect(
        outcome,
        isA<RestResponse>(),
        reason: 'A request goes to the server of the test: a RestTestServer '
            'takes the stand-in of the binding of the tests away, in a widget '
            'test too.',
      );
      expect(token, isNotNull, reason: 'The user of an account has a token.');
      expect(
        header,
        'Bearer $token',
        reason: 'A request to the origin of the address has the token of the '
            'session.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a request without an account carries what the mode of the app says',
    (tester) async {
      String? header;
      String? token;
      String? uid;

      await withServer(tester, (server) async {
        await appSession.userToken();
        uid = appSession.value.uid;
        token = await appSession.userToken();
        await outcomeOf(appRest.get('notes'));
        header = server.requests.single.headers['authorization'];
      });

      expect(
        uid == null,
        authMode != AuthMode.anonymous,
        reason: 'The mode anonymous signs in an anonymous user, and the other '
            'modes nobody.',
      );
      expect(
        header,
        authMode == AuthMode.anonymous ? 'Bearer $token' : isNull,
        reason: 'In the modes required and guest, nobody has no token, so the '
            'request goes without a header. In the mode anonymous, it has the '
            'token of the anonymous user.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'after a sign-out, a request carries no token of the user who left',
    (tester) async {
      String? ofUser;
      String? header;

      await withServer(tester, (server) async {
        await appSession.signUp(
          email: addressOf('rest-sign-out'),
          password: password,
        );
        ofUser = await appSession.userToken();
        await appSession.signOut();
        await outcomeOf(appRest.get('notes'));
        header = server.requests.single.headers['authorization'];
      });

      expect(ofUser, isNotNull, reason: 'The user of an account has a token.');
      expect(
        (header == 'Bearer $ofUser', header == null),
        (false, authMode != AuthMode.anonymous),
        reason: 'After a sign-out a request goes without a token, and in the '
            'mode anonymous with the token of the next anonymous user: never '
            'as the user who left.',
      );
    },
    timeout: timeout,
  );
}
