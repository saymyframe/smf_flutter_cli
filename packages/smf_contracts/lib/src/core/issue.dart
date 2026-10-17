import 'package:smf_contracts/core.dart';

/// How serious an [SmfIssue] is.
enum IssueSeverity {
  /// Generation cannot continue. In lenient mode the pipeline may drop the
  /// module at fault instead.
  error,

  /// Generation continues and the pipeline reports the issue.
  warning,
}

/// What a warning is about.
enum WarningCategory {
  /// What the app is made of, such as a destination that no main navigation
  /// leads to. Such a warning has a code (see [SmfIssue.code]).
  composition,

  /// The machine that generates the app, such as a missing tool that a
  /// module needs only for a step after generation. Only the preflight
  /// checks of the pipeline report such a warning.
  machine,
}

/// A problem found by a check: a validation hook of a role or provider, a
/// module rule, a structural rule, a choice of a role, or the pipeline.
final class SmfIssue {
  /// Creates an error described by [message].
  const SmfIssue(this.message, {this.hint, this.origin, this.path})
      : category = null,
        code = null;

  /// Creates a warning about what the app is made of, described by
  /// [message], with its [code].
  ///
  /// The code is a constant of the role whose hook or rule reports the
  /// warning, such as `RouterRole.noStartWarning`; see [code].
  const SmfIssue.warning(
    this.message, {
    required String this.code,
    this.hint,
    this.origin,
    this.path,
  }) : category = WarningCategory.composition;

  /// Creates a warning about the machine described by [message], such as a
  /// tool that a check of the pipeline found missing.
  ///
  /// Only the preflight checks of the pipeline report such a warning: the
  /// pipeline refuses one from a hook or a rule of a role, which check what
  /// the app is made of.
  const SmfIssue.machineWarning(
    this.message, {
    this.hint,
    this.origin,
    this.path,
  })  : category = WarningCategory.machine,
        code = null;

  /// What is wrong, as a complete sentence.
  final String message;

  /// What the warning is about, or `null` for an error.
  final WarningCategory? category;

  /// The code of a warning about what the app is made of, such as
  /// `router.no_start`, or `null` for an error and a warning about the
  /// machine.
  ///
  /// It is the id of the role that reports the warning, a dot and a name
  /// in lower snake_case, so that a code says which role reported it and
  /// two roles never report the same code (see [isWarningCode]). The
  /// pipeline keeps the codes that start with `pipeline.` for its own
  /// warnings, such as an option of a role that the app lacks. A role
  /// publishes each code as a constant, so that a test or a tool names a
  /// warning by its code rather than by its message, which may change.
  final String? code;

  /// How to fix the problem, such as a "did you mean" suggestion.
  final String? hint;

  /// Who caused the problem, if known.
  ///
  /// In lenient mode the pipeline drops the module named here instead of
  /// failing, unless no app can be made without the module.
  final ContributionOrigin? origin;

  /// The file of the generated app the problem is in, relative to the
  /// project root, if it is about a file.
  final String? path;

  /// Whether generation can continue.
  IssueSeverity get severity =>
      category == null ? IssueSeverity.error : IssueSeverity.warning;

  /// Whether this issue stops generation.
  bool get isError => category == null;

  /// Whether [code] has the form of a code of a warning about what the app
  /// is made of: two names in lower snake_case with a dot between them,
  /// such as `router.no_start` (see [code]).
  static bool isWarningCode(String code) {
    final dot = code.indexOf('.');
    return dot > 0 &&
        SmfNames.isSnakeCase(code.substring(0, dot)) &&
        SmfNames.isSnakeCase(code.substring(dot + 1));
  }

  @override
  String toString() {
    final buffer = StringBuffer(isError ? 'error' : 'warning');
    if (origin != null) buffer.write(' [$origin]');
    if (code != null) buffer.write(' $code');
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
