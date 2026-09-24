import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/cli_engine.dart';
import 'package:smf_flutter_cli/prompts/prompt.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'helpers/mason_cache.dart';
import 'helpers/mock_logger.dart';
import 'helpers/test_modules.dart';

const _pubspecTemplate = '''
name: {{app_name}}
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
''';

void main() {
  group('runCli', () {
    late Directory sandbox;
    late Directory outputDir;
    late MockLogger logger;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('smf_cli_engine');
      await installHooklessCliBrick(
        Directory(p.join(sandbox.path, 'mason_cache')),
      );
      outputDir = Directory(p.join(sandbox.path, 'out'))..createSync();
      logger = createMockLogger();
    });

    tearDown(() async {
      resetMasonCache();
      await sandbox.delete(recursive: true);
    });

    File outputFile(String relativePath) =>
        File(p.join(outputDir.path, relativePath));

    Object? pubspecValue(List<String> path) =>
        YamlEditor(outputFile('pubspec.yaml').readAsStringSync())
            .parseAt(path)
            .value;

    Future<void> run(
      List<IModuleCodeContributor> modules, {
      StrictMode strictMode = StrictMode.lenient,
      String? initialRoute,
    }) {
      return runCli(
        CliContext(
          name: 'demo',
          packageName: 'com.acme',
          selectedModules: modules,
          outputDirectory: outputDir.path,
          logger: logger,
          strictMode: strictMode,
          moduleResolver: const ModuleDependencyResolver(),
          initialRoute: initialRoute,
        ),
      );
    }

    TestModule scaffoldModule({Map<String, String> extraFiles = const {}}) {
      return TestModule(
        'scaffold',
        pubDependency: {'get_it: ^8.0.3'},
        pubDevDependency: {'build_runner: ^2.5.4'},
        brickContributions: [
          textBrick('scaffold', {
            'pubspec.yaml': _pubspecTemplate,
            'lib/main.dart': '// {{app_name}}\n',
            ...extraFiles,
          }),
        ],
        sharedFileContributions: const [
          AppendLineContribution(
            file: 'lib/main.dart',
            line: '// patched for {{org_name}}',
          ),
        ],
      );
    }

    test('runs brick, shared-file, DSL and pubspec generation', () async {
      final router = DslTestModule(
        'router',
        onGenerate: (context) => [
          GeneratedFile(
            p.join(context.projectRootPath, 'lib', 'router.dart'),
            '// initial: ${context.initialRoute}\n',
          ),
        ],
      );

      await run([scaffoldModule(), router], initialRoute: '/home');

      // The shared contribution patched the file the brick created.
      expect(
        outputFile('lib/main.dart').readAsStringSync(),
        '// demo\n// patched for com.acme\n',
      );
      expect(
        outputFile('lib/router.dart').readAsStringSync(),
        '// initial: /home\n',
      );
      expect(pubspecValue(['name']), 'demo');
      expect(pubspecValue(['dependencies', 'get_it']), '^8.0.3');
      expect(pubspecValue(['dev_dependencies', 'build_runner']), '^2.5.4');
    });

    test('exposes the CLI context to templates as core vars', () async {
      await run([
        scaffoldModule(
          extraFiles: {
            'vars.txt': '{{app_name}}|{{org_name}}|{{{modules}}}|'
                '{{strict_mode}}|{{{working_dir}}}',
          },
        ),
        TestModule('extra'),
      ]);

      expect(
        outputFile('vars.txt').readAsStringSync(),
        "demo|com.acme|['scaffold','extra']|false|${outputDir.path}",
      );
    });

    test('passes strict mode to the templates', () async {
      await run(
        [
          scaffoldModule(extraFiles: {'strict.txt': '{{strict_mode}}'}),
        ],
        strictMode: StrictMode.strict,
      );

      expect(outputFile('strict.txt').readAsStringSync(), 'true');
    });

    test('leaves out dependencies of modules dropped during brick generation',
        () async {
      // 'obstructed' is a file, so the broken brick cannot write below it.
      final broken = TestModule(
        'broken',
        pubDependency: {'firebase_core: ^4.1.0'},
        brickContributions: [
          textBrick('broken', {'obstructed/file.txt': ''}),
        ],
      );

      await run([
        scaffoldModule(extraFiles: {'obstructed': ''}),
        broken,
      ]);

      final dependencies = pubspecValue(['dependencies'])! as Map;
      expect(dependencies.containsKey('get_it'), isTrue);
      expect(dependencies.containsKey('firebase_core'), isFalse);
    });

    test('fails when no module provides a pubspec.yaml', () async {
      await expectLater(
        run([TestModule('empty')]),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
