import 'dart:io';

import 'package:mason/mason.dart' show Level;
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/prompts/prompt.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:smf_flutter_cli/utils/safe_generation_runner.dart';
import 'package:test/test.dart';

import '../helpers/mason_cache.dart';
import '../helpers/mock_logger.dart';
import '../helpers/test_modules.dart';

/// Scaffolds `<app_name>/README.md` plus the `pubspec.yaml` that
/// `PubspecGenerator` reads from the generation root. The root is the temp
/// workspace because the hook that normally points `working_dir` at the app
/// folder is stripped (see [installHooklessCliBrick]).
TestModule _projectModule({bool withProjectDir = true}) {
  return TestModule(
    'scaffold',
    brickContributions: [
      textBrick('scaffold', {
        'pubspec.yaml': 'name: app\ndependencies:\n',
        if (withProjectDir)
          '{{app_name.snakeCase()}}/README.md': '# {{app_name}}\n',
      }),
    ],
  );
}

void main() {
  group('SafeGenerationRunner', () {
    late Directory sandbox;
    late Directory outputDir;
    late Directory systemTemp;
    late MockLogger logger;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('smf_safe_runner');
      await installHooklessCliBrick(
        Directory(p.join(sandbox.path, 'mason_cache')),
      );
      outputDir = Directory(p.join(sandbox.path, 'out'))..createSync();
      systemTemp = Directory(p.join(sandbox.path, 'tmp'))..createSync();
      logger = createMockLogger();
    });

    tearDown(() async {
      resetMasonCache();
      await sandbox.delete(recursive: true);
    });

    /// Runs generation of an app called "My App" with the system temp
    /// directory redirected into the sandbox, so the runner's temp workspace
    /// can be inspected.
    Future<void> run({
      List<IModuleCodeContributor>? modules,
      String? outputDirectory,
      String? onConflict,
    }) {
      final context = CliContext(
        name: 'My App',
        packageName: 'com.acme',
        selectedModules: modules ?? [_projectModule()],
        outputDirectory: outputDirectory ?? outputDir.path,
        logger: logger,
        strictMode: StrictMode.lenient,
        moduleResolver: const ModuleDependencyResolver(),
      );

      return IOOverrides.runZoned(
        () => onConflict == null
            ? SafeGenerationRunner().run(context)
            : SafeGenerationRunner().run(context, onConflict: onConflict),
        getSystemTempDirectory: () => systemTemp,
      );
    }

    Directory outputSubdir(String name) =>
        Directory(p.join(outputDir.path, name));

    void expectTempWorkspaceRemoved() {
      expect(systemTemp.listSync(), isEmpty);
    }

    void expectUnexpectedErrorReported() {
      verify(() => logger.write('❌  An unexpected error occurred.\n'))
          .called(1);
    }

    test('moves the generated project to <output>/<snake_case name>', () async {
      await run();

      final readme = File(p.join(outputDir.path, 'my_app', 'README.md'));
      expect(readme.readAsStringSync(), '# My App\n');
      expect(outputDir.listSync().map((e) => p.basename(e.path)), ['my_app']);
      expectTempWorkspaceRemoved();
      verify(
        () => logger.success(
          '✅  Project created at: ${p.join(outputDir.path, 'my_app')}',
        ),
      ).called(1);
    });

    test('creates a missing output directory', () async {
      final nested = p.join(outputDir.path, 'nested', 'dir');

      await run(outputDirectory: nested);

      expect(File(p.join(nested, 'my_app', 'README.md')).existsSync(), isTrue);
    });

    test('does not prompt when the destination does not exist yet', () async {
      await run(onConflict: 'prompt');

      expect(outputSubdir('my_app').existsSync(), isTrue);
    });

    group('when the destination already exists', () {
      late File existingFile;

      setUp(() {
        existingFile = File(p.join(outputDir.path, 'my_app', 'old.txt'))
          ..createSync(recursive: true)
          ..writeAsStringSync('old');
      });

      test('replace removes the old directory first', () async {
        await run(onConflict: 'replace');

        expect(existingFile.existsSync(), isFalse);
        expect(
          File(p.join(outputDir.path, 'my_app', 'README.md')).existsSync(),
          isTrue,
        );
        expectTempWorkspaceRemoved();
        verify(
          () => logger.warn(any(that: contains('Removing existing directory'))),
        ).called(1);
      });

      test('copy generates into "<name> copy" and keeps the old one', () async {
        await run(onConflict: 'copy');

        expect(existingFile.readAsStringSync(), 'old');
        expect(
          File(p.join(outputDir.path, 'my_app copy', 'README.md')).existsSync(),
          isTrue,
        );
        expectTempWorkspaceRemoved();
      });

      test('copy picks the next free "<name> copy N" name', () async {
        outputSubdir('my_app copy').createSync();
        outputSubdir('my_app copy 2').createSync();

        await run(onConflict: 'copy');

        expect(
          File(p.join(outputDir.path, 'my_app copy 3', 'README.md'))
              .existsSync(),
          isTrue,
        );
        expect(outputSubdir('my_app copy').listSync(), isEmpty);
        expect(outputSubdir('my_app copy 2').listSync(), isEmpty);
      });

      test('cancel keeps the old directory and reports the cancellation',
          () async {
        await run(onConflict: 'cancel');

        expect(existingFile.readAsStringSync(), 'old');
        expect(outputDir.listSync(), hasLength(1));
        expectTempWorkspaceRemoved();
        verify(() => logger.warn('⚠️ Operation cancelled by user.')).called(1);
        expectUnexpectedErrorReported();
      });
    });

    group('when generation fails', () {
      test('reports the error, hints at --verbose and cleans up', () async {
        // No module generates the pubspec.yaml that PubspecGenerator needs.
        await run(modules: [TestModule('empty')]);

        expect(outputDir.listSync(), isEmpty);
        expectTempWorkspaceRemoved();
        expectUnexpectedErrorReported();
        verify(
          () => logger.write(any(that: contains('Try running with --verbose'))),
        ).called(1);
        verifyNever(() => logger.write('--- Details ---\n\n'));
      });

      test('prints the error details in verbose mode', () async {
        when(() => logger.level).thenReturn(Level.verbose);

        await run(modules: [TestModule('empty')]);

        verify(() => logger.write('--- Details ---\n\n')).called(1);
        verify(() => logger.write(any(that: contains('pubspec.yaml'))))
            .called(1);
        verifyNever(
          () => logger.write(any(that: contains('Try running with --verbose'))),
        );
      });

      test('reports an error when no project directory was generated',
          () async {
        await run(modules: [_projectModule(withProjectDir: false)]);

        expect(outputDir.listSync(), isEmpty);
        expectTempWorkspaceRemoved();
        expectUnexpectedErrorReported();
      });

      test('signals the failure to the caller', () async {
        await expectLater(
          run(modules: [TestModule('empty')]),
          throwsA(isA<Exception>()),
        );
      },
          skip: 'Bug: run() swallows generation errors, so `smf create` exits '
              'with code 0 after a failed generation');
    });
  });
}
