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

/// The file that gen-l10n of Flutter 3.44 generates for [app], by its path
/// in the app, with what the files of the app use of it: the class of the
/// localizations with the members that gen-l10n declares and a `String`
/// getter for each text of the template ARB file.
///
/// It follows the options of the `l10n.yaml` of [app] as gen-l10n does: the
/// file is `output-localization-file` in `arb-dir`, the texts are those of
/// `template-arb-file` there, and `of()` returns the localizations or
/// `null` unless `nullable-getter` is `false`.
({String path, String text}) generatedLocalizationsOf(RenderedApp app) {
  final options = loadYaml(app.files['l10n.yaml']!.text) as YamlMap;
  final directory = options['arb-dir'] as String;
  final template = jsonDecode(
    app.files['$directory/${options['template-arb-file']}']!.text,
  ) as Map<String, Object?>;
  final nullable = options['nullable-getter'] != false;
  return (
    path: '$directory/${options['output-localization-file']}',
    text: [
      "import 'package:flutter/widgets.dart';",
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
      '      localizationsDelegates = [delegate];',
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
) async {
  final root = Directory.systemTemp.createTempSync('smf_gen_l10n_');
  try {
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    write('flutter/lib/widgets.dart', _widgets);
    final dartFiles = [
      for (final file in app.files.values)
        if (file.path.startsWith('lib/') && file.path.endsWith('.dart')) file,
    ];
    for (final file in dartFiles) {
      write('app/${file.path}', file.text);
    }
    final generated = generatedLocalizationsOf(app);
    write('app/${generated.path}', generated.text);
    write('app/pubspec.yaml', 'name: contract_app\n');
    write(
      'app/.dart_tool/package_config.json',
      jsonEncode({
        'configVersion': 2,
        'packages': [
          for (final (name, rootUri) in [
            ('contract_app', '../'),
            ('flutter', '../../flutter/'),
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
  } finally {
    root.deleteSync(recursive: true);
  }
}
