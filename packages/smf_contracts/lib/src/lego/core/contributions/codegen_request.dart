part of '../contributions.dart';

/// A request to run code generation in the generated app.
///
/// However many modules request it, the pipeline runs
/// `dart run build_runner build` once, after `flutter pub get`, and adds
/// `build_runner` to the dev dependencies itself. Since version 2.7,
/// `build_runner` always deletes conflicting outputs and ignores the flag for
/// it.
/// The builders, such as `injectable_generator`, are dev dependencies that
/// the requesting module adds with a [PubspecContribution].
final class CodegenRequest extends Contribution {
  /// Requests code generation, for the reason in [description], of the
  /// libraries at [outputs].
  const CodegenRequest({
    this.description,
    this.outputs = const [],
    super.when,
  });

  /// Why the module needs code generation, for diagnostics.
  final String? description;

  /// The libraries that the builders generate and that code of the app
  /// imports, relative to the project root, such as
  /// `lib/core/di/dependencies.config.dart`.
  ///
  /// Part files, such as the `.g.dart` files of `json_serializable`, need
  /// not be listed. The pipeline checks that the builders generated each
  /// of these, and the contract harness takes them as files of the app.
  final List<String> outputs;
}
