import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:yaml/yaml.dart';

/// A stand-in for the library of in_app_review that the module uses, with
/// the signatures of in_app_review 2.0.12: the store of a device in memory,
/// which a script reads and scripts. `reviewCalls` has each call, a script
/// sets whether the store can show its dialog, and `failNextReview` makes
/// the next call throw what the platform throws.
const _inAppReview = '''
/// The calls of the package, in their order.
final List<String> reviewCalls = [];

/// Whether the store of the device can show its review dialog.
bool storeAvailable = true;

/// What the next call of the package throws, if anything.
Object? failNextReview;

Future<void> _call(String method) async {
  reviewCalls.add(method);
  final error = failNextReview;
  failNextReview = null;
  if (error != null) throw error;
}

class InAppReview {
  InAppReview._();

  static final InAppReview instance = InAppReview._();

  Future<bool> isAvailable() async {
    await _call('isAvailable');
    return storeAvailable;
  }

  Future<void> requestReview() => _call('requestReview');

  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) =>
      _call('openStoreListing');
}
''';

/// A stand-in for the library of url_launcher that the module uses, with the
/// signatures of url_launcher 6.3: `launched` has each link that opened, with
/// its mode, and a script sets what the platform answers.
const _urlLauncher = r'''
enum LaunchMode {
  platformDefault,
  inAppWebView,
  inAppBrowserView,
  externalApplication,
  externalNonBrowserApplication,
}

/// The links that the app opened, each as `<link> <mode>`.
final List<String> launched = [];

/// Whether an app of the device opens a link.
bool linkOpens = true;

/// What the next launch throws, if anything.
Object? failNextLaunch;

Future<bool> launchUrl(
  Uri url, {
  LaunchMode mode = LaunchMode.platformDefault,
  String? webOnlyWindowName,
}) async {
  launched.add('$url ${mode.name}');
  final error = failNextLaunch;
  failNextLaunch = null;
  if (error != null) throw error;
  return linkOpens;
}
''';

/// A stand-in for the library of package_info_plus that the module uses,
/// with the signatures of package_info_plus 10.2: a script sets the version
/// of the app, or what reading it throws.
const _packageInfo = '''
/// The version of the app that the platform gives.
String appVersionOfPlatform = '1.0.0';

/// What reading the information of the app throws, if anything.
Object? failPackageInfo;

class PackageInfo {
  PackageInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    this.buildSignature = '',
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String buildSignature;

  static Future<PackageInfo> fromPlatform({String? baseUrl}) async {
    final error = failPackageInfo;
    if (error != null) throw error;
    return PackageInfo(
      appName: 'contract_app',
      packageName: 'com.example.contract_app',
      version: appVersionOfPlatform,
      buildNumber: '1',
    );
  }
}
''';

/// The Dart files in `lib/` of a rendered app, written to a temporary
/// directory with stand-ins for the libraries of in_app_review, of
/// url_launcher and of package_info_plus that the code of the module uses,
/// so that it can be analyzed and run with the Dart SDK alone: the tests of
/// the package run without the Flutter SDK, which those packages need.
///
/// The other files of the app need Flutter, so the analyzer checks the files
/// of the owners it is given, and a script that runs the app imports none of
/// the others. The real packages run in the tests of the generated apps.
/// [delete] removes the directory.
final class DartApp {
  DartApp._(this._root, this._files);

  /// Writes the Dart files in `lib/` of [app].
  factory DartApp.write(RenderedApp app) {
    final root = Directory.systemTemp.createTempSync('smf_in_app_review_');
    final files = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') && file.path.endsWith('.dart')) file,
    ];
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    for (final file in files) {
      write('app/${file.path}', file.text);
    }
    write('in_app_review/lib/in_app_review.dart', _inAppReview);
    write('url_launcher/lib/url_launcher.dart', _urlLauncher);
    write('package_info_plus/lib/package_info_plus.dart', _packageInfo);
    write('app/pubspec.yaml', 'name: contract_app\n');
    // The stand-ins are in the language of the app too.
    final languageVersion = _languageVersionOf(app);
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('in_app_review', '../../in_app_review/'),
            ('url_launcher', '../../url_launcher/'),
            ('package_info_plus', '../../package_info_plus/'),
          ])
            {
              'name': name,
              'rootUri': rootUri,
              'packageUri': 'lib/',
              'languageVersion': languageVersion,
            },
        ],
      }),
    );
    return DartApp._(root, files);
  }

  final Directory _root;
  final List<RenderedFile> _files;

  String get _appPath =>
      Directory('${_root.path}/app').resolveSymbolicLinksSync();

  /// The errors and warnings that the analyzer finds in the files of
  /// [owners], each with the path of its file.
  Future<List<String>> analysisProblems(Set<ContributionOrigin> owners) async {
    final appPath = _appPath;
    final collection = AnalysisContextCollection(includedPaths: [appPath]);
    try {
      final problems = <String>[];
      for (final file in _files) {
        if (!owners.contains(file.owner)) continue;
        // The analyzer takes only the paths of the system, such as
        // C:\app\lib\main.dart on Windows.
        final path = Uri.directory(appPath).resolve(file.path).toFilePath();
        final result = await collection
            .contextFor(path)
            .currentSession
            .getResolvedUnit(path);
        if (result is! ResolvedUnitResult) {
          problems.add('${file.path}: cannot be resolved: $result');
          continue;
        }
        for (final diagnostic in result.diagnostics) {
          if (diagnostic.severity == Severity.info) continue;
          problems.add(
            '${file.path}:${result.lineInfo.getLocation(diagnostic.offset)}: '
            '${diagnostic.message}',
          );
        }
      }
      return problems;
    } finally {
      await collection.dispose();
    }
  }

  /// Runs [script], a Dart library whose `main(List<String>, SendPort)`
  /// imports the app by its package, `contract_app`, in an isolate of its
  /// own, and returns the first message it sends.
  ///
  /// Throws a [StateError] with the error if the isolate fails, or if it
  /// sends nothing in time.
  Future<Object?> run(String script) async {
    final file = File('${_root.path}/check.dart')..writeAsStringSync(script);
    final result = Completer<Object?>();
    void fail(String message) {
      if (!result.isCompleted) result.completeError(StateError(message));
    }

    final messages = ReceivePort()
      ..listen((message) {
        if (!result.isCompleted) result.complete(message);
      });
    final errors = ReceivePort()
      ..listen((error) => fail('The script failed: $error'));
    // The isolate sends its message before it ends, so an end that comes
    // first means that it sent none.
    final exits = ReceivePort()
      ..listen((_) => fail('The script ended without a message.'));
    Isolate? isolate;
    try {
      isolate = await Isolate.spawnUri(
        file.uri,
        const [],
        messages.sendPort,
        onError: errors.sendPort,
        onExit: exits.sendPort,
        packageConfig: Uri.file('$_appPath/.dart_tool/package_config.json'),
      );
      return await result.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw StateError('The script sent nothing in time.'),
      );
    } finally {
      isolate?.kill(priority: Isolate.immediate);
      messages.close();
      errors.close();
      exits.close();
    }
  }

  /// Deletes the directory of the app.
  void delete() => _root.deleteSync(recursive: true);
}

/// The language version of [app]: that of the lower bound of the SDK
/// constraint of its pubspec, such as 3.12 for `^3.12.0`.
String _languageVersionOf(RenderedApp app) {
  final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
  final sdk = (pubspec['environment'] as YamlMap)['sdk'] as String;
  final version = RegExp(r'(\d+)\.(\d+)').firstMatch(sdk)!;
  return '${version[1]}.${version[2]}';
}
