import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:smf_pipeline/src/move.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A file system where the directories at some paths fail: they cannot be
/// renamed, as if they were on another file system, deleted, or listed.
final class _Faulty extends ForwardingFileSystem {
  _Faulty(
    super.delegate, {
    this.noRename = const {},
    this.noDelete = const {},
    this.unreadable = const {},
  });

  final Set<String> noRename;
  final Set<String> noDelete;
  final Set<String> unreadable;

  @override
  Directory directory(dynamic path) {
    final directory = delegate.directory(path);
    final faulty = {...noRename, ...noDelete, ...unreadable};
    return faulty.contains(directory.path)
        ? _FaultyDirectory(this, directory)
        : directory;
  }
}

final class _FaultyDirectory
    extends ForwardingFileSystemEntity<Directory, io.Directory>
    with ForwardingDirectory<Directory> {
  _FaultyDirectory(this._faulty, this.delegate);

  final _Faulty _faulty;

  @override
  final io.Directory delegate;

  @override
  FileSystem get fileSystem => _faulty;

  @override
  Directory wrapDirectory(io.Directory delegate) =>
      _faulty.directory(delegate.path);

  @override
  File wrapFile(io.File delegate) => delegate as File;

  @override
  Link wrapLink(io.Link delegate) => delegate as Link;

  @override
  Directory childDirectory(String basename) =>
      (delegate as Directory).childDirectory(basename);

  @override
  File childFile(String basename) =>
      (delegate as Directory).childFile(basename);

  @override
  Link childLink(String basename) =>
      (delegate as Directory).childLink(basename);

  @override
  Future<Directory> rename(String newPath) async =>
      _faulty.noRename.contains(path)
          ? throw FileSystemException('Cross-device link', path)
          : super.rename(newPath);

  @override
  Future<Directory> delete({bool recursive = false}) async =>
      _faulty.noDelete.contains(path)
          ? throw FileSystemException('Permission denied', path)
          : super.delete(recursive: recursive);

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) =>
      _faulty.unreadable.contains(path)
          ? Stream.error(FileSystemException('Permission denied', path))
          : super.list(recursive: recursive, followLinks: followLinks);
}

void main() {
  late MemoryFileSystem fileSystem;
  late FakeLogger logger;

  void write(String path, [String text = 'x']) => fileSystem.file(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    logger = FakeLogger();
    write('/tmp/smf/app/lib/main.dart', 'main');
    write('/tmp/smf/app/pubspec.yaml');
    write('/tmp/smf/app/.dart_tool/package_config.json');
    write('/tmp/smf/app/build/cache');
    write('/tmp/smf/app/ios/Flutter/Generated.xcconfig');
    write('/tmp/smf/app/ios/Flutter/Debug.xcconfig');
    write('/tmp/smf/app/ios/Flutter/ephemeral/env');
    write('/tmp/smf/app/.flutter-plugins-dependencies');
  });

  List<String> filesIn(String directory) => [
        for (final entity in fileSystem
            .directory(directory)
            .listSync(recursive: true, followLinks: false))
          if (entity is File) entity.path.substring(directory.length + 1),
      ]..sort();

  List<String> namesIn(String directory) => [
        for (final entity in fileSystem.directory(directory).listSync())
          entity.basename,
      ]..sort();

  Future<void> move(TargetDecision target, {FileSystem? on}) => moveApp(
        on ?? fileSystem,
        source: '/tmp/smf/app',
        target: target,
        logger: logger,
      );

  const moved = [
    'ios/Flutter/Debug.xcconfig',
    'lib/main.dart',
    'pubspec.yaml',
  ];

  test('moves the app without the files of the Flutter tools', () async {
    await move(const TargetDecision(path: '/work/out/app'));

    expect(filesIn('/work/out/app'), moved);
    expect(fileSystem.directory('/tmp/smf/app').existsSync(), isFalse);
  });

  test('moves the app on Windows', () async {
    final windows = MemoryFileSystem.test(style: FileSystemStyle.windows);
    for (final path in [
      r'C:\tmp\smf\app\lib\main.dart',
      r'C:\tmp\smf\app\ios\Flutter\Generated.xcconfig',
      r'C:\tmp\smf\app\windows\flutter\ephemeral\generated_config.cmake',
    ]) {
      windows.file(path).createSync(recursive: true);
    }

    await moveApp(
      windows,
      source: r'C:\tmp\smf\app',
      target: const TargetDecision(path: r'C:\work\app'),
      logger: logger,
    );

    expect(
      [
        for (final entity
            in windows.directory(r'C:\work\app').listSync(recursive: true))
          if (entity is File) entity.path,
      ],
      [r'C:\work\app\lib\main.dart'],
    );
  });

  test('replaces the directory that stage 1 decided to replace', () async {
    write('/work/app/old.txt');
    // Another run's leftover does not stop this one.
    write('/work/app.smf-replaced-1/older.txt');

    await move(const TargetDecision(path: '/work/app', replaceExisting: true));

    expect(filesIn('/work/app'), moved);
    expect(namesIn('/work'), ['app', 'app.smf-replaced-1']);
    expect(logger.warnings, isEmpty);
  });

  test('an empty directory at the target is taken over', () async {
    fileSystem.directory('/work/app').createSync(recursive: true);

    await move(const TargetDecision(path: '/work/app'));

    expect(filesIn('/work/app'), moved);
  });

  test('never replaces a directory that appeared meanwhile, nor a file',
      () async {
    write('/work/app/mine.txt');
    write('/work/notes');

    await expectLater(
      move(const TargetDecision(path: '/work/app')),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          '/work/app appeared while the app was being generated, so the app '
              'stays in /tmp/smf/app.',
        ),
      ),
    );
    await expectLater(
      move(const TargetDecision(path: '/work/notes', replaceExisting: true)),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          '/work/notes is a file, so the app stays in /tmp/smf/app.',
        ),
      ),
    );
    expect(filesIn('/work/app'), ['mine.txt']);
    expect(filesIn('/tmp/smf/app'), moved);
  });

  test('copies the app next to the target when renaming cannot move it',
      () async {
    fileSystem
        .link('/tmp/smf/app/lib/sub/latest.dart')
        .createSync('../main.dart', recursive: true);

    await move(
      const TargetDecision(path: '/work/app'),
      on: _Faulty(fileSystem, noRename: {'/tmp/smf/app'}),
    );

    expect(filesIn('/work/app'), moved);
    expect(
      fileSystem.file('/work/app/lib/main.dart').readAsStringSync(),
      'main',
    );
    expect(
      fileSystem.link('/work/app/lib/sub/latest.dart').targetSync(),
      '../main.dart',
    );
    expect(namesIn('/work'), ['app']);
    expect(fileSystem.directory('/tmp/smf/app').existsSync(), isFalse);
  });

  test('a temporary copy that cannot be deleted only warns', () async {
    await move(
      const TargetDecision(path: '/work/app'),
      on: _Faulty(
        fileSystem,
        noRename: {'/tmp/smf/app'},
        noDelete: {'/tmp/smf/app'},
      ),
    );

    expect(filesIn('/work/app'), moved);
    expect(
      logger.warnings.single,
      startsWith('The app is in /work/app, but its temporary copy could not '
          'be deleted from /tmp/smf/app:'),
    );
  });

  test('puts the replaced directory back when the app cannot be moved',
      () async {
    write('/work/app/old.txt');

    await expectLater(
      move(
        const TargetDecision(path: '/work/app', replaceExisting: true),
        on: _Faulty(
          fileSystem,
          noRename: {'/tmp/smf/app'},
          unreadable: {'/tmp/smf/app'},
        ),
      ),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          startsWith('The app could not be moved to /work/app, so it stays in '
              '/tmp/smf/app:'),
        ),
      ),
    );
    expect(filesIn('/work/app'), ['old.txt']);
    expect(namesIn('/work'), ['app']);
    expect(filesIn('/tmp/smf/app'), moved);
  });

  test('names the replaced directory if it cannot be put back', () async {
    write('/work/app/old.txt');

    await expectLater(
      move(
        const TargetDecision(path: '/work/app', replaceExisting: true),
        on: _Faulty(
          fileSystem,
          noRename: {'/tmp/smf/app', '/work/app.smf-replaced-1'},
          unreadable: {'/tmp/smf/app'},
        ),
      ),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          endsWith('The directory it was to replace is at '
              '/work/app.smf-replaced-1.'),
        ),
      ),
    );
    expect(filesIn('/work/app.smf-replaced-1'), ['old.txt']);
  });

  test('a directory that cannot be set aside keeps the app where it is',
      () async {
    write('/work/app/old.txt');

    await expectLater(
      move(
        const TargetDecision(path: '/work/app', replaceExisting: true),
        on: _Faulty(fileSystem, noRename: {'/work/app'}),
      ),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          startsWith('The app could not be moved to /work/app, so it stays in '
              '/tmp/smf/app:'),
        ),
      ),
    );
    expect(filesIn('/work/app'), ['old.txt']);
  });

  test('a replaced directory that cannot be deleted only warns', () async {
    write('/work/app/old.txt');

    await move(
      const TargetDecision(path: '/work/app', replaceExisting: true),
      on: _Faulty(fileSystem, noDelete: {'/work/app.smf-replaced-1'}),
    );

    expect(filesIn('/work/app'), moved);
    expect(
      logger.warnings.single,
      startsWith('The app replaced /work/app, but the old files could not be '
          'deleted from /work/app.smf-replaced-1:'),
    );
  });
}
