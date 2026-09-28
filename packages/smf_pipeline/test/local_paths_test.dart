// The pipeline on the file system of the machine, in directories whose
// names have spaces and letters beyond ASCII, as those in the profile of a
// user whose name has them do on any system, such as the temporary
// directory C:\Users\Євген\AppData\Local\Temp on Windows.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/src/move.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The file system of the machine, with [temporary] as its temporary
/// directory.
final class _Machine extends ForwardingFileSystem {
  _Machine(this.temporary) : super(const LocalFileSystem());

  final String temporary;

  @override
  Directory get systemTempDirectory => delegate.directory(temporary);
}

/// The operating system of this machine.
HostOperatingSystem get _system => switch (io.Platform.operatingSystem) {
      'macos' => HostOperatingSystem.macos,
      'windows' => HostOperatingSystem.windows,
      'linux' => HostOperatingSystem.linux,
      _ => HostOperatingSystem.other,
    };

/// A file of the app with letters beyond ASCII in its name and text.
const _notes = 'docs/нотатки é.txt';
const _notesText = 'Привіт, café ✓\n';

void main() {
  late io.Directory root;
  late String temporary;
  late String output;
  final context = const LocalFileSystem().path;

  setUp(() {
    root = io.Directory.systemTemp.createTempSync('smf_paths_');
    temporary = context.join(root.path, 'тимчасова тека é');
    output = context.join(root.path, 'SMF apps застосунки é');
    io.Directory(temporary).createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  test(
      'writes the app into its temporary directory and moves it into place, '
      'with the names and text of its files', () async {
    // The executables of a Flutter SDK, which the runner does not start.
    final bin = context.join(root.path, 'Flutter SDK é', 'bin');
    final windows = _system == HostOperatingSystem.windows;
    for (final name in windows ? ['flutter.bat', 'dart.bat'] : ['flutter']) {
      io.File(context.join(bin, name)).createSync(recursive: true);
    }
    if (!windows) io.File(context.join(bin, 'dart')).createSync();
    io.Directory(context.join(bin, 'cache', 'dart-sdk'))
        .createSync(recursive: true);
    final fileSystem = _Machine(temporary);
    final runner = RecordingRunner(
      // pub get writes a file with the path of the app, as Flutter does.
      onRun: (call) {
        if (call.arguments.contains('get')) {
          fileSystem.file(
            context.join(call.workingDirectory!, '.dart_tool', 'path'),
          )
            ..createSync(recursive: true)
            ..writeAsStringSync(call.workingDirectory!);
        }
        return const SmfProcessResult(exitCode: 0);
      },
    );
    final host = SmfHost(
      prompter: ScriptedPrompter(const []),
      processRunner: runner,
      logger: FakeLogger(),
      fileSystem: fileSystem,
      environmentVariables: {'PATH': bin},
      operatingSystem: _system,
      hasTerminal: false,
    );
    final modules = [
      scaffold(
        contributions: [
          BrickContribution(bundle('notes', files: {_notes: _notesText})),
        ],
      ),
      TestModule('extra'),
    ];

    final app = await CreatePipeline(
      registry: ModuleRegistry(modules),
      host: host,
    ).run(
      CreateRequest(
        appName: 'my_app',
        outputDirectory: output,
        modules: const [ModuleId('extra')],
        skipExternalSetup: true,
      ),
    );

    final place = context.join(output, 'my_app');
    expect(app!.path, place);
    expect(
      io.File(context.join(place, 'lib', 'main.dart')).existsSync(),
      isTrue,
    );
    expect(
      io.File(context.join(place, _notes)).readAsBytesSync(),
      utf8.encode(_notesText),
    );
    // The first pub get runs in the temporary directory, the last in the
    // place of the app, which then has the files that it writes.
    expect(runner.calls.first.workingDirectory, startsWith(temporary));
    expect(runner.calls.last.workingDirectory, place);
    expect(
      io.File(context.join(place, '.dart_tool', 'path')).readAsStringSync(),
      place,
    );
    expect(io.Directory(temporary).listSync(), isEmpty);
  });

  test(
      'copies the app into place when renaming cannot move it, as between '
      'file systems', () async {
    final source = context.join(temporary, 'smf_create_1', 'my_app');
    final files = {
      context.join('lib', 'main.dart'): 'void main() {}\n',
      _notes: _notesText,
    };
    for (final MapEntry(key: path, value: text) in files.entries) {
      io.File(context.join(source, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    }
    final target = context.join(output, 'my_app');
    final logger = FakeLogger();

    await moveApp(
      FaultyFileSystem(const LocalFileSystem(), noRename: {source}),
      source: source,
      target: TargetDecision(path: target),
      logger: logger,
    );

    for (final MapEntry(key: path, value: text) in files.entries) {
      expect(
        io.File(context.join(target, path)).readAsBytesSync(),
        utf8.encode(text),
        reason: path,
      );
    }
    expect(io.Directory(source).existsSync(), isFalse);
    expect(io.Directory(output).listSync().map((entity) => entity.path), [
      target,
    ]);
    expect(logger.warnings, isEmpty);
  });
}
