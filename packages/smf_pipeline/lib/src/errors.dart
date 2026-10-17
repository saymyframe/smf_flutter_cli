import 'package:smf_contracts/core.dart';

/// Thrown when generation cannot continue; the CLI exits with code 1.
///
/// Problems the user caused with the command line are [SmfUsageException]s
/// instead, and exit with code 64.
final class GenerationFailedException implements Exception {
  /// Creates the failure described by [message], with the [issues] that
  /// caused it.
  const GenerationFailedException(this.message, {this.issues = const []});

  /// What failed, as a complete sentence.
  final String message;

  /// The problems that stopped generation, if checks found them.
  final List<SmfIssue> issues;

  @override
  String toString() => [
        'GenerationFailedException: $message',
        for (final issue in issues) '  $issue',
      ].join('\n');
}

/// Thrown when the registry of modules breaks the rules of the module model,
/// which is a bug in the modules or the CLI, not in the user's input.
final class RegistryException implements Exception {
  /// Creates the exception with the [problems] found.
  const RegistryException(this.problems);

  /// What is wrong with the registry, as complete sentences.
  final List<String> problems;

  @override
  String toString() => [
        'RegistryException: the registry of modules is invalid.',
        for (final problem in problems) '  $problem',
      ].join('\n');
}

/// [issue] as a line for a logger that marks its severity itself, such as
/// `[WARN]`: [SmfIssue.toString] without the severity, such as
/// `[firebase_core]: Firebase login is missing. …`.
String issueLine(SmfIssue issue) {
  final about = [
    if (issue.origin case final origin?) '[$origin]',
    if (issue.path case final path?) path,
  ].join(' ');
  final hint = issue.hint;
  return '${about.isEmpty ? '' : '$about: '}${issue.message}'
      '${hint == null ? '' : ' ($hint)'}';
}

/// The code of the warnings of the pipeline about an option of a role that
/// the app lacks, which nothing reads.
const unusedOptionWarning = 'pipeline.unused_option';

/// [issue], which [who], a hook or a rule of [role] with the [origin],
/// reported, with [origin] if it names no origin itself; or an error of
/// [origin] if [who] may not report it.
///
/// It may report an error, and a warning about what the app is made of
/// with a code of [role], `<role id>.<name>` (see [SmfIssue.code]). A code
/// says which role reported a warning, so a code of another role or of
/// another form is a bug of [origin]. So is a warning about the machine,
/// which only the preflight checks of the pipeline report.
SmfIssue reportedBy(
  SmfIssue issue, {
  required Role role,
  required String who,
  required ContributionOrigin origin,
}) {
  final ownOrigin = issue.origin ?? origin;
  switch (issue.category) {
    case null:
      return SmfIssue(
        issue.message,
        hint: issue.hint,
        origin: ownOrigin,
        path: issue.path,
      );
    case WarningCategory.machine:
      return SmfIssue(
        '$who reported a warning about the machine, which only the '
        'preflight checks of the pipeline report: ${issue.message}',
        hint: 'Report a warning about what the app is made of, with a code '
            'of the $role.',
        origin: origin,
      );
    case WarningCategory.composition:
      final code = issue.code!;
      if (!SmfIssue.isWarningCode(code) || !code.startsWith('${role.id}.')) {
        return SmfIssue(
          '$who reported a warning with the code "$code", which is not a '
          'code of the $role: ${issue.message}',
          hint: 'A code of the $role is ${role.id}.<name>, with a name in '
              'lower snake_case.',
          origin: origin,
        );
      }
      return SmfIssue.warning(
        issue.message,
        code: code,
        hint: issue.hint,
        origin: ownOrigin,
        path: issue.path,
      );
  }
}
