import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:smf_pipeline/src/move.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A file system where the directory at [source] cannot be renamed, as if it
/// were on another file system, and cannot be listed if [unreadable].
final class _Crossing extends ForwardingFileSystem {
  _Crossing(super.delegate, this.source, {this.unreadable = false});

  final String source;
  final bool unreadable;

  @override
  Directory directory(dynamic path) {
    final directory = delegate.directory(path);
    return directory.path == source ? _Stuck(this, directory) : directory;
  }
}

final class _Stuck extends ForwardingFileSystemEntity<Directory, io.Directory>
    with ForwardingDirectory<Directory> {
  _Stuck(this._crossing, this.delegate);

  final _Crossing _crossing;

  @override
  final io.Directory delegate;

  @override
  FileSystem get fileSystem => _crossing;

  @override
  Directory wrapDirectory(io.Directory delegate) => delegate as Directory;

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
      throw FileSystemException('Cross-device link', path);

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) =>
      _crossing.unreadable
          ? Stream.error(FileSystemException('Permission denied', path))
          : super.list(recursive: recursive, followLinks: followLinks);
}

void main() {
  late MemoryFileSystem fileSystem;

  void write(String path, [String text = 'x']) => fileSystem.file(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  setUp(() {
    fileSystem = MemoryFileSystem.test();
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

  const moved = [
    'ios/Flutter/Debug.xcconfig',
    'lib/main.dart',
    'pubspec.yaml',
  ];

  test('moves the app without the files of the Flutter tools', () async {
    await moveApp(
      fileSystem,
      source: '/tmp/smf/app',
      target: const TargetDecision(path: '/work/out/app'),
    );

    expect(filesIn('/work/out/app'), moved);
    expect(fileSystem.directory('/tmp/smf/app').existsSync(), isFalse);
  });

  test('replaces the directory that stage 1 decided to replace', () async {
    write('/work/app/old.txt');
    // Another run's leftover does not stop this one.
    write('/work/app.smf-replaced-1/older.txt');

    await moveApp(
      fileSystem,
      source: '/tmp/smf/app',
      target: const TargetDecision(path: '/work/app', replaceExisting: true),
    );

    expect(filesIn('/work/app'), moved);
    expect(
      fileSystem.directory('/work').listSync().map((e) => e.path),
      unorderedEquals(['/work/app', '/work/app.smf-replaced-1']),
    );
  });

  test('an empty directory at the target is taken over', () async {
    fileSystem.directory('/work/app').createSync(recursive: true);

    await moveApp(
      fileSystem,
      source: '/tmp/smf/app',
      target: const TargetDecision(path: '/work/app'),
    );

    expect(filesIn('/work/app'), moved);
  });

  test('never replaces a directory that appeared meanwhile', () async {
    write('/work/app/mine.txt');

    await expectLater(
      moveApp(
        fileSystem,
        source: '/tmp/smf/app',
        target: const TargetDecision(path: '/work/app'),
      ),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          '/work/app appeared while the app was being generated, so the app '
              'stays in /tmp/smf/app.',
        ),
      ),
    );
    expect(filesIn('/work/app'), ['mine.txt']);
    expect(filesIn('/tmp/smf/app'), moved);
  });

  test('copies the app when renaming cannot move it', () async {
    fileSystem.link('/tmp/smf/app/lib/latest.dart').createSync('main.dart');

    await moveApp(
      _Crossing(fileSystem, '/tmp/smf/app'),
      source: '/tmp/smf/app',
      target: const TargetDecision(path: '/work/app'),
    );

    expect(filesIn('/work/app'), moved);
    expect(
      fileSystem.file('/work/app/lib/main.dart').readAsStringSync(),
      'main',
    );
    expect(
      fileSystem.link('/work/app/lib/latest.dart').targetSync(),
      'main.dart',
    );
    expect(fileSystem.directory('/tmp/smf/app').existsSync(), isFalse);
  });

  test('puts the replaced directory back when the app cannot be moved',
      () async {
    write('/work/app/old.txt');

    await expectLater(
      moveApp(
        _Crossing(fileSystem, '/tmp/smf/app', unreadable: true),
        source: '/tmp/smf/app',
        target: const TargetDecision(path: '/work/app', replaceExisting: true),
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
    expect(filesIn('/tmp/smf/app'), moved);
  });
}
