import 'package:file/file.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/selection.dart';

/// The files and directories that Flutter and pub write into an app with
/// the absolute path of the app or of the machine's tools, relative to the
/// root of the app. They are not moved with the app from its temporary
/// directory; `flutter pub get` writes them again in the app's final place.
const flutterToolFiles = [
  '.dart_tool',
  'build',
  '.flutter-plugins',
  '.flutter-plugins-dependencies',
  'ios/Flutter/Generated.xcconfig',
  'ios/Flutter/flutter_export_environment.sh',
  'ios/Flutter/ephemeral',
  'macos/Flutter/ephemeral',
  'linux/flutter/ephemeral',
  'windows/flutter/ephemeral',
];

/// Stage 10 of the pipeline: moves the app from [source], the temporary
/// directory it was generated in, to the place that stage 1 decided,
/// [target].
///
/// The files of [flutterToolFiles] stay behind, since they hold the
/// temporary path; `flutter pub get` writes them again in the app's
/// place. An existing directory that [target] replaces is set aside first
/// and deleted only once the app is in its place; if the move fails, it is
/// put back. A directory that appeared at the target meanwhile is never
/// replaced unless stage 1 decided to replace it.
///
/// The move renames the directory. When the temporary directory is on
/// another file system, it copies the app next to the target and renames
/// the copy into place, so the target never holds half an app.
///
/// Throws a [GenerationFailedException] if the app cannot be moved; the app
/// is then still in [source], and the error says so. What only takes space
/// once the app is in place, such as the replaced directory that cannot be
/// deleted, is a warning of [logger].
Future<void> moveApp(
  FileSystem fileSystem, {
  required String source,
  required TargetDecision target,
  required SmfLogger logger,
}) async {
  final destination = fileSystem.directory(target.path);
  Directory? setAside;
  try {
    for (final path in flutterToolFiles) {
      final entity = fileSystem.path.joinAll([source, ...path.split('/')]);
      final type = fileSystem.typeSync(entity, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await fileSystem.directory(entity).delete(recursive: true);
      } else if (type != FileSystemEntityType.notFound) {
        await fileSystem.file(entity).delete();
      }
    }

    await destination.parent.create(recursive: true);
    final type = fileSystem.typeSync(target.path);
    if (type == FileSystemEntityType.directory) {
      if (destination.listSync().isEmpty) {
        await destination.delete();
      } else if (target.replaceExisting) {
        final aside = await _freeSibling(destination, 'replaced');
        await destination.rename(aside);
        setAside = fileSystem.directory(aside);
      } else {
        throw GenerationFailedException(
          '${target.path} appeared while the app was being generated, so the '
          'app stays in $source.',
        );
      }
    } else if (type != FileSystemEntityType.notFound) {
      throw GenerationFailedException(
        '${target.path} is a file, so the app stays in $source.',
      );
    }
  } on FileSystemException catch (error) {
    throw GenerationFailedException(
      'The app could not be moved to ${target.path}, so it stays in $source: '
      '$error',
    );
  }

  try {
    await _move(fileSystem.directory(source), destination, logger);
  } on Object catch (error) {
    final aside = setAside;
    if (aside != null) {
      try {
        await aside.rename(target.path);
      } on FileSystemException {
        throw GenerationFailedException(
          'The app could not be moved to ${target.path}, so it stays in '
          '$source: $error\nThe directory it was to replace is at '
          '${aside.path}.',
        );
      }
    }
    throw GenerationFailedException(
      'The app could not be moved to ${target.path}, so it stays in $source: '
      '$error',
    );
  }

  if (setAside case final aside?) {
    try {
      await aside.delete(recursive: true);
    } on FileSystemException catch (error) {
      logger.warn(
        'The app replaced ${target.path}, but the old files could not be '
        'deleted from ${aside.path}: $error',
      );
    }
  }
}

/// A path next to [directory] that nothing has, marked with [purpose].
Future<String> _freeSibling(Directory directory, String purpose) async {
  final fileSystem = directory.fileSystem;
  var index = 1;
  while (true) {
    final candidate = '${directory.path}.smf-$purpose-$index';
    if (fileSystem.typeSync(candidate) == FileSystemEntityType.notFound) {
      return candidate;
    }
    index++;
  }
}

/// Moves [source] to [destination], which does not exist: renames it, or,
/// if a rename cannot move it, as between file systems, copies it next to
/// [destination] and renames the copy.
///
/// Once the app is in place, a [source] that cannot be deleted is a warning
/// of [logger].
Future<void> _move(
  Directory source,
  Directory destination,
  SmfLogger logger,
) async {
  try {
    await source.rename(destination.path);
    return;
  } on FileSystemException {
    // Renaming does not cross file systems; copy instead.
  }
  final copy = destination.fileSystem.directory(
    await _freeSibling(destination, 'new'),
  );
  try {
    await _copy(source, copy);
    await copy.rename(destination.path);
  } on Object {
    try {
      if (copy.existsSync()) await copy.delete(recursive: true);
    } on FileSystemException catch (error) {
      logger.warn('The partial copy at ${copy.path} could not be deleted: '
          '$error');
    }
    rethrow;
  }
  try {
    await source.delete(recursive: true);
  } on FileSystemException catch (error) {
    logger.warn(
      'The app is in ${destination.path}, but its temporary copy could not '
      'be deleted from ${source.path}: $error',
    );
  }
}

/// Copies the files, directories and links of [source] into [destination].
Future<void> _copy(Directory source, Directory destination) async {
  final context = source.fileSystem.path;
  final fileSystem = destination.fileSystem;
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final path = context.join(
      destination.path,
      context.relative(entity.path, from: source.path),
    );
    switch (entity) {
      case final Directory _:
        await fileSystem.directory(path).create(recursive: true);
      case final File file:
        await fileSystem.file(path).parent.create(recursive: true);
        await file.copy(path);
      case final Link link:
        await fileSystem.link(path).parent.create(recursive: true);
        await fileSystem.link(path).create(await link.target());
    }
  }
}
