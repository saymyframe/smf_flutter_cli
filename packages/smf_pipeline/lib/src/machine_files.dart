import 'package:smf_pipeline/src/move.dart';

/// Why a brick may not generate the file at [path], a path relative to the
/// root of the app with forward slashes, or `null` if it may.
///
/// Some files belong to one machine, one build or one app, not to every app
/// a brick generates: the files that Flutter's tools write with the path of
/// the app (see [flutterToolFiles]), the outputs of builds, the signing keys
/// of an app, and the files that an IDE, Xcode, CocoaPods, pub or the
/// operating system leave behind. A brick with such a file was most likely
/// copied from an app that had been built.
///
/// The answer completes "The brick generates [path], which …".
String? machineFileProblem(String path) {
  for (final tool in flutterToolFiles) {
    if (path == tool || path.startsWith('$tool/')) {
      return "is written by Flutter's tools, which the pipeline does not move "
          'with the app';
    }
  }
  if (_paths[path] case final problem?) return problem;
  final segments = path.split('/');
  final name = segments.last;
  if (_names[name] case final problem?) return problem;
  if (name.endsWith('.jks') || name.endsWith('.keystore')) return _signing;
  if (name.endsWith('.iml')) return _ide;
  if (name.startsWith('GeneratedPluginRegistrant.') ||
      name == 'generated_plugin_registrant.dart') {
    return 'is written by Flutter for the plugins of the app';
  }
  final directories = segments.sublist(0, segments.length - 1);
  for (final directory in directories) {
    if (_directories[directory] case final problem?) return problem;
  }
  // The native projects build into a directory named build; elsewhere, as
  // in lib/ or assets/, it may be a part of the app.
  if (directories.contains('build') &&
      const {'android', 'ios', 'macos', 'linux', 'windows', 'web'}
          .contains(segments.first)) {
    return _build;
  }
  return null;
}

const _build = 'is the output of a build, not a part of the app';

const _pods = 'is written when the pods of the app are installed';

const _signing = 'holds the signing keys of one app, which no other app may '
    'share';

const _ide = 'holds the settings of an IDE on one machine';

/// The problems of files at a path relative to the root of the app.
const Map<String, String> _paths = {
  'ios/Flutter/.last_build_id': _build,
  'ios/Flutter/Flutter.podspec': _build,
};

/// The problems of files by their name.
const Map<String, String> _names = {
  '.DS_Store': 'is left behind by the operating system',
  'Thumbs.db': 'is left behind by the operating system',
  'local.properties': 'holds the paths of the SDKs of one machine',
  'key.properties': _signing,
  'pubspec.lock': 'is written by pub when it gets the packages of the app',
  'Podfile.lock': _pods,
};

/// The problems of files by the name of a directory they are in.
const Map<String, String> _directories = {
  '.dart_tool': _build,
  '.gradle': _build,
  '.cxx': _build,
  'DerivedData': _build,
  '.swiftpm': _build,
  'App.framework': _build,
  'Flutter.framework': _build,
  'Pods': _pods,
  '.symlinks': _pods,
  'xcuserdata': 'holds the Xcode settings of one user',
  '.idea': _ide,
};
