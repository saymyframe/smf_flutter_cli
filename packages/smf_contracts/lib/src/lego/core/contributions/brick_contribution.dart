part of '../contributions.dart';

/// Template files of a module or role template: a mason bundle.
///
/// The pipeline renders the bundle with mason, with these variables:
/// - `app_name` and `org_name` of the [ModuleContext];
/// - `has_<role>` for each role the contributor provides, requires or uses
///   (see [Role.presenceFlag]);
/// - the rendered contributions of each socket tag in the bundle;
/// - the variables a role hook returns in [RoleOutput.vars] for its bricks;
/// - [vars].
///
/// A bundle with mason hooks is rejected: what hooks used to do is part of
/// the pipeline, [Preflight] and [PostGenStep]. Every generated file has
/// exactly one owner, so two bricks must not produce the same path.
final class BrickContribution extends Contribution {
  /// Creates a contribution of the files of [bundle].
  const BrickContribution(this.bundle, {this.vars = const {}, super.when});

  /// The mason bundle with the template files.
  final MasonBundle bundle;

  /// Variables of the contributor for this bundle.
  final Map<String, Object?> vars;
}
