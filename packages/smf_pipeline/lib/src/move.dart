import 'package:file/file.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/postgen.dart';
import 'package:smf_pipeline/src/selection.dart';

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
/// The move renames the directory, or copies it when the temporary
/// directory is on another file system. Throws a
/// [GenerationFailedException] if the app cannot be moved; the app is then
/// still in [source].
Future<void> moveApp(
  FileSystem fileSystem, {
  required String source,
  required TargetDecision target,
}) async {
  final context = fileSystem.path;
  for (final path in flutterToolFiles) {
    final entity = context.joinAll([source, ...path.split('/')]);
    final type = fileSystem.typeSync(entity, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await fileSystem.directory(entity).delete(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      await fileSystem.file(entity).delete();
    }
  }

  final destination = fileSystem.directory(target.path);
  await destination.parent.create(recursive: true);
  Directory? setAside;
  if (destination.existsSync()) {
    if (destination.listSync().isEmpty) {
      await destination.delete();
    } else if (target.replaceExisting) {
      setAside = await destination.rename(await _freeSibling(destination));
    } else {
      throw GenerationFailedException(
        '${target.path} appeared while the app was being generated, so the '
        'app stays in $source.',
      );
    }
  }

  try {
    await _move(fileSystem.directory(source), destination);
  } on Object catch (error) {
    if (destination.existsSync()) await destination.delete(recursive: true);
    await setAside?.rename(target.path);
    throw GenerationFailedException(
      'The app could not be moved to ${target.path}, so it stays in '
      '$source: $error',
    );
  }
  await setAside?.delete(recursive: true);
}

/// A path next to [directory] that nothing has, to set it aside at.
Future<String> _freeSibling(Directory directory) async {
  final fileSystem = directory.fileSystem;
  var index = 1;
  while (true) {
    final candidate = '${directory.path}.smf-replaced-$index';
    if (fileSystem.typeSync(candidate) == FileSystemEntityType.notFound) {
      return candidate;
    }
    index++;
  }
}

/// Moves [source] to [destination], which does not exist: renames it, or
/// copies and deletes it if a rename cannot move it, as between file
/// systems.
Future<void> _move(Directory source, Directory destination) async {
  try {
    await source.rename(destination.path);
    return;
  } on FileSystemException {
    // Renaming does not cross file systems; copy instead.
  }
  final context = source.fileSystem.path;
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final path = context.join(
      destination.path,
      context.relative(entity.path, from: source.path),
    );
    switch (entity) {
      case final Directory _:
        await destination.fileSystem.directory(path).create(recursive: true);
      case final File file:
        await destination.fileSystem.file(path).parent.create(recursive: true);
        await file.copy(path);
      case final Link link:
        await destination.fileSystem.link(path).create(await link.target());
    }
  }
  await source.delete(recursive: true);
}
