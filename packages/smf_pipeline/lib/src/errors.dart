import 'package:smf_contracts/lego_core.dart';

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

/// Thrown when the registry of modules breaks the rules of the lego model,
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

/// Returns [issue] with [origin] if it names no origin itself.
SmfIssue issueWithOrigin(SmfIssue issue, ContributionOrigin origin) {
  if (issue.origin != null) return issue;
  return issue.isError
      ? SmfIssue(
          issue.message,
          hint: issue.hint,
          origin: origin,
          path: issue.path,
        )
      : SmfIssue.warning(
          issue.message,
          hint: issue.hint,
          origin: origin,
          path: issue.path,
        );
}
