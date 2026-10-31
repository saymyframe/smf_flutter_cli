// A test that continuous integration runs in the apps with the module that
// makes requests through the REST role, whichever module provides the role: it
// loads and adds the notes of a server with one import, gives a body of another
// shape a reason of the role, and cancels each call on its way when it is
// disposed of. A load cancels no add, and does not take the place of what an add
// showed while it was on its way.
//
// It tests a module, and starts neither the app nor a session. The tokens of the
// client are those of the test, so that a request waits for no first start of a
// session, in an app with sign-in and in one without.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_notes/fixture_notes.dart';
import 'package:{{app_name}}/core/rest/app_rest.dart';

import '../core/rest/rest_test_server.dart';

/// The token of one user.
final class _Tokens implements RestTokens {
  @override
  String? get owner => 'a user of the test';

  @override
  Future<String?> current() async => 'token-of-the-test';

  @override
  Future<String?> after(String rejected) async => null;
}

void main() {
  late RestTestServer server;
  late FixtureNotes notes;

  setUp(() async {
    server = await RestTestServer.start();
    appRest.use(baseAddress: server.address, tokens: _Tokens());
    notes = FixtureNotes();
  });

  tearDown(() async {
    notes.dispose();
    await server.close();
  });

  test('it loads the notes of the server, with the token of the user',
      () async {
    server.answerJson('GET', '/notes', [
      {'id': 1, 'text': 'the first'},
      {'id': 2, 'text': 'the second'},
    ]);

    final loading = notes.load();
    expect(notes.value, isA<FixtureNotesLoading>());
    await loading;

    final view = notes.value;
    expect(
      view,
      isA<FixtureNotesShown>(),
      reason: 'The notes reach the state of the screen through appRest.',
    );
    expect(
      [for (final note in (view as FixtureNotesShown).notes) note.text],
      ['the first', 'the second'],
    );
    expect(
      server.requests.single.headers['authorization'],
      'Bearer token-of-the-test',
      reason: 'The token goes with the request, though the module knows of no '
          'sign-in.',
    );
  });

  test('it adds a note, after those that it shows', () async {
    server
      ..answerJson('GET', '/notes', [
        {'id': 1, 'text': 'the first'},
      ])
      ..answerJson('POST', '/notes', {'id': 2, 'text': 'the second'});

    await notes.load();
    await notes.add('the second');

    final view = notes.value;
    expect(view, isA<FixtureNotesShown>());
    expect(
      [for (final note in (view as FixtureNotesShown).notes) note.text],
      ['the first', 'the second'],
    );
    expect(server.requests.last.body, '{"text":"the second"}');
  });

  test('a refusal of the server is a reason of the role', () async {
    server.answerJson('GET', '/notes', {'why': 'broken'}, status: 500);

    await notes.load();

    expect(
      notes.value,
      isA<FixtureNotesFailed>().having(
        (view) => view.reason,
        'reason',
        RestFailureReason.server,
      ),
    );
  });

  for (final (what, body) in [
    ('no JSON', 'this is no JSON'),
    ('JSON of another shape', '{"notes":[]}'),
    ('a list of items of another shape', '[{"id":"one"}]'),
  ]) {
    test('$what is the reason invalidResponse, and no TypeError', () async {
      server.answer('GET', '/notes', (request) async {
        request.response.write(body);
        await request.response.close();
      });

      await notes.load();

      expect(
        notes.value,
        isA<FixtureNotesFailed>().having(
          (view) => view.reason,
          'reason',
          RestFailureReason.invalidResponse,
        ),
      );
    });
  }

  test('without an address it fails with notConfigured, and the app goes on',
      () async {
    appRest.use(noBaseAddress: true);

    await notes.load();

    expect(
      notes.value,
      isA<FixtureNotesFailed>().having(
        (view) => view.reason,
        'reason',
        RestFailureReason.notConfigured,
      ),
    );
  });

  test(
      'dispose() closes the connection of a load that is on its way, and the '
      'state hears nothing of it', () async {
    final closed = Completer<void>();
    final heard = Completer<void>();
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <Socket>[];
    silent.listen((socket) {
      sockets.add(socket);
      socket.listen(
        (_) {
          if (!heard.isCompleted) heard.complete();
        },
        onDone: () {
          if (!closed.isCompleted) closed.complete();
        },
        onError: (Object _) {
          if (!closed.isCompleted) closed.complete();
        },
      );
    });
    addTearDown(() async {
      await silent.close();
      for (final socket in sockets) {
        socket.destroy();
      }
    });
    appRest.use(baseAddress: 'http://127.0.0.1:${silent.port}');
    final own = FixtureNotes();

    final load = own.load();
    await heard.future;
    own.dispose();

    await expectLater(
      closed.future.timeout(const Duration(seconds: 3)),
      completes,
      reason: 'The state of a screen cancels its call when it is disposed of, '
          'and the provider closes the connection.',
    );
    await load;
    expect(
      own.value,
      isA<FixtureNotesLoading>(),
      reason: 'A state that was disposed of hears nothing of its call.',
    );
  });

  group('with a server that holds its answers', () {
    late Completer<void> releaseLoad;
    late Completer<void> releaseAdd;

    /// Answers a GET with [notes] and a POST with a new note, each held until
    /// the test releases it.
    void hold(List<Map<String, Object>> notes) {
      releaseLoad = Completer();
      releaseAdd = Completer();
      server
        ..answer('GET', '/notes', (request) async {
          await releaseLoad.future;
          request.response.write(jsonEncode(notes));
          await request.response.close();
        })
        ..answer('POST', '/notes', (request) async {
          await releaseAdd.future;
          request.response.write('{"id":2,"text":"the second"}');
          await request.response.close();
        });
    }

    List<String> textsOf(FixtureNotesView view) => [
          if (view is FixtureNotesShown)
            for (final note in view.notes) note.text,
        ];

    test('dispose() after an add ends a load that is still on its way',
        () async {
      hold([
        {'id': 1, 'text': 'the first'},
      ]);
      releaseAdd.complete();
      final own = FixtureNotes();
      final load = own.load();
      await own.add('the second');

      own.dispose();
      releaseLoad.complete();

      await expectLater(
        load,
        completes,
        reason: 'A state cancels every call on its way when it is disposed of, '
            'so no answer reaches it after that.',
      );
    });

    test('dispose() ends an add that is on its way', () async {
      hold(const []);
      final own = FixtureNotes();
      final add = own.add('the second');

      own.dispose();
      releaseAdd.complete();

      await expectLater(
        add,
        completes,
        reason: 'A state cancels every call on its way when it is disposed of, '
            'so no answer reaches it after that.',
      );
    });

    test('a load that answers after an add keeps the note of the add',
        () async {
      hold([
        {'id': 1, 'text': 'the first'},
      ]);
      releaseAdd.complete();
      final load = notes.load();
      await notes.add('the second');
      expect(textsOf(notes.value), ['the second']);

      releaseLoad.complete();
      await load;

      expect(
        textsOf(notes.value),
        ['the first', 'the second'],
        reason: 'The answer of a load that was on its way may know nothing of '
            'a note that was added since, so it does not take its place.',
      );
    });

    test('a load whose answer has the note of the add shows it once', () async {
      hold([
        {'id': 2, 'text': 'the second'},
      ]);
      releaseAdd.complete();
      final load = notes.load();
      await notes.add('the second');

      releaseLoad.complete();
      await load;

      expect(textsOf(notes.value), ['the second']);
    });

    test('a load that fails after an add leaves the note of the add', () async {
      hold(const []);
      server.answer('GET', '/notes', (request) async {
        await releaseLoad.future;
        request.response.statusCode = 500;
        await request.response.close();
      });
      releaseAdd.complete();
      final load = notes.load();
      await notes.add('the second');

      releaseLoad.complete();
      await load;

      expect(
        textsOf(notes.value),
        ['the second'],
        reason: 'What the add showed is newer than the load.',
      );
    });

    test('a load does not cancel an add on its way', () async {
      hold([
        {'id': 1, 'text': 'the first'},
      ]);
      releaseLoad.complete();
      final add = notes.add('the second');
      // The POST reaches the server, which may do what it asks.
      while (server.requests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      await notes.load();
      releaseAdd.complete();
      await add;

      expect(
        textsOf(notes.value),
        ['the first', 'the second'],
        reason: 'A load cancels only the load before it: the server may have '
            'done what an add asked.',
      );
    });

    test('a load in place of a load on its way shows only its own answer',
        () async {
      hold([
        {'id': 1, 'text': 'the first'},
      ]);
      final first = notes.load();
      while (server.requests.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      server.answerJson('GET', '/notes', [
        {'id': 3, 'text': 'the third'},
      ]);

      await notes.load();
      releaseLoad.complete();
      await first;

      expect(textsOf(notes.value), ['the third']);
    });
  });
}
