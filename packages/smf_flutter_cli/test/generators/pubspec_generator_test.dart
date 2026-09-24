import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/generators/pubspec_generator.dart';
import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

import '../helpers/mock_logger.dart';
import '../helpers/test_modules.dart';

const _pubspec = '''
name: demo
# Keep this comment.
environment:
  sdk: ^3.6.0

dependencies:
  flutter:
    sdk: flutter
  get_it: ^7.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
''';

void main() {
  group('PubspecGenerator', () {
    late Directory projectDir;
    late File pubspec;
    late MockLogger logger;

    setUp(() async {
      projectDir = await Directory.systemTemp.createTemp('smf_pubspec_gen');
      pubspec = File(p.join(projectDir.path, 'pubspec.yaml'))
        ..writeAsStringSync(_pubspec);
      logger = MockLogger();
    });

    tearDown(() async {
      await projectDir.delete(recursive: true);
    });

    Future<void> generate(List<TestModule> modules) {
      return const PubspecGenerator().generate(
        modules,
        logger,
        <String, dynamic>{},
        projectDir.path,
      );
    }

    Object? valueAt(List<String> path) =>
        YamlEditor(pubspec.readAsStringSync()).parseAt(path).value;

    test('adds dependencies of every module', () async {
      await generate([
        TestModule('a', pubDependency: {'event_bus: ^2.0.1'}),
        TestModule(
          'b',
          pubDependency: {'equatable: ^2.0.7', 'go_router: ^16.0.0'},
        ),
      ]);

      expect(valueAt(['dependencies', 'event_bus']), '^2.0.1');
      expect(valueAt(['dependencies', 'equatable']), '^2.0.7');
      expect(valueAt(['dependencies', 'go_router']), '^16.0.0');
    });

    test('adds dev dependencies under dev_dependencies', () async {
      await generate([
        TestModule(
          'a',
          pubDependency: {'freezed_annotation: ^3.1.0'},
          pubDevDependency: {'build_runner: ^2.5.4'},
        ),
      ]);

      expect(valueAt(['dev_dependencies', 'build_runner']), '^2.5.4');
      expect(
        (valueAt(['dependencies'])! as Map).containsKey('build_runner'),
        isFalse,
      );
    });

    test('overrides the version of an existing dependency', () async {
      await generate([
        TestModule('a', pubDependency: {'get_it: ^8.0.3'}),
      ]);

      expect(valueAt(['dependencies', 'get_it']), '^8.0.3');
    });

    test('trims whitespace around names and versions', () async {
      await generate([
        TestModule('a', pubDependency: {'  event_bus  :   ^2.0.1  '}),
      ]);

      expect(valueAt(['dependencies', 'event_bus']), '^2.0.1');
    });

    test('keeps the rest of the pubspec intact', () async {
      await generate([
        TestModule('a', pubDependency: {'event_bus: ^2.0.1'}),
      ]);

      final content = pubspec.readAsStringSync();
      expect(content, contains('# Keep this comment.'));
      expect(valueAt(['name']), 'demo');
      expect(valueAt(['dependencies', 'flutter', 'sdk']), 'flutter');
      expect(valueAt(['dev_dependencies', 'flutter_test', 'sdk']), 'flutter');
    });

    test('leaves the file unchanged when modules add nothing', () async {
      await generate([TestModule('a'), TestModule('b')]);

      expect(pubspec.readAsStringSync(), _pubspec);
    });

    test('fails when the project has no pubspec.yaml', () async {
      pubspec.deleteSync();

      await expectLater(
        generate([
          TestModule('a', pubDependency: {'event_bus: ^2.0.1'}),
        ]),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
