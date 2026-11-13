import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:yaml/yaml.dart';

/// Stand-ins for the parts of Flutter's widgets library that the checked
/// files and the file of the localizations use, with the signatures of
/// Flutter 3.44.
const _widgets = '''
abstract interface class BuildContext {}

class Locale {
  const Locale(this.languageCode);

  final String languageCode;
}

abstract class LocalizationsDelegate<T> {
  const LocalizationsDelegate();
}
''';

/// Stand-ins for the delegates of flutter_localizations that the file of
/// the localizations names, with the deprecations of Flutter 3.50, which
/// deprecates the localizations of Material and Cupertino for those of
/// material_ui and cupertino_ui.
const _flutterLocalizations = '''
import 'package:flutter/widgets.dart';

@Deprecated(
  'Use GlobalMaterialLocalizations from package:material_ui/material_ui.dart instead. '
  'This feature was deprecated after v3.47.0-0.0.pre.',
)
abstract class GlobalMaterialLocalizations {
  static const LocalizationsDelegate<Object> delegate = _Delegate();
}

@Deprecated(
  'Use GlobalCupertinoLocalizations from package:cupertino_ui/cupertino_ui.dart instead. '
  'This feature was deprecated after v3.47.0-0.0.pre.',
)
abstract class GlobalCupertinoLocalizations {
  static const LocalizationsDelegate<Object> delegate = _Delegate();
}

abstract class GlobalWidgetsLocalizations {
  static const LocalizationsDelegate<Object> delegate = _Delegate();
}

class _Delegate extends LocalizationsDelegate<Object> {
  const _Delegate();
}
''';

/// The file that gen-l10n of Flutter 3.44 to 3.50 generates for [app], by
/// its path in the app, with what the files of the app use of it and the
/// delegates of flutter_localizations that it names: the class of the
/// localizations with the members that gen-l10n declares and a `String`
/// getter for each text of the template ARB file.
///
/// It follows the options of the `l10n.yaml` of [app], or [options] in
/// place of that file, as gen-l10n does: the file starts with `header`, is
/// `output-localization-file` in `arb-dir`, the texts are those of
/// `template-arb-file` there, and `of()` returns the localizations or
/// `null` unless `nullable-getter` is `false`.
({String path, String text}) generatedLocalizationsOf(
  RenderedApp app, {
  String? options,
}) {
  final yaml = loadYaml(options ?? app.files['l10n.yaml']!.text) as YamlMap;
  final directory = yaml['arb-dir'] as String;
  final template = jsonDecode(
    app.files['$directory/${yaml['template-arb-file']}']!.text,
  ) as Map<String, Object?>;
  final nullable = yaml['nullable-getter'] != false;
  final header = yaml['header'] as String? ?? '';
  return (
    path: '$directory/${yaml['output-localization-file']}',
    text: [
      // gen-l10n puts the header, as it is, before the first import.
      if (header.isNotEmpty) ...[header, ''],
      "import 'package:flutter/widgets.dart';",
      "import 'package:flutter_localizations/flutter_localizations.dart';",
      '',
      'abstract class AppLocalizations {',
      '  AppLocalizations(this.localeName);',
      '',
      '  final String localeName;',
      '',
      '  static AppLocalizations${nullable ? '?' : ''} of(',
      '    BuildContext context,',
      '  ) =>',
      '      throw UnimplementedError();',
      '',
      '  static const LocalizationsDelegate<AppLocalizations> delegate =',
      '      _AppLocalizationsDelegate();',
      '',
      '  static const List<LocalizationsDelegate<dynamic>>',
      '      localizationsDelegates = <LocalizationsDelegate<dynamic>>[',
      '    delegate,',
      '    GlobalMaterialLocalizations.delegate,',
      '    GlobalCupertinoLocalizations.delegate,',
      '    GlobalWidgetsLocalizations.delegate,',
      '  ];',
      '',
      '  static const List<Locale> supportedLocales = [];',
      for (final name in template.keys)
        if (!name.startsWith('@')) ...['', '  String get $name;'],
      '}',
      '',
      'class _AppLocalizationsDelegate',
      '    extends LocalizationsDelegate<AppLocalizations> {',
      '  const _AppLocalizationsDelegate();',
      '}',
      '',
    ].join('\n'),
  );
}

/// Resolves the Dart files in `lib/` of [app] that [owners] generated
/// against a stand-in of Flutter's widgets library and the file that
/// gen-l10n generates for the app (see [generatedLocalizationsOf]), and
/// returns the errors and warnings that the analyzer finds, each with the
/// path of its file.
///
/// It checks the types of the code with the Dart SDK alone, as the tests of
/// the package run without the Flutter SDK, which generates the real file
/// in the apps of the matrix.
Future<List<String>> analysisProblems(
  RenderedApp app,
  Set<ContributionOrigin> owners,
) =>
    _diagnosticsOf(
      app,
      checks: (owner) => owner != null && owners.contains(owner),
      infos: false,
    );

/// Resolves the file that gen-l10n generates for [app] (see
/// [generatedLocalizationsOf]), with [options] in place of the `l10n.yaml`
/// of [app] if given, against stand-ins of Flutter's widgets library and of
/// flutter_localizations with the deprecations of Flutter 3.50, and returns
/// what the analyzer reports there, infos included, each with its path and
/// its code, as `flutter analyze` reports the file in a new app.
Future<List<String>> generatedLocalizationsDiagnostics(
  RenderedApp app, {
  String? options,
}) =>
    _diagnosticsOf(
      app,
      checks: (owner) => owner == null,
      infos: true,
      options: options,
    );

/// Resolves the Dart files in `lib/` of [app] and the file that gen-l10n
/// generates for it with the `l10n.yaml` of [app], or [options] in its
/// place (see [generatedLocalizationsOf]), against stand-ins of Flutter's
/// widgets library and of flutter_localizations. Returns what the analyzer
/// reports in the files whose owners [checks] takes, `null` for the file of
/// gen-l10n, without the infos unless [infos].
Future<List<String>> _diagnosticsOf(
  RenderedApp app, {
  required bool Function(ContributionOrigin? owner) checks,
  required bool infos,
  String? options,
}) async {
  final root = Directory.systemTemp.createTempSync('smf_gen_l10n_');
  try {
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    write('flutter/lib/widgets.dart', _widgets);
    write(
      'flutter_localizations/lib/flutter_localizations.dart',
      _flutterLocalizations,
    );
    final generated = generatedLocalizationsOf(app, options: options);
    final dartFiles = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') && file.path.endsWith('.dart'))
          (path: file.path, text: file.text, owner: file.owner),
      (path: generated.path, text: generated.text, owner: null),
    ];
    for (final file in dartFiles) {
      write('app/${file.path}', file.text);
    }
    write('app/pubspec.yaml', 'name: contract_app\n');
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('flutter', '../../flutter/'),
            ('flutter_localizations', '../../flutter_localizations/'),
          ])
            {
              'name': name,
              'rootUri': rootUri,
              'packageUri': 'lib/',
              'languageVersion': '3.12',
            },
        ],
      }),
    );

    final appPath = Directory('${root.path}/app').resolveSymbolicLinksSync();
    final collection = AnalysisContextCollection(includedPaths: [appPath]);
    try {
      final problems = <String>[];
      for (final file in dartFiles) {
        if (!checks(file.owner)) continue;
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
          if (!infos && diagnostic.severity == Severity.info) continue;
          problems.add(
            '${file.path}:${result.lineInfo.getLocation(diagnostic.offset)}: '
            '${infos ? '${diagnostic.diagnosticCode.lowerCaseName}: ' : ''}'
            '${diagnostic.message}',
          );
        }
      }
      return problems;
    } finally {
      await collection.dispose();
    }
  } finally {
    root.deleteSync(recursive: true);
  }
}
