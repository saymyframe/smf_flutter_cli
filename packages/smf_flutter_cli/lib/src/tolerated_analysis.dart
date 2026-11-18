/// The issues of `flutter analyze` and `dart analyze` that the matrix lets
/// pass for now.
library;

/// A line of an issue that `flutter analyze` (`info • message • place •
/// code`) or `dart analyze` (`info - place - message - code`) writes: its
/// severity, what is between, and its code.
final _issue = RegExp(
  r'^\s*(error|warning|info) (?:•|-) (.*) (?:•|-) ([a-z0-9_]+)\s*$',
  multiLine: true,
);

/// The line with which both write how many issues they found.
final _count = RegExp(r'^\s*(\d+) issues? found\.', multiLine: true);

/// The replacements that Flutter 3.50 names for its material and cupertino
/// libraries and for the localizations of them, which it deprecates.
const _replacements = ['package:material_ui/', 'package:cupertino_ui/'];

/// Whether an issue with [severity], [text] and [code] is one that the
/// matrix lets pass: an info that Flutter 3.50 deprecates
/// `package:flutter/material.dart`, `package:flutter/cupertino.dart`, or a
/// name of them or of `flutter_localizations`, for `package:material_ui` or
/// `package:cupertino_ui`.
///
/// The apps keep the material library of Flutter, which their root is of,
/// and the code that SMF generates ignores those deprecations, as does the
/// header that gen_l10n gives the code that gen-l10n writes. So these infos
/// come from the files of the app tests, which import the library without
/// the ignore, and from an app of a published release of the CLI that
/// does not ignore them yet.
bool isToleratedAnalysisIssue(String severity, String text, String code) =>
    severity == 'info' &&
    code == 'deprecated_member_use' &&
    _replacements.any(text.contains);

/// The [result] of `flutter analyze` or `dart analyze --fatal-infos` in an
/// app, its exit code and its output, with the exit code 0 when the
/// analyzer reported only issues that the matrix lets pass
/// ([isToleratedAnalysisIssue]), and a line that says so after the output.
/// Any other result stays as it is: a failure for any other issue, and one
/// whose output the matrix cannot read in full, where the number of issues
/// found differs from the number of the lines of issues.
(int, String) toleratingAnalysis((int, String) result) {
  final (code, output) = result;
  if (code == 0) return result;
  final issues = _issue.allMatches(output).toList();
  final found = _count.firstMatch(output)?[1];
  if (issues.isEmpty ||
      found == null ||
      int.parse(found) != issues.length ||
      !issues.every(
        (issue) => isToleratedAnalysisIssue(issue[1]!, issue[2]!, issue[3]!),
      )) {
    return result;
  }
  final infos = issues.length == 1 ? '1 info' : '${issues.length} infos';
  return (
    0,
    '$output\nThe analyzer found only $infos of Flutter 3.50 that its '
        'material and cupertino libraries are deprecated for '
        'package:material_ui and package:cupertino_ui, which the matrix lets '
        'pass while the apps allow Flutter 3.44.\n',
  );
}
