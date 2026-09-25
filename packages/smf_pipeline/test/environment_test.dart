import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('findExecutable', () {
    test('finds an executable on the PATH', () async {
      final host = FakeHost();
      final environment = host.environment();

      expect(await environment.findExecutable('flutter'), '/sdk/bin/flutter');
      expect(await environment.findExecutable('firebase'), isNull);
    });

    test('searches the installed directories before the PATH', () async {
      final host = FakeHost();
      host.fileSystem.file('/opt/tools/flutter').createSync(recursive: true);
      final environment = host.environment()..addBinDirs(['/opt/tools']);

      expect(await environment.findExecutable('flutter'), '/opt/tools/flutter');
      expect(environment.binDirs, ['/opt/tools']);
      expect(environment.path, '/opt/tools:/sdk/bin');
    });

    test('adds each installed directory once', () {
      final environment = FakeHost().environment()
        ..addBinDirs(['/a', '/b'])
        ..addBinDirs(['/a']);

      expect(environment.binDirs, ['/a', '/b']);
    });

    test('checks absolute and relative paths directly', () async {
      final host = FakeHost();
      host.fileSystem.file('/work/tool/run').createSync(recursive: true);
      final environment = host.environment();

      expect(
        await environment.findExecutable('/sdk/bin/dart'),
        '/sdk/bin/dart',
      );
      expect(await environment.findExecutable('tool/run'), '/work/tool/run');
      expect(await environment.findExecutable('/sdk/bin/nothing'), isNull);
    });

    test('skips empty entries and resolves relative ones', () async {
      final host = FakeHost(environment: {'PATH': ':local::'});
      host.fileSystem.file('/work/local/tool').createSync(recursive: true);

      expect(
        await host.environment().findExecutable('tool'),
        '/work/local/tool',
      );
    });

    test('works without a PATH', () async {
      final environment = FakeHost(environment: {}).environment();

      expect(await environment.findExecutable('flutter'), isNull);
      expect(environment.path, isEmpty);
    });

    test('on Windows tries the extensions of PATHEXT', () async {
      final host = FakeHost(
        operatingSystem: HostOperatingSystem.windows,
        environment: {'Path': r'C:\sdk\bin', 'PATHEXT': '.EXE;.BAT'},
      );
      final environment = host.environment();

      expect(
        await environment.findExecutable('flutter'),
        r'C:\sdk\bin\flutter.bat',
      );
      expect(
        await environment.findExecutable('dart.bat'),
        r'C:\sdk\bin\dart.bat',
      );
      expect(await environment.findExecutable('dart.exe'), isNull);
      environment.addBinDirs([r'C:\tools']);
      expect(environment.path, r'C:\tools;C:\sdk\bin');
    });

    test('on Windows drops quotes and takes / as a separator', () async {
      final host = FakeHost(
        operatingSystem: HostOperatingSystem.windows,
        environment: {'PATH': r'"C:\Program Files\node";C:\sdk\bin'},
      );
      host.fileSystem
          .file(r'C:\Program Files\node\node.exe')
          .createSync(recursive: true);
      host.fileSystem
          .file(r'C:\work\tools\run.bat')
          .createSync(recursive: true);
      final environment = host.environment();

      expect(
        await environment.findExecutable('node'),
        r'C:\Program Files\node\node.exe',
      );
      expect(
        await environment.findExecutable('tools/run'),
        r'C:\work\tools\run.bat',
      );
    });

    test('on Windows defaults PATHEXT', () async {
      final host = FakeHost(
        operatingSystem: HostOperatingSystem.windows,
        environment: {'PATH': r'C:\sdk\bin'},
      );

      expect(
        await host.environment().findExecutable('dart'),
        r'C:\sdk\bin\dart.bat',
      );
    });
  });

  group('with the SDK found', () {
    test('flutter and dart are the SDK', () async {
      final environment = FakeHost().environment()
        ..sdk = const FlutterSdk(flutter: '/f/flutter', dart: '/f/dart');

      expect(await environment.findExecutable('flutter'), '/f/flutter');
      expect(await environment.findExecutable('dart'), '/f/dart');
      expect(
        await environment.findExecutable('/sdk/bin/dart'),
        '/sdk/bin/dart',
      );
      expect(environment.path, '/f:/sdk/bin');
    });

    test('commands get the PATH unless they set one', () async {
      final runner = ScriptedProcessRunner({
        'firebase': const SmfProcessResult(exitCode: 0),
      });
      final seen = <Map<String, String>>[];
      final host = FakeHost(processRunner: _Recording(runner, seen));
      final environment = host.environment()..addBinDirs(['/npm/bin']);

      await environment.processRunner.run('firebase', ['login:list']);
      await environment.processRunner
          .run('firebase', [], environment: const {'PATH': '/mine'});
      await environment.processRunner.runInteractive('firebase', ['login']);

      expect(seen, [
        {'PATH': '/npm/bin:/sdk/bin'},
        {'PATH': '/mine'},
        {'PATH': '/npm/bin:/sdk/bin'},
      ]);
    });

    test('on Windows a Path of any case counts', () {
      final host = FakeHost(
        operatingSystem: HostOperatingSystem.windows,
        environment: {'Path': r'C:\sdk\bin'},
      );
      final environment = host.environment();

      expect(environment.withPath(const {'path': 'x'}), {'path': 'x'});
      expect(environment.withPath(const {}), {'Path': r'C:\sdk\bin'});
    });
  });

  group('resolveTool', () {
    test("puts the tool's own PATH first", () async {
      final environment = FakeHost().environment();

      final resolved = await environment.resolveTool(
        const ToolRef('/sdk/bin/dart', environment: {'PATH': '/tool'}),
      );

      expect(resolved.environment, {'PATH': '/tool:/sdk/bin'});
    });

    test('takes flutter and dart from the SDK', () async {
      final environment = FakeHost().environment()
        ..sdk = const FlutterSdk(flutter: '/f/flutter', dart: '/f/dart')
        ..addBinDirs(['/opt/node']);

      final resolved = await environment.resolveTool(
        const ToolRef(
          'dart',
          prefixArgs: ['pub', 'global', 'run', 'flutterfire_cli:flutterfire'],
          environment: {'FOO': 'bar'},
        ),
        ['configure'],
      );

      expect(resolved.executable, '/f/dart');
      expect(resolved.arguments, [
        'pub',
        'global',
        'run',
        'flutterfire_cli:flutterfire',
        'configure',
      ]);
      expect(resolved.environment, {
        'FOO': 'bar',
        'PATH': '/f:/opt/node:/sdk/bin',
      });
      expect(
        (await environment.resolveTool(const ToolRef('flutter'))).executable,
        '/f/flutter',
      );
    });

    test('looks up other tools; flutter needs the SDK', () async {
      final environment = FakeHost().environment();

      await expectLater(
        environment.resolveTool(const ToolRef('flutter')),
        throwsStateError,
      );
      await expectLater(
        environment.resolveTool(const ToolRef('firebase')),
        throwsStateError,
      );
      expect(
        (await environment.resolveTool(const ToolRef('/sdk/bin/dart')))
            .executable,
        '/sdk/bin/dart',
      );
    });
  });

  test('writes temporary files and deletes them on dispose', () async {
    final host = FakeHost();
    final environment = host.environment();

    final first = await environment.writeTempFile('install.sh', 'echo a');
    final second = await environment.writeTempFile('install.sh', 'echo b');

    expect(first, endsWith('install.sh'));
    expect(second, isNot(first));
    expect(host.fileSystem.file(first).readAsStringSync(), 'echo a');
    expect(host.fileSystem.file(second).readAsStringSync(), 'echo b');
    await environment.dispose();
    expect(host.fileSystem.file(first).existsSync(), isFalse);
    expect(host.fileSystem.file(second).existsSync(), isFalse);
    await environment.dispose();
  });

  test('exposes the host', () {
    final host = FakeHost(terminal: true);
    final environment = host.environment(skipExternalSetup: true);

    expect(environment.interactive, isTrue);
    expect(environment.skipExternalSetup, isTrue);
    expect(environment.operatingSystem, HostOperatingSystem.linux);
    expect(environment.prompter, same(host.prompter));
    expect(environment.logger, same(host.logger));
    expect(environment.processRunner, isNot(same(host.processRunner)));
    expect(environment.fileSystem, same(host.fileSystem));
  });
}

/// Records the environment of every call, then delegates.
final class _Recording implements SmfProcessRunner {
  _Recording(this._runner, this._seen);

  final SmfProcessRunner _runner;
  final List<Map<String, String>> _seen;

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) {
    _seen.add(environment);
    return _runner.run(executable, arguments);
  }

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) async {
    _seen.add(environment);
    return 0;
  }
}
