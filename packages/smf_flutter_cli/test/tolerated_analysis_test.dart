import 'package:smf_flutter_cli/matrix.dart';
import 'package:test/test.dart';

/// What Flutter 3.50 reports of an app that imports its material library,
/// and of the code that its gen-l10n writes, as `flutter analyze` writes it.
const _material = "   info • 'package:flutter/material.dart' is deprecated "
    "and shouldn't be used. Use package:material_ui/material_ui.dart "
    'instead. This feature was deprecated after v3.47.0-0.0.pre. Try '
    'replacing the use of the deprecated member with the replacement • '
    'lib/app.dart:6:1 • deprecated_member_use';
const _localizations = "   info • 'GlobalCupertinoLocalizations' is "
    "deprecated and shouldn't be used. Use GlobalCupertinoLocalizations from "
    'package:cupertino_ui/cupertino_ui.dart instead. This feature was '
    'deprecated after v3.47.0-0.0.pre. Try replacing the use of the '
    'deprecated member with the replacement • '
    'lib/l10n/app_localizations.dart:91:9 • deprecated_member_use';

/// The same as `dart analyze` writes it, where the matrix analyzes an app
/// in a directory whose path has letters beyond ASCII.
const _materialOfDart = '  info - lib/app.dart:6:1 - '
    "'package:flutter/material.dart' is deprecated and shouldn't be used. "
    'Use package:material_ui/material_ui.dart instead. This feature was '
    'deprecated after v3.47.0-0.0.pre. Try replacing the use of the '
    'deprecated member with the replacement - deprecated_member_use';

/// The output of an analysis with [issues] and the count of [found].
String _output(List<String> issues, {int? found}) {
  final count = found ?? issues.length;
  final noun = count == 1 ? 'issue' : 'issues';
  return [
    'Analyzing app_1...',
    '',
    ...issues,
    '',
    '$count $noun found. (ran in 1.8s)',
  ].join('\n');
}

/// Another deprecation, which no package of Flutter 3.50 replaces.
const _otherDeprecation = "   info • 'oldName' is deprecated and shouldn't "
    'be used. Use newName instead • lib/main.dart:3:1 • deprecated_member_use';

/// The replacement of the material library, with another code.
const _otherCode = '   info • Use package:material_ui/material_ui.dart • '
    'lib/main.dart:3:1 • prefer_const_constructors';

/// A warning, such as the second import of the new library that dart fix
/// of Flutter 3.50 writes.
const _warning = '   warning • Duplicate import of '
    'package:material_ui/material_ui.dart • lib/app.dart:8:8 • '
    'duplicate_import';

/// An error that names the replacement.
const _error = "   error • 'package:flutter/material.dart' is deprecated. "
    'Use package:material_ui/material_ui.dart • lib/app.dart:6:1 • '
    'deprecated_member_use';

void main() {
  group('toleratingAnalysis', () {
    test(
        'passes an app whose only issues are the infos of Flutter 3.50 that '
        'its material and cupertino libraries are deprecated', () {
      final output = _output([_material, _localizations]);

      final (code, text) = toleratingAnalysis((1, output));

      expect(code, 0);
      expect(text, startsWith(output));
      expect(
        text,
        contains(
          'The analyzer found only 2 infos of Flutter 3.50 that its '
          'material and cupertino libraries are deprecated',
        ),
      );
    });

    test('reads the issues of dart analyze too', () {
      final output = _output([_materialOfDart]);

      expect(toleratingAnalysis((3, output)).$1, 0);
    });

    test('keeps the failure of any other issue', () {
      for (final other in [_otherDeprecation, _otherCode, _warning, _error]) {
        final result = (1, _output([_material, other]));

        expect(toleratingAnalysis(result), result, reason: other);
      }
    });

    test('keeps the failure of an output that it cannot read in full', () {
      for (final output in [
        // More issues found than lines of issues.
        _output([_material], found: 2),
        // No count.
        _material,
        // No issue at all, as when the analyzer itself fails.
        'Oops: the analysis server crashed.',
      ]) {
        final result = (1, output);

        expect(toleratingAnalysis(result), result, reason: output);
      }
    });

    test('leaves an analysis that passed as it is', () {
      const result = (0, 'No issues found!');

      expect(toleratingAnalysis(result), result);
    });
  });

  test('isToleratedAnalysisIssue takes only the infos of the two packages', () {
    expect(
      isToleratedAnalysisIssue(
        'info',
        'Use package:cupertino_ui/cupertino_ui.dart instead',
        'deprecated_member_use',
      ),
      isTrue,
    );
    expect(
      isToleratedAnalysisIssue(
        'info',
        'Use package:other/other.dart instead',
        'deprecated_member_use',
      ),
      isFalse,
    );
  });
}
