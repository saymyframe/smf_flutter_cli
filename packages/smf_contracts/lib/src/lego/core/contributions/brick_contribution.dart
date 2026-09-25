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
/// Paths are relative to the root of the app. A path may use variables,
/// such as the directory of the app's Kotlin package, but no mustache
/// sections, partials or includes: files that only some apps have go into a
/// brick of their own, contributed with [when]. Mustache escapes a variable
/// in two braces for HTML, so a variable that holds code, or a path with a
/// slash, takes three: `{{{name}}}`.
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
  ///
  /// They cannot take the names the pipeline sets: `app_name`, `org_name`,
  /// `smf_…` and `has_…`. mason removes a backslash that comes before a line
  /// break or a non-ASCII character in anything it renders, so no text
  /// here may have one.
  final Map<String, Object?> vars;
}
