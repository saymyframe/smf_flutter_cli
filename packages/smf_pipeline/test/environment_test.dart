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

  group('resolveTool', () {
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
        'PATH': '/opt/node:/sdk/bin',
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

    final first = await environment.writeTempFile('a.sh', 'echo a');
    final second = await environment.writeTempFile('b.sh', 'echo b');

    expect(host.fileSystem.file(first).readAsStringSync(), 'echo a');
    expect(
      host.fileSystem.file(second).parent.path,
      host.fileSystem.file(first).parent.path,
    );
    await environment.dispose();
    expect(host.fileSystem.file(first).existsSync(), isFalse);
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
    expect(environment.processRunner, isA<NoProcessRunner>());
    expect(environment.fileSystem, same(host.fileSystem));
  });
}
