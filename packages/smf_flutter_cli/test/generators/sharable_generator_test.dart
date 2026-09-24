import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/generators/sharable_generator.dart';
import 'package:test/test.dart';

import '../helpers/mock_logger.dart';
import '../helpers/test_modules.dart';

void main() {
  group('SharableGenerator', () {
    late Directory projectDir;
    late MockLogger logger;

    setUp(() async {
      projectDir = await Directory.systemTemp.createTemp('smf_sharable_gen');
      Directory(p.join(projectDir.path, 'lib')).createSync();
      logger = createMockLogger();
    });

    tearDown(() async {
      await projectDir.delete(recursive: true);
    });

    File projectFile(String relativePath) =>
        File(p.join(projectDir.path, relativePath));

    test('applies contributions of all modules in module order', () async {
      projectFile('lib/main.dart').writeAsStringSync('// main\n');

      await const SharableGenerator().generate(
        [
          TestModule(
            'a',
            sharedFileContributions: const [
              AppendLineContribution(file: 'lib/main.dart', line: '// a'),
            ],
          ),
          TestModule(
            'b',
            sharedFileContributions: const [
              AppendLineContribution(file: 'lib/main.dart', line: '// b1'),
              AppendLineContribution(file: 'lib/main.dart', line: '// b2'),
            ],
          ),
        ],
        logger,
        <String, dynamic>{},
        projectDir.path,
      );

      expect(
        projectFile('lib/main.dart').readAsStringSync(),
        '// main\n// a\n// b1\n// b2\n',
      );
    });

    test('patches files relative to the target directory', () async {
      projectFile('lib/main.dart').writeAsStringSync('');
      projectFile('pubspec.yaml').writeAsStringSync('name: demo\n');

      await const SharableGenerator().generate(
        [
          TestModule(
            'a',
            sharedFileContributions: const [
              AppendLineContribution(file: 'lib/main.dart', line: '// main'),
              AppendLineContribution(file: 'pubspec.yaml', line: '# pubspec'),
            ],
          ),
        ],
        logger,
        <String, dynamic>{},
        projectDir.path,
      );

      expect(projectFile('lib/main.dart').readAsStringSync(), '// main\n');
      expect(
        projectFile('pubspec.yaml').readAsStringSync(),
        'name: demo\n# pubspec\n',
      );
    });

    test('renders mustache variables from coreVars', () async {
      projectFile('lib/main.dart').writeAsStringSync('');

      await const SharableGenerator().generate(
        [
          TestModule(
            'a',
            sharedFileContributions: const [
              AppendLineContribution(
                file: 'lib/main.dart',
                line: '// {{app_name}} by {{org_name}}',
              ),
            ],
          ),
        ],
        logger,
        <String, dynamic>{'app_name': 'demo', 'org_name': 'com.acme'},
        projectDir.path,
      );

      expect(
        projectFile('lib/main.dart').readAsStringSync(),
        '// demo by com.acme\n',
      );
    });

    test('leaves the project untouched without contributions', () async {
      projectFile('lib/main.dart').writeAsStringSync('// main\n');

      await const SharableGenerator().generate(
        [TestModule('a')],
        logger,
        <String, dynamic>{},
        projectDir.path,
      );

      expect(projectFile('lib/main.dart').readAsStringSync(), '// main\n');
    });
  });
}
