import 'dart:convert';
import 'dart:io';

/// Runs [commands] one after another, each with `bash -c`, in a clone of a
/// commit of the app in [directory], as a job of CI runs them on a runner, and
/// removes the clone. Returns 0 and the output, or the exit code of the first
/// command that fails and the output up to it, whose last line names the
/// command.
///
/// So the clone has what git has of the app, and not what the `.gitignore` of
/// the app keeps out of it, such as `.env`, `build/` or `.dart_tool/`. The
/// repository of that commit is in a temporary directory too, so the app stays
/// as it was. What the machine ignores, signs or checks in its own
/// configuration of git has no part in it.
///
/// Each command gets the variables of [environment] in its process, next to
/// those of this one. With [artifact], a path in the clone, a run whose
/// commands all succeed fails when they left no such file.
Future<(int, String)> runCiCommands(
  String directory,
  List<String> commands, {
  Map<String, String> environment = const {},
  String? artifact,
}) async {
  final output = StringBuffer();
  final temp = await Directory.systemTemp.createTemp('smf_ci_');
  try {
    final clone = '${temp.path}/app';
    final cloned =
        await _cloneTo(clone, '${temp.path}/repository', directory, output);
    if (cloned != 0) return (cloned, output.toString());
    for (final command in commands) {
      output.writeln('\$ $command');
      final code = await _run(
        'bash',
        ['-c', command],
        clone,
        output,
        environment: environment,
      );
      if (code != 0) {
        output.writeln('This command of CI exited with $code: $command');
        return (code, output.toString());
      }
    }
    if (artifact != null && !File('$clone/$artifact').existsSync()) {
      output.writeln('The commands of CI left no file $artifact.');
      return (1, output.toString());
    }
    return (0, output.toString());
  } finally {
    await temp.delete(recursive: true);
  }
}

/// Clones to [clone] a commit of what git has of the app in [directory], in a
/// new [repository]; returns the exit code of the first command of git that
/// fails, or 0.
Future<int> _cloneTo(
  String clone,
  String repository,
  String directory,
  StringBuffer output,
) async {
  // The app has no repository of its own to add to, and gets none.
  final inApp = ['--git-dir=$repository', '--work-tree=.'];
  for (final arguments in [
    [...inApp, 'init', '-q'],
    ['-c', 'core.excludesFile=', ...inApp, 'add', '-A'],
    [
      '-c',
      'user.name=SMF',
      '-c',
      'user.email=ci@saymyframe.invalid',
      '-c',
      'commit.gpgSign=false',
      ...inApp,
      'commit',
      '-q',
      '--no-verify',
      '-m',
      'The app',
    ],
    ['clone', '-q', repository, clone],
  ]) {
    final code = await _run('git', arguments, directory, output);
    if (code != 0) {
      output.writeln(
        'git ${arguments.join(' ')} exited with $code, so no command of CI '
        'ran.',
      );
      return code;
    }
  }
  return 0;
}

/// Runs [executable] with [arguments] in [directory], adds what it prints to
/// [output] and returns its exit code.
Future<int> _run(
  String executable,
  List<String> arguments,
  String directory,
  StringBuffer output, {
  Map<String, String>? environment,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: directory,
    environment: environment,
    stdoutEncoding: const Utf8Codec(allowMalformed: true),
    stderrEncoding: const Utf8Codec(allowMalformed: true),
  );
  output
    ..write(result.stdout)
    ..write(result.stderr);
  return result.exitCode;
}
