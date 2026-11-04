import 'dart:convert';
import 'dart:io';

import 'package:smf_pipeline/src/render.dart';
import 'package:smf_pipeline/src/testing/file_indexer.dart';
import 'package:yaml/yaml.dart';

/// [text], the value of a constant that the compiler cannot evaluate, as
/// [DartOnlyApp.compile] and the compiler of a release build of Flutter
/// quote it in their error: in double quotes, with each backslash doubled and
/// each double quote and control character escaped. A test looks for the
/// text of such an error, such as `EnvRole.releaseErrorOf`, in this form in
/// what a build printed.
String compilerQuoteOf(String text) {
  final escaped = text.replaceAllMapped(
    RegExp(r'[\\"\x00-\x1f]'),
    (match) => switch (match[0]!) {
      r'\' => r'\\',
      '"' => r'\"',
      '\n' => r'\n',
      '\r' => r'\r',
      '\t' => r'\t',
      '\b' => r'\b',
      '\f' => r'\f',
      final control =>
        '\\u${control.codeUnitAt(0).toRadixString(16).padLeft(4, '0')}',
    },
  );
  return '"$escaped"';
}

/// Dart files of a rendered app that need nothing but the Dart SDK, written
/// to a temporary directory as the package of the app, so that a test
/// compiles them as a release build does, or runs them, without Flutter.
///
/// It holds the files that a test names and the files of the app that they
/// import, directly or not, and refuses a file that imports a package other
/// than the app itself, such as `package:flutter`, which the directory does
/// not have. [delete] removes the directory.
final class DartOnlyApp {
  DartOnlyApp._(this._root, this.files);

  /// Writes the files of [app] at [paths], each by its path from the root of
  /// the app, such as `lib/core/env/app_env.dart`, and the files of the app
  /// that they import or export, directly or not, as the package that the
  /// `pubspec.yaml` of [app] names.
  ///
  /// Throws an [ArgumentError] that names the file for a path that [app]
  /// lacks, for an import of a package other than the app, and for an import
  /// of a file that [app] lacks; and a [StateError] when [app] has no
  /// `pubspec.yaml` with a name.
  factory DartOnlyApp.write(RenderedApp app, Iterable<String> paths) {
    final package = _packageOf(app);
    final files = _filesOf(app, paths, package);
    final root = Directory.systemTemp.createTempSync('smf_dart_only_app_');
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    for (final path in files) {
      write('app/$path', app.files[path]!.text);
    }
    write('app/pubspec.yaml', 'name: $package\n');
    write(
      _packageConfig,
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': package,
            'rootUri': '../',
            'packageUri': 'lib/',
            'languageVersion': _languageVersion,
          },
        ],
      }),
    );
    return DartOnlyApp._(root, Set.unmodifiable(files));
  }

  /// The files of [app] at [paths] and those that they import or export,
  /// directly or not, as [package], the package of the app, by their paths
  /// from the root of the app. It throws as [DartOnlyApp.write] does.
  static Set<String> _filesOf(
    RenderedApp app,
    Iterable<String> paths,
    String package,
  ) {
    final files = <String>{};
    final pending = [
      for (final path in paths) (path: path, importedBy: null as String?),
    ];
    while (pending.isNotEmpty) {
      final (:path, :importedBy) = pending.removeLast();
      if (!files.add(path)) continue;
      final file = app.files[path];
      if (file == null) {
        throw ArgumentError(
          importedBy == null
              ? 'The app has no file $path.'
              : '$importedBy imports $path, which the app does not have.',
        );
      }
      for (final target in _importedBy(path, file.text, package)) {
        pending.add((path: target, importedBy: path));
      }
    }
    return files;
  }

  /// The files of the app that the Dart file at [path] with [text] imports
  /// or exports, by their paths from the root of the app, [package] being
  /// the package of the app. Throws an [ArgumentError] for an import of
  /// another package.
  static Iterable<String> _importedBy(
    String path,
    String text,
    String package,
  ) sync* {
    final index = DartFileIndexer.index(path, text);
    for (final directive in [...index.imports, ...index.exports]) {
      final uri = directive.uri;
      if (uri.startsWith('dart:')) continue;
      final target = _pathOf(uri, path, package);
      if (target == null) {
        throw ArgumentError(
          '$path imports $uri, a package other than the app, which needs '
          'more than the Dart SDK.',
        );
      }
      yield target;
    }
  }

  /// The path of the package config of the app in the directory.
  static const _packageConfig = 'app/.dart_tool/package_config.json';

  /// The language version of the Dart SDK that runs the test, such as
  /// `3.12`.
  static final String _languageVersion =
      RegExp(r'^\d+\.\d+').firstMatch(Platform.version)![0]!;

  final Directory _root;

  /// The paths of the files of the app that the directory has, from the
  /// root of the app.
  final Set<String> files;

  /// The directory of the package of the app, with its `pubspec.yaml` and
  /// its files at their paths, which the analyzer of a test can analyze.
  String get path => Directory('${_root.path}/app').resolveSymbolicLinksSync();

  /// Runs [script], a Dart program that imports the files of the app by its
  /// package, with the Dart VM, which declares each of [defines] as
  /// `-D<key>=<value>`, as the `flutter` tool declares the value of a line
  /// `KEY=value` of `.env` with `--dart-define-from-file`, and does not
  /// declare `dart.vm.product`, as a debug build does not. Returns what the
  /// program printed, with each line break as `\n`, also on Windows, where
  /// `dart` prints `\r\n`.
  ///
  /// Throws a [StateError] with what it printed if the program fails.
  Future<String> run(
    String script, {
    Map<String, String> defines = const {},
  }) async {
    final result = await _dart([
      _packages,
      ..._definesOf(defines),
      _script('run.dart', script),
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'The program failed with ${result.exitCode}: ${result.stdout}'
        '${result.stderr}',
      );
    }
    return '${result.stdout}'.replaceAll('\r\n', '\n');
  }

  /// Compiles [script], a Dart program that imports the files of the app by
  /// its package, to kernel with `dart compile kernel`, which evaluates the
  /// constants of the program as the compiler of a release build does: it
  /// declares `dart.vm.product` and each of [defines] as `-D<key>=<value>`.
  /// Returns whether it compiled, and what the compiler printed, which has
  /// the error of a constant that it cannot evaluate.
  Future<({bool compiled, String output})> compile(
    String script, {
    Map<String, String> defines = const {},
  }) async {
    final result = await _dart([
      'compile',
      'kernel',
      _packages,
      ..._definesOf(defines),
      '-o',
      '${_root.path}/compiled.dill',
      _script('compiled.dart', script),
    ]);
    return (
      compiled: result.exitCode == 0,
      output: '${result.stdout}${result.stderr}',
    );
  }

  /// Deletes the directory of the app.
  void delete() => _root.deleteSync(recursive: true);

  /// Writes [script] to [name] in the directory, outside the package of the
  /// app, and returns its path.
  String _script(String name, String script) =>
      (File('${_root.path}/$name')..writeAsStringSync(script)).path;

  /// The option of `dart` that gives a program the package of the app.
  String get _packages => '--packages=$path/.dart_tool/package_config.json';

  /// Runs `dart` with [arguments].
  Future<ProcessResult> _dart(List<String> arguments) => Process.run(
        Platform.resolvedExecutable,
        arguments,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

  static List<String> _definesOf(Map<String, String> defines) => [
        for (final MapEntry(:key, :value) in defines.entries) '-D$key=$value',
      ];
}

/// The package that the `pubspec.yaml` of [app] names.
String _packageOf(RenderedApp app) {
  final pubspec = app.files['pubspec.yaml'];
  final name =
      pubspec == null ? null : (loadYaml(pubspec.text) as YamlMap?)?['name'];
  if (name is! String) {
    throw StateError('The app has no pubspec.yaml with the name of a package.');
  }
  return name;
}

/// The path from the root of the app of the file that [uri], an import or
/// an export in the file at [from], names: `lib/` and the rest of a URI of
/// the app's [package], or [uri] from the directory of [from]. `null` for a
/// URI of another package.
String? _pathOf(String uri, String from, String package) {
  if (uri.startsWith('package:')) {
    final prefix = 'package:$package/';
    return uri.startsWith(prefix)
        ? 'lib/${uri.substring(prefix.length)}'
        : null;
  }
  return Uri.parse(from).resolve(uri).path;
}
