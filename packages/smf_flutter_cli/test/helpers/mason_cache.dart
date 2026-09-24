import 'dart:io';

import 'package:mason/mason.dart';
import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/bundles/smf_cli_brick_bundle.dart';

/// Points mason's brick cache (normally under the user's home directory) at
/// [cacheDir]. Undo with [resetMasonCache].
void useMasonCache(Directory cacheDir) {
  BricksJson.testEnvironment = {'MASON_CACHE': cacheDir.path};
}

/// Restores mason's default cache location.
void resetMasonCache() {
  BricksJson.testEnvironment = null;
}

/// Makes `runCli` hermetic by unpacking the CLI brick into [cacheDir] without
/// its hooks.
///
/// The real pre-gen hook only rewrites `working_dir` to
/// `<output>/<app_name>`, but running it (and the post-gen hook, which calls
/// `flutter pub get`, `dart fix` and `dart format`) needs `dart pub get` and a
/// Flutter SDK. `MasonGenerator.fromBundle` reuses an already unpacked bundle
/// directory as is, so removing its `hooks/` folder turns both hooks into
/// no-ops. As a consequence `working_dir` stays equal to the output directory
/// for every generator that runs after the bricks.
Future<void> installHooklessCliBrick(Directory cacheDir) async {
  useMasonCache(cacheDir);
  await MasonGenerator.fromBundle(smfCliBrickBundle);

  final bundled = Directory(p.join(cacheDir.path, 'bundled'));
  final unpacked = bundled.listSync().whereType<Directory>().where(
        (dir) => p.basename(dir.path).startsWith('${smfCliBrickBundle.name}_'),
      );
  for (final dir in unpacked) {
    Directory(p.join(dir.path, 'hooks')).deleteSync(recursive: true);
  }

  final generator = await MasonGenerator.fromBundle(smfCliBrickBundle);
  if (generator.hooks.preGenHook != null ||
      generator.hooks.postGenHook != null) {
    throw StateError('Could not strip the hooks of the CLI brick.');
  }
}
