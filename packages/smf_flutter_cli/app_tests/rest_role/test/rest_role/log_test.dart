// A test that continuous integration runs in the apps with the REST role,
// whichever module provides it: a debug build prints one line for each attempt,
// with the origin and the path alone, and nothing that the client or the
// provider prints, or says in a failure, has a token, a query or a body.
//
// It knows only the role. It hears what debugPrint prints and what goes through
// print in the zone of the call, which is the zone of what a provider prints in
// it too.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import 'rest_role.dart';

void main() {
  late RestTestServer server;

  setUp(() async {
    server = await RestTestServer.start();
  });

  tearDown(() => server.close());

  test(
      'a call with a refresh prints a line for each attempt, with no token, '
      'no query and no body', () async {
    final tokens = ScriptedTokens('secret-first', refreshed: ['secret-second']);
    server.answer('POST', '$apiPath/notes', (request) async {
      final isNew =
          request.headers.value('authorization') == 'Bearer secret-second';
      request.response.statusCode = isNew ? 500 : 401;
      await request.response.close();
    });
    final printed = <String>[];
    final debugPrintBefore = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    addTearDown(() => debugPrint = debugPrintBefore);

    final outcome = await runZoned(
      () => outcomeOf(
        clientOf(server, tokens: tokens).post(
          'notes',
          json: {'text': 'secret-body'},
          query: {'key': 'secret-query'},
          headers: {'X-Of-The-Call': 'secret-header'},
        ),
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printed.add(line),
      ),
    );

    expect(
      printed.where((line) => line.startsWith('REST POST ')),
      [
        startsWith('REST POST ${server.address}$apiPath/notes 401 ('),
        startsWith('REST POST ${server.address}$apiPath/notes 500 ('),
      ],
      reason: 'A debug build prints one line for each attempt.',
    );
    expect(
      [...printed, '$outcome', (outcome as RestFailure).developerHint ?? ''],
      everyElement(isNot(contains('secret-'))),
      reason: 'Nothing that a client or a provider prints, or says in a '
          'failure, has a header, a query or a body.',
    );
  });
}
