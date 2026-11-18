import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// Stand-ins of Flutter's libraries with the deprecations of Flutter 3.50.
const _standIns = {
  'flutter/lib/material.dart': '''
@Deprecated('Use package:material_ui/material_ui.dart instead.')
library;

class Icons {
  static const int home = 0;
}
''',
  'flutter/lib/cupertino.dart': '''
@Deprecated('Use package:cupertino_ui/cupertino_ui.dart instead.')
library;

class CupertinoPageTransitionsBuilder {}
''',
  'flutter/lib/widgets.dart': 'class Widget {}\n',
  'flutter_localizations/lib/flutter_localizations.dart': '''
@Deprecated('Use GlobalMaterialLocalizations of material_ui instead.')
abstract class GlobalMaterialLocalizations {
  static const Object delegate = 0;
}

@Deprecated('Use GlobalCupertinoLocalizations of cupertino_ui instead.')
abstract class GlobalCupertinoLocalizations {
  static const Object delegate = 0;
}

abstract class GlobalWidgetsLocalizations {
  static const Object delegate = 0;
}
''',
};

/// Files of an app, each with what Flutter 3.50 deprecates, ignored or not.
const _files = {
  // Ignored on the line above, with a reason, and on the same line.
  'lib/above.dart': '''
// ignore: deprecated_member_use (Flutter 3.50 deprecates it)
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // ignore: deprecated_member_use

const a = Icons.home;
''',
  // An import between the ignore and the import of material, and an
  // ignore after a trailing comment that wraps the directive.
  'lib/split.dart': '''
// ignore: deprecated_member_use
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoPageTransitionsBuilder; // ignore: deprecated_member_use

const a = Icons.home;
''',
  // Names of the localizations, ignored or not, with the code among others
  // and after text that ends the list of codes.
  'lib/names.dart': '''
import 'package:flutter_localizations/flutter_localizations.dart' as l10n;

const delegates = [
  // ignore: unused_element, deprecated_member_use
  l10n.GlobalMaterialLocalizations.delegate,
  // ignore: unused_element because of deprecated_member_use
  l10n.GlobalCupertinoLocalizations.delegate,
  l10n.GlobalWidgetsLocalizations.delegate,
];
''',
  // Ignored for the whole file.
  'test/whole_file_test.dart': '''
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

const a = Icons.home;
''',
  // A library directive, a comment that ignores nothing and an ignore of
  // a type of diagnostics rather than of a code.
  'lib/plain.dart': '''
library;

// The icons of the app.
import 'package:flutter/material.dart' show Icons;
// ignore: type=lint
export 'package:flutter/cupertino.dart';

const a = Icons.home;
''',
};

/// What the analyzer reports as `deprecated_member_use` in [files], resolved
/// against [_standIns], each as `<path>:<line>`.
Future<List<String>> _analyzerReports(Map<String, String> files) async {
  final root = Directory.systemTemp.createTempSync('smf_deprecations_');
  try {
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    for (final MapEntry(key: path, value: text) in _standIns.entries) {
      write(path, text);
    }
    for (final MapEntry(key: path, value: text) in files.entries) {
      write('app/$path', text);
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
      final reports = <String>[];
      for (final path in files.keys.toList()..sort()) {
        final file = Uri.directory(appPath).resolve(path).toFilePath();
        final result = await collection
            .contextFor(file)
            .currentSession
            .getResolvedUnit(file) as ResolvedUnitResult;
        for (final diagnostic in result.diagnostics) {
          if (diagnostic.diagnosticCode.lowerCaseName !=
              'deprecated_member_use') {
            continue;
          }
          final line = result.lineInfo.getLocation(diagnostic.offset);
          reports.add('$path:${line.lineNumber}');
        }
      }
      return reports;
    } finally {
      await collection.dispose();
    }
  } finally {
    root.deleteSync(recursive: true);
  }
}

RenderedApp _app(Map<String, String> files) => RenderedApp([
      for (final MapEntry(key: path, value: text) in files.entries)
        RenderedFile(
          path: path,
          bytes: utf8.encode(text),
          owner: const ModuleOrigin(ModuleId('acme')),
        ),
    ]);

/// A problem of [flutterDeprecationProblems] at [place], of [what].
String _problem(String place, String what) =>
    '$place: $what, has no // ignore: deprecated_member_use on its line or '
    'the line above';

void main() {
  test(
      'finds what the analyzer reports as deprecated_member_use of the '
      'libraries of Flutter 3.50, where an ignore does not cover it', () async {
    final problems = flutterDeprecationProblems(_app(_files));

    expect(
      problems.map((problem) => problem.split(': ').first),
      await _analyzerReports(_files),
    );
    const material = 'package:flutter/material.dart';
    const cupertino = 'package:flutter/cupertino.dart';
    expect(problems, [
      _problem(
        'lib/names.dart:7',
        'GlobalCupertinoLocalizations, in a file of acme',
      ),
      _problem(
        'lib/plain.dart:4',
        'the import of $material, of the template of acme',
      ),
      _problem(
        'lib/plain.dart:6',
        'the export of $cupertino, of the template of acme',
      ),
      _problem(
        'lib/split.dart:3',
        'the import of $material, of the template of acme',
      ),
      _problem(
        'lib/split.dart:4',
        'the import of $cupertino, of the template of acme',
      ),
    ]);
  });

  test(
      'names the contributor of an import that the pipeline added, and the '
      'owner of a file that a render hook wrote', () {
    const import = "import 'package:flutter/material.dart';\n";
    final problems = flutterDeprecationProblems(
      RenderedApp([
        RenderedFile(
          path: 'lib/destination.dart',
          bytes: utf8.encode('$import\nconst icon = Icons.home;\n'),
          owner: const ModuleOrigin(ModuleId('acme')),
          addedImports: const [
            AddedImport(
              ImportRef('package:flutter/widgets.dart'),
              ModuleOrigin(ModuleId('settings')),
            ),
            AddedImport(
              ImportRef('package:flutter/material.dart'),
              ModuleOrigin(ModuleId('home')),
            ),
          ],
        ),
        RenderedFile(
          path: 'lib/hooked.dart',
          bytes: utf8.encode(import),
          owner: const ModuleOrigin(ModuleId('clock')),
          fromHook: true,
        ),
        // Only Dart files count.
        RenderedFile(
          path: 'README.md',
          bytes: utf8.encode(import),
          owner: const ModuleOrigin(ModuleId('acme')),
        ),
      ]),
    );

    expect(problems, [
      _problem(
        'lib/destination.dart:1',
        'the import of package:flutter/material.dart, which the pipeline '
            'added for a fragment of home',
      ),
      _problem(
        'lib/hooked.dart:1',
        'the import of package:flutter/material.dart, which a render hook '
            'of clock wrote',
      ),
    ]);
  });
}
