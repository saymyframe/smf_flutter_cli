@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_dio/smf_dio.dart';
import 'package:smf_dio/src/agents.dart';
import 'package:smf_dio/src/readme.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// The modules of the tests: the app entry, this module, the provider of the
/// env role, which the REST role requires, and the provider of the auth role,
/// which the REST role uses, with the module that it depends on.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  DartDefineModule(),
  DioModule(),
  FirebaseCoreModule(),
  FirebaseAuthModule(),
];

/// The owner of the transport.
const _dio = ModuleOrigin(DioModule.id);

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _resultOf(List<ModuleId> modules) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// Sends exchanges through the transport of the app, over a server of its own
/// on this machine, and sends back what the server got and what came back.
///
/// It imports only the file of the module and the file of the interface of the
/// role, which need nothing but Dart and dio.
const _script = r'''
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:contract_app/core/rest/dio_rest_transport.dart';
import 'package:contract_app/core/rest/rest_transport.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  final got = <Map<String, Object?>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final body = await request.fold<List<int>>([], (all, part) => all..addAll(part));
    got.add({
      'method': request.method,
      'uri': '${request.uri}',
      'type': request.headers.contentType?.mimeType,
      'length': request.headers.contentLength,
      'body': body,
      'port': request.connectionInfo?.remotePort,
    });
    if (request.uri.path == '/compressed') {
      request.response.headers.set('content-encoding', 'gzip');
      request.response.add(gzip.encode(utf8.encode('decoded')));
    } else if (request.uri.path == '/redirect') {
      request.response.statusCode = 302;
      request.response.headers.set('Location', '/elsewhere');
    }
    await request.response.close();
  });
  final transport = createDioRestTransport();
  final address = 'http://127.0.0.1:${server.port}';
  Future<RestReply> send(String method, String path, {List<int>? body}) =>
      transport.send(
        RestExchange(
          method: method,
          uri: Uri.parse('$address$path'),
          headers: {
            if (body != null) 'content-length': '${body.length}',
          },
          body: body,
          stop: Completer<void>().future,
        ),
      );

  final bytes = await send('POST', '/bytes?a=b%20c', body: const [0, 200, 255]);
  final compressed = await send('GET', '/compressed');
  final redirect = await send('GET', '/redirect');

  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final closedPort = socket.port;
  await socket.close();
  Object? failure;
  try {
    await transport.send(
      RestExchange(
        method: 'GET',
        uri: Uri.parse('http://127.0.0.1:$closedPort/?key=secret'),
        headers: const {},
        stop: Completer<void>().future,
      ),
    );
  } on Object catch (error) {
    failure = error;
  }
  await server.close(force: true);

  port.send({
    'got': got,
    'status of bytes': bytes.status,
    'compressed': utf8.decode(compressed.bytes),
    'redirect': [redirect.status, redirect.headers['location']],
    'failure': '$failure',
  });
}
''';

void main() {
  const module = DioModule();

  group('DioModule', () {
    test('is infrastructure that provides the REST role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('dio'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {restRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, dio, its implementation of the transport, '
        'created without waiting, the section of its README and its note for '
        'coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(5));
      expect((contributions[0] as BrickContribution).bundle.name, 'dio');
      final dependency = contributions[1] as PubspecDependency;
      expect(dependency.package, 'dio');
      expect(dependency.constraint, '^5.11.1');
      expect(dependency.dev, isFalse);
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, restRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'DioRestTransport');
      expect(implementation.create!.name, 'createDioRestTransport');
      expect(implementation.create!.deps, isEmpty);
      final readme = contributions[3] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, readmeHeading);
      expect(readme.entryValue, readmeSection);
      final note = contributions[4] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, restRole.description);
      expect(note.entryValue, AgentNote(agentNote));
    });

    test('passes the contract harness in every app it can be part of',
        () async {
      final harness = ContractHarness(ModuleRegistry(_modules));

      final results = await harness.checkAll();

      expect(
        [
          for (final result in results)
            for (final error in result.errors) '${result.contractCase}: $error',
        ],
        isEmpty,
      );
      expect(await harness.uncheckedProviders(), isEmpty);
      expect(
        {
          for (final result in results)
            if (result.contractCase.requested.contains(DioModule.id))
              result.contractCase.name,
        },
        containsAll(<String>['dio', 'dio with auth']),
      );
    });
  });

  group('the app', () {
    late ContractResult result;
    late RenderedApp app;
    late DartApp dart;

    setUpAll(() async {
      result = await _resultOf(const [FlutterCoreModule.id, DioModule.id]);
      app = result.app!;
      dart = await DartApp.write(app);
    });

    tearDownAll(() => dart.delete());

    test('has the transport, whose owner is the module', () {
      expect(app.files[transportFile]!.owner, _dio);
      expect(
        app.files[RestRole.clientFile]!.text,
        contains('createDioRestTransport()'),
      );
    });

    test('depends on dio, which the app needs at run time', () {
      final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;

      expect((pubspec['dependencies'] as YamlMap)['dio'], '^5.11.1');
      expect(pubspec['dev_dependencies'] as YamlMap, isNot(contains('dio')));
    });

    test('imports the package in that file alone', () {
      expect(
        [
          for (final file in app.files.values)
            if (file.path.endsWith('.dart') &&
                file.text.contains('package:dio/'))
              file.path,
        ],
        [transportFile],
      );
    });

    test('has a transport that type-checks against the real dio', () async {
      expect(await dart.analysisProblems({_dio}), isEmpty);
    });

    test(
        'sends a body byte by byte and the address as it is, takes a redirect '
        'as a reply and a compressed body decoded, keeps its connection, and '
        'tells of a failed connection without its query', () async {
      final sent = (await dart.run(_script))! as Map<Object?, Object?>;

      final got = sent['got']! as List<Object?>;
      expect(got, hasLength(3));
      final bytes = got[0]! as Map<Object?, Object?>;
      expect(bytes['method'], 'POST');
      expect(bytes['uri'], '/bytes?a=b%20c');
      expect(bytes['body'], [0, 200, 255]);
      expect(bytes['length'], 3);
      expect(bytes['type'], isNull);
      expect(sent['status of bytes'], 200);
      expect(sent['compressed'], 'decoded');
      expect(sent['redirect'], [302, '/elsewhere']);
      expect(
        {
          for (final request in got)
            (request! as Map<Object?, Object?>)['port'],
        },
        hasLength(1),
        reason: 'One Dio keeps its connection between two exchanges.',
      );
      expect(sent['failure'], startsWith('RestConnectionFailed'));
      expect(sent['failure'], isNot(contains('secret')));
    });

    test('has a README that leads to the page of the module', () {
      expect(
        File('README.md').readAsStringSync(),
        contains('(https://doc.saymyframe.com/modules/dio)'),
      );
    });

    test('names in the section of its README what the app has', () {
      final readme = app.files[AppEntryRole.readmeFile]!.text;

      expect(readme, contains('## $readmeHeading'));
      expect(readme, contains('## ${RestRole.readmeHeading}'));
      expect(readme, contains(transportFile));
    });

    test('gives in its note for coding agents the names of the code', () {
      final transport = DartFileIndexer.index(
        transportFile,
        app.files[transportFile]!.text,
      );

      expect(agentNote, startsWith('With `dio`:'));
      for (final name in ['DioRestTransport', 'createDio']) {
        expect(agentNote, contains('`$name'));
        expect(transport.declaration(name), isNotNull, reason: name);
      }
      expect(agentNote, contains('`$transportFile`'));
    });
  });
}
