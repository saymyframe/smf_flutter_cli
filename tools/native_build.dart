// Writes what the apps in a directory build their native side with, for
// Android or iOS, into a file whose hash keys the caches that CI keeps of
// what Gradle downloads for Android and what Swift Package Manager
// downloads for iOS:
//
//   dart tools/native_build.dart <android|ios> <directory of apps> <file>
//
// The apps are the directories right in the directory, as for
// .github/scripts/each_app.sh, such as the app with every module that the
// --create of a matrix tool generates for a job of the plan of CI, once
// `flutter pub get` ran in them, as smf create runs it. For each app, the
// file has what decides what its native build downloads:
// - the plugins of the app with native code for the platform, from the
//   .flutter-plugins-dependencies that `flutter pub get` writes, with the
//   versions that pub resolved for them in pubspec.lock. The plugins of the
//   Flutter SDK, such as integration_test, come with the SDK, and the caches
//   are for every version of Flutter, so they are left out, as the version
//   of Flutter is. Flutter writes no .flutter-plugins-dependencies for an
//   app without plugins of its own, such as the app of the start check
//   without Firebase, which then has none.
// - For Android, the Gradle files of the Android project, which name the
//   versions of Gradle, of its plugins and of the dependencies of the app,
//   without the lines that set the ids of the app, namespace and
//   applicationId.
// - For iOS, the Swift packages that the Xcode project of the app refers to
//   itself, besides those that the plugins bring.
// Apps that build with the same have one text, which the file has once
// whatever the number and the names of the apps. So the jobs whose apps
// build with the same share a cache, and a job whose app builds with
// something else, such as another plugin, another version of one, or
// another version of Gradle, gets a cache of its own. The file must be in
// the workspace, where hashFiles of GitHub Actions finds it, and the tool
// prints what it wrote, for the log of the job. When the apps download
// nothing for the platform, as an app without plugins with iOS code, the
// tool writes no file and removes the one there, so hashFiles of it is
// empty and the job has no cache to restore or save. It fails when the
// directory has no app, when pub did not resolve an app, which then has no
// pubspec.lock or no .dart_tool/package_config.json, and when an app has
// no project for the platform. tools/workflow_apps_test.dart checks that
// the jobs of the workflows key the caches of their native builds with it.
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// The platforms of the native builds, by the name of the directory of
/// their project in an app, which is also the name of their plugins in
/// .flutter-plugins-dependencies.
const platforms = ['android', 'ios'];

/// Why the tool cannot tell what an app builds with.
final class NativeBuildException implements Exception {
  /// An exception with [message].
  NativeBuildException(this.message);

  /// What is missing, and where.
  final String message;

  @override
  String toString() => message;
}

/// What each app in [directory], each directory right in it but a hidden
/// one, builds its native side with for [platform] (see [nativeBuildOf]),
/// by the name of the app, in the order of the names.
///
/// Throws a [NativeBuildException] when [directory] has no app, or when
/// [nativeBuildOf] does for an app.
Map<String, String> nativeBuildsOf(Directory directory, String platform) {
  final apps = {
    for (final entity in directory.listSync())
      if (entity is Directory && !_nameOf(entity).startsWith('.'))
        _nameOf(entity): entity,
  };
  if (apps.isEmpty) {
    throw NativeBuildException('${directory.path} has no app.');
  }
  return {
    for (final name in apps.keys.toList()..sort())
      name: nativeBuildOf(apps[name]!, platform),
  };
}

/// What the app in [app] builds its native side with for [platform], as
/// lines:
/// - `plugin <name> <version> (<source>)` for each plugin with native code
///   for [platform], in the order of their names, with the commit of a
///   plugin from git after its source, but for the plugins of the Flutter
///   SDK;
/// - for Android, `file <path>` for each Gradle file of `android/`, but
///   those in hidden directories and in `build/`, in the order of their
///   paths, each followed by its lines, indented by two spaces, but those
///   that set the ids of the app, namespace and applicationId;
/// - for iOS, `file <path>: remote Swift packages` for each Xcode project
///   of `ios/` that refers to Swift packages itself, in the order of their
///   paths, each followed by the lines of its
///   XCRemoteSwiftPackageReference section, trimmed and indented by two
///   spaces.
///
/// An app that pub resolved without a .flutter-plugins-dependencies, which
/// Flutter writes only for an app with plugins of its own, has no plugins:
/// such as the app of the start check without Firebase, whose only plugin,
/// integration_test, is a dev dependency from the Flutter SDK.
///
/// Throws a [NativeBuildException] when pub did not resolve the app, which
/// then has no pubspec.lock or no .dart_tool/package_config.json, when the
/// app has no version of one of its plugins, or no project for [platform],
/// and an [ArgumentError] for a platform other than those of [platforms].
String nativeBuildOf(Directory app, String platform) {
  final project = switch (platform) {
    'android' => _gradleFilesOf,
    'ios' => _swiftPackagesOf,
    _ =>
      throw ArgumentError.value(platform, 'platform', 'Not one of $platforms'),
  };
  return [..._pluginsOf(app, platform), ...project(app)].join('\n');
}

/// The text of the file for the native builds [builds] of apps: each
/// different build once, in the order of their texts, apart by an empty
/// line, which no build has.
String nativeBuildFileOf(Iterable<String> builds) =>
    '${(builds.toSet().toList()..sort()).join('\n\n')}\n';

/// The name of [entity], the last part of its path.
String _nameOf(FileSystemEntity entity) =>
    entity.uri.pathSegments.lastWhere((part) => part.isNotEmpty);

/// The file [name] of [app], which `flutter pub get` writes when it resolves
/// the app.
File _resolvedFile(Directory app, String name) {
  final file = File('${app.path}/$name');
  if (!file.existsSync()) {
    throw NativeBuildException(
      '${app.path} has no $name: run flutter pub get in it.',
    );
  }
  return file;
}

/// The lines of the plugins of [app] with native code for [platform], but
/// those of the Flutter SDK (see [nativeBuildOf]).
List<String> _pluginsOf(Directory app, String platform) {
  final lock = _resolvedFile(app, 'pubspec.lock');
  _resolvedFile(app, '.dart_tool/package_config.json');
  final dependencies = File('${app.path}/.flutter-plugins-dependencies');
  if (!dependencies.existsSync()) return const [];
  final plugins = switch (jsonDecode(dependencies.readAsStringSync())) {
    {'plugins': final Map<String, Object?> plugins} => plugins[platform],
    _ => null,
  };
  final packages = switch (loadYaml(lock.readAsStringSync())) {
    {'packages': final YamlMap packages} => packages,
    _ => YamlMap(),
  };
  return [
    for (final plugin in plugins is List ? plugins : const [])
      // A plugin with Dart code only for the platform builds nothing.
      if (plugin case {'name': final String name}
          when plugin['native_build'] != false)
        if (_pluginOf(app, packages, name) case final line?) line,
  ]..sort();
}

/// The line of the plugin [name] of [app], with its version from
/// [packages], the packages of its pubspec.lock, or `null` for a plugin of
/// the Flutter SDK.
String? _pluginOf(Directory app, YamlMap packages, String name) {
  final package = packages[name];
  if (package is! YamlMap) {
    throw NativeBuildException(
      'The pubspec.lock of ${app.path} has no version of $name, a plugin of '
      'its .flutter-plugins-dependencies: run flutter pub get in it.',
    );
  }
  final source = package['source'];
  if (source == 'sdk') return null;
  final commit = switch (package['description']) {
    {'resolved-ref': final Object commit} when source == 'git' => ' $commit',
    _ => '',
  };
  return 'plugin $name ${package['version']} ($source$commit)';
}

/// A line of a Gradle file that sets an id of the app, which differs from
/// app to app while the downloads stay the same.
final _setsId = RegExp(r'^\s*(?:namespace|applicationId)\b');

/// The lines of the Gradle files of the Android project of [app] (see
/// [nativeBuildOf]).
List<String> _gradleFilesOf(Directory app) {
  final android = Directory('${app.path}/android');
  if (!android.existsSync()) {
    throw NativeBuildException('${app.path} has no Android project, android/.');
  }
  final files = <String, File>{};
  void collect(Directory directory, String path) {
    for (final entity in directory.listSync(followLinks: false)) {
      final name = _nameOf(entity);
      if (entity is Directory && !name.startsWith('.') && name != 'build') {
        collect(entity, '$path$name/');
      } else if (entity is File && _isGradleFile(name)) {
        files['$path$name'] = entity;
      }
    }
  }

  collect(android, 'android/');
  return [
    for (final path in files.keys.toList()..sort()) ...[
      'file $path',
      for (final line in const LineSplitter().convert(
        files[path]!.readAsStringSync(),
      ))
        if (!_setsId.hasMatch(line)) '  $line',
    ],
  ];
}

/// Whether the file [name] of an Android project is a Gradle file that
/// decides what Gradle downloads: a build script or a settings script, of
/// Groovy or Kotlin, a version catalog, the properties of Gradle, or those
/// of its wrapper, which name the version of Gradle. The properties of the
/// machine, local.properties, are none.
bool _isGradleFile(String name) =>
    name.endsWith('.gradle') ||
    name.endsWith('.gradle.kts') ||
    name.endsWith('.toml') ||
    name == 'gradle.properties' ||
    name == 'gradle-wrapper.properties';

/// The lines of the Swift packages that the Xcode projects of the iOS
/// project of [app] refer to themselves (see [nativeBuildOf]).
List<String> _swiftPackagesOf(Directory app) {
  final ios = Directory('${app.path}/ios');
  final projects = {
    if (ios.existsSync())
      for (final entity in ios.listSync())
        if (entity is Directory && _nameOf(entity).endsWith('.xcodeproj'))
          if (File('${entity.path}/project.pbxproj') case final file
              when file.existsSync())
            'ios/${_nameOf(entity)}/project.pbxproj': file,
  };
  if (projects.isEmpty) {
    throw NativeBuildException(
      '${app.path} has no Xcode project, ios/<name>.xcodeproj.',
    );
  }
  return [
    for (final path in projects.keys.toList()..sort())
      if (_remoteSwiftPackages(projects[path]!.readAsStringSync())
          case final lines when lines.isNotEmpty) ...[
        'file $path: remote Swift packages',
        for (final line in lines) '  $line',
      ],
  ];
}

/// The lines of the XCRemoteSwiftPackageReference section of [project], the
/// text of an Xcode project, trimmed, or none when it has no such section.
List<String> _remoteSwiftPackages(String project) {
  final lines = const LineSplitter().convert(project);
  final begin = lines.indexWhere(
    (line) => line.contains('Begin XCRemoteSwiftPackageReference section'),
  );
  final end = lines.indexWhere(
    (line) => line.contains('End XCRemoteSwiftPackageReference section'),
    begin + 1,
  );
  return begin < 0 || end < 0
      ? const []
      : [
          for (final line in lines.sublist(begin + 1, end))
            if (line.trim().isNotEmpty) line.trim(),
        ];
}

void main(List<String> arguments) {
  if (arguments.length != 3 ||
      !platforms.contains(arguments[0]) ||
      !Directory(arguments[1]).existsSync()) {
    stderr.writeln(
      'Usage: dart tools/native_build.dart <${platforms.join('|')}> '
      '<directory of apps> <file>',
    );
    exitCode = 64;
    return;
  }
  final [platform, directory, path] = arguments;
  final Map<String, String> builds;
  try {
    builds = nativeBuildsOf(Directory(directory), platform);
  } on NativeBuildException catch (error) {
    stderr.writeln('::error::$error');
    exitCode = 1;
    return;
  }
  // The apps of each build, in the order of their first app.
  final apps = <String, List<String>>{};
  for (final MapEntry(key: app, value: build) in builds.entries) {
    (apps[build] ??= []).add(app);
  }
  for (final MapEntry(key: build, value: names) in apps.entries) {
    stdout
      ..writeln(
        'What ${names.join(', ')} build${names.length == 1 ? 's' : ''} '
        'with for $platform:',
      )
      ..writeln(
        build.isEmpty
            ? '  no plugin with native code, and nothing else to download'
            : build,
      );
  }
  final file = File(path);
  if (apps.keys.every((build) => build.isEmpty)) {
    if (file.existsSync()) file.deleteSync();
    stdout
        .writeln('The apps download nothing for $platform: no file at $path.');
    return;
  }
  file
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(nativeBuildFileOf(builds.values));
  stdout.writeln('Wrote what the apps build with to $path.');
}
