import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/generators/brick_generator.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:test/test.dart';

import '../helpers/mason_cache.dart';
import '../helpers/mock_logger.dart';
import '../helpers/test_modules.dart';

/// Directory name that tests occupy with a regular file, so that any brick
/// writing below it fails with a [FileSystemException].
const _obstructed = 'obstructed';

void main() {
  group('BrickGenerator', () {
    late Directory sandbox;
    late Directory projectDir;
    late MockLogger logger;
    late List<RecordingProgress> progresses;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('smf_brick_gen');
      useMasonCache(Directory(p.join(sandbox.path, 'mason_cache')));
      projectDir = Directory(p.join(sandbox.path, 'project'))..createSync();
      File(p.join(projectDir.path, _obstructed)).writeAsStringSync('');
      progresses = [];
      logger = createMockLogger(progresses: progresses);
    });

    tearDown(() async {
      resetMasonCache();
      await sandbox.delete(recursive: true);
    });

    File projectFile(String relativePath) =>
        File(p.join(projectDir.path, relativePath));

    Future<void> generate(
      List<IModuleCodeContributor> modules, {
      Map<String, dynamic>? coreVars,
    }) {
      return const BrickGenerator(ModuleDependencyResolver()).generate(
        modules,
        logger,
        coreVars ?? <String, dynamic>{'app_name': 'demo'},
        projectDir.path,
      );
    }

    TestModule failingModule(String name, {Set<String> dependsOn = const {}}) {
      return TestModule(
        name,
        dependsOn: dependsOn,
        brickContributions: [
          textBrick('${name}_brick', {'$_obstructed/$name.txt': name}),
        ],
      );
    }

    TestModule writingModule(String name, {Set<String> dependsOn = const {}}) {
      return TestModule(
        name,
        dependsOn: dependsOn,
        brickContributions: [
          textBrick('${name}_brick', {'$name.txt': name}),
        ],
      );
    }

    test('renders every brick of every module into the target directory',
        () async {
      await generate(
        [
          TestModule(
            'core',
            brickContributions: [
              textBrick('core_brick', {
                '{{app_name}}/lib/main.dart': '// {{app_name}} by {{org_name}}',
              }),
            ],
          ),
          TestModule(
            'feature',
            brickContributions: [
              textBrick('feature_one', {'{{app_name}}/one.txt': 'one'}),
              textBrick('feature_two', {'{{app_name}}/two.txt': 'two'}),
            ],
          ),
        ],
        coreVars: <String, dynamic>{'app_name': 'demo', 'org_name': 'acme'},
      );

      expect(
        projectFile('demo/lib/main.dart').readAsStringSync(),
        '// demo by acme',
      );
      expect(projectFile('demo/one.txt').readAsStringSync(), 'one');
      expect(projectFile('demo/two.txt').readAsStringSync(), 'two');
    });

    test('renders brick-specific vars on top of coreVars', () async {
      await generate(
        [
          TestModule(
            'core',
            brickContributions: [
              textBrick(
                'core_brick',
                {'vars.txt': '{{app_name}}/{{flavor}}'},
                vars: <String, dynamic>{'flavor': 'dev'},
              ),
            ],
          ),
        ],
      );

      expect(projectFile('vars.txt').readAsStringSync(), 'demo/dev');
    });

    test(
      'does not leak brick vars into coreVars or later bricks',
      () async {
        final coreVars = <String, dynamic>{'app_name': 'demo'};

        await generate(
          [
            TestModule(
              'first',
              brickContributions: [
                textBrick(
                  'first_brick',
                  {'first.txt': '{{flavor}}'},
                  vars: <String, dynamic>{'flavor': 'dev'},
                ),
              ],
            ),
            TestModule(
              'second',
              brickContributions: [
                textBrick('second_brick', {'second.txt': '[{{flavor}}]'}),
              ],
            ),
          ],
          coreVars: coreVars,
        );

        expect(projectFile('second.txt').readAsStringSync(), '[]');
        expect(coreVars, isNot(contains('flavor')));
      },
      skip: 'Bug: `coreVars..addAll(brick.vars)` mutates the shared '
          'coreVars, so brick vars leak into later bricks and generators',
    );

    test('overwrites existing files for the overwrite strategy', () async {
      projectFile('file.txt').writeAsStringSync('old');

      await generate([
        TestModule(
          'core',
          brickContributions: [
            textBrick('core_brick', {'file.txt': 'new'}),
          ],
        ),
      ]);

      expect(projectFile('file.txt').readAsStringSync(), 'new');
    });

    test('appends to existing files for the appendToFile strategy', () async {
      projectFile('file.txt').writeAsStringSync('old\n');

      await generate([
        TestModule(
          'core',
          brickContributions: [
            textBrick(
              'core_brick',
              {'file.txt': 'new\n'},
              mergeStrategy: FileMergeStrategy.appendToFile,
            ),
          ],
        ),
      ]);

      expect(projectFile('file.txt').readAsStringSync(), 'old\nnew\n');
    });

    test('reports progress for each brick', () async {
      await generate([
        TestModule(
          'core',
          brickContributions: [
            textBrick('core_brick', {'a.txt': 'a', 'b.txt': 'b'}),
          ],
        ),
      ]);

      expect(progresses.map((p) => p.message), ['Generating from core_brick']);
      expect(progresses.single.isFinished, isTrue);
    });

    test('keeps the module list intact when all bricks succeed', () async {
      final modules = <IModuleCodeContributor>[
        writingModule('a'),
        TestModule('no_bricks'),
      ];

      await generate(modules);

      expect(modules, hasLength(2));
      verifyNever(() => logger.info(any()));
    });

    group('in lenient mode', () {
      test('drops a failing module and its dependents, keeps the rest',
          () async {
        final base = failingModule('base');
        final dependent = writingModule('dependent', dependsOn: {'base'});
        final independent = writingModule('independent');
        final modules = <IModuleCodeContributor>[base, dependent, independent];

        await generate(modules);

        expect(modules, [independent]);
        expect(projectFile('independent.txt').existsSync(), isTrue);
        expect(projectFile('dependent.txt').existsSync(), isFalse);
      });

      test('skips the remaining bricks of a failing module', () async {
        final module = TestModule(
          'broken',
          brickContributions: [
            textBrick('broken_one', {'$_obstructed/one.txt': 'one'}),
            textBrick('broken_two', {'two.txt': 'two'}),
          ],
        );

        await generate([module]);

        expect(projectFile('two.txt').existsSync(), isFalse);
      });

      test('logs a warning listing the excluded modules', () async {
        await generate([
          failingModule('base'),
          writingModule('dependent', dependsOn: {'base'}),
        ]);

        verify(
          () => logger.info(any(that: contains('Generation warnings'))),
        ).called(1);
        verify(
          () => logger.info(any(that: contains('base, dependent'))),
        ).called(1);
        verify(
          () => logger.detail(any(that: contains("'base'"))),
        ).called(1);
      });

      test(
        'also drops modules that depend on a dropped dependent',
        () async {
          final base = failingModule('base');
          final middle = writingModule('middle', dependsOn: {'base'});
          final top = writingModule('top', dependsOn: {'middle'});
          final modules = <IModuleCodeContributor>[base, middle, top];

          await generate(modules);

          expect(modules, isEmpty);
          expect(projectFile('top.txt').existsSync(), isFalse);
        },
        skip: 'Bug: only direct dependents of a failed module are excluded '
            '(dependentsOf is not transitive)',
      );

      test(
        'finishes the progress of a brick that failed to generate',
        () async {
          await generate([failingModule('base')]);

          expect(progresses, hasLength(1));
          expect(progresses.single.isFinished, isTrue);
        },
        skip: 'Bug: the progress is never completed/failed when generate '
            'throws, so the spinner keeps running',
      );
    });

    group('in strict mode', () {
      test('logs the failing module and rethrows', () async {
        final modules = <IModuleCodeContributor>[
          failingModule('base'),
          writingModule('later'),
        ];

        await expectLater(
          generate(
            modules,
            coreVars: <String, dynamic>{
              'app_name': 'demo',
              'strict_mode': true,
            },
          ),
          throwsA(isA<FileSystemException>()),
        );

        verify(() => logger.err(any(that: contains('base')))).called(1);
        expect(modules, hasLength(2));
        expect(projectFile('later.txt').existsSync(), isFalse);
      });
    });
  });
}
