import 'package:smf_contracts/lego_core.dart';

/// How serious an [SmfIssue] is.
enum IssueSeverity {
  /// Generation cannot continue. In lenient mode the pipeline may drop the
  /// module at fault instead.
  error,

  /// Generation continues and the pipeline reports the issue.
  warning,
}

/// A problem found by a check: a validation hook of a role or provider, a
/// module rule, a structural rule, or the pipeline.
final class SmfIssue {
  /// Creates an error described by [message].
  const SmfIssue(this.message, {this.hint, this.origin, this.path})
      : severity = IssueSeverity.error;

  /// Creates a warning described by [message].
  const SmfIssue.warning(this.message, {this.hint, this.origin, this.path})
      : severity = IssueSeverity.warning;

  /// What is wrong, as a complete sentence.
  final String message;

  /// Whether generation can continue.
  final IssueSeverity severity;

  /// How to fix the problem, such as a "did you mean" suggestion.
  final String? hint;

  /// Who caused the problem, if known.
  ///
  /// In lenient mode the pipeline drops the module named here instead of
  /// failing.
  final ContributionOrigin? origin;

  /// The file of the generated app the problem is in, relative to the
  /// project root, if it is about a file.
  final String? path;

  /// Whether this issue stops generation.
  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() {
    final buffer = StringBuffer(isError ? 'error' : 'warning');
    if (origin != null) buffer.write(' [$origin]');
    if (path != null) buffer.write(' $path');
    buffer.write(': $message');
    if (hint != null) buffer.write(' ($hint)');
    return buffer.toString();
  }
}

/// Thrown by a role hook when the user's input cannot work, such as a
/// missing option in a non-interactive run.
///
/// The pipeline reports [message] as a usage error, and the CLI exits with
/// code 64.
final class SmfUsageException implements Exception {
  /// Creates a usage error described by [message].
  const SmfUsageException(this.message);

  /// What is wrong with the input and how to fix it.
  final String message;

  @override
  String toString() => 'SmfUsageException: $message';
}
