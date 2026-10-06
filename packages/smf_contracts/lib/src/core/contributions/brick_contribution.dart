part of '../contributions.dart';

/// Template files of a module or role template: a mason bundle.
///
/// The pipeline renders the bundle with mason, with these variables:
/// - `app_name` and `org_name` of the [ModuleContext];
/// - `has_<role>` for each role the contributor provides, requires or uses,
///   and each role open to all modules (see [Role.presenceFlag]);
/// - the rendered contributions of each socket tag in the bundle;
/// - the variables a role hook returns in [RoleOutput.vars] for its bricks;
/// - [vars], each with its value for the roles of the app (see [RoleVar]).
///
/// A template reads only variables that one of these sets; mustache would
/// render any other as nothing.
///
/// Paths are relative to the root of the app. A path may use variables,
/// such as the directory of the app's Kotlin package, but no mustache
/// sections, partials or includes: files that only some apps have go into a
/// brick of their own, contributed with [when], and files whose number or
/// paths depend on the data of a role come from the render hook of the
/// role's template or provider (see [RoleOutput.files]). Mustache escapes a
/// variable in two braces for HTML, so a variable that holds code, or a
/// path with a slash, takes three: `{{{name}}}`.
///
/// A bundle with mason hooks is rejected: what hooks used to do is part of
/// the pipeline, [Preflight] and [PostGenStep]. Every generated file has
/// exactly one owner, so two bricks, or a brick and a render hook, must not
/// produce the same path.
final class BrickContribution extends Contribution {
  /// Creates a contribution of the files of [bundle].
  const BrickContribution(this.bundle, {this.vars = const {}, super.when});

  /// The mason bundle with the template files.
  final MasonBundle bundle;

  /// Variables of the contributor for this bundle: plain data, which is
  /// strings, numbers, booleans, and lists and maps of them, or a [RoleVar]
  /// for code that depends on the presence of a role.
  ///
  /// They cannot take the names the pipeline sets: `app_name`, `org_name`,
  /// `smf_…` and `has_…`. mason removes a backslash that comes before a line
  /// break or a non-ASCII character in anything it renders, so no text
  /// here may have one.
  final Map<String, Object?> vars;
}

/// A value of [BrickContribution.vars] for code that depends on whether a
/// role is present in the app: [present] with [role], [absent] without it.
///
/// A module does not branch on the roles of the app when it contributes
/// (see [SmfModule.contribute]). So a template whose code differs with a
/// role that its module only uses needs two mustache branches under the
/// presence flag of the role, around the code and again around its import.
/// With a `RoleVar` the template reads one variable instead, and the
/// pipeline takes its value by the presence of the role, as it tells by a
/// [Contribution.when] whether a contribution applies:
///
/// ```dart
/// BrickContribution(
///   bundle,
///   vars: {
///     'zones': RoleVar(
///       clockRole,
///       present: Fragment(
///         'createClock().zones',
///         imports: [ImportRef.app('core/clock/clock_factory.dart')],
///       ),
///       absent: 'const <String>[]',
///     ),
///   },
/// )
/// ```
///
/// A template with `List<String> zones() => {{{zones}}};` then calls
/// `createClock()`, with the import of its file, in an app with the clock,
/// and returns `const <String>[]` in an app without it.
///
/// - [role] is a role that the contributor provides, requires or uses, as
///   the roles of a [Contribution.when] are.
/// - Each value is code, as the variable renders it: a [Fragment] with the
///   imports that the code needs, or a string of code that needs none. It
///   is no plain data for mustache, such as a list to iterate or a boolean
///   to test: a template tests the presence of a role with the presence
///   flag of the role (see [Role.presenceFlag]).
/// - The variable is a fragment variable in every app, whichever value the
///   app gets, so that a template reads it rightly in every app or in
///   none. A template reads it as it reads the fragment variable of a
///   render hook (see [RoleOutput.vars]): as it is, `{{{zones}}}`, and a
///   path cannot read it. The pipeline adds the imports of the value that
///   the app gets to every Dart file of the brick that reads the variable.
///   When either value has imports, only a Dart library may read the
///   variable, not a part file or a file that is not Dart. A line that
///   holds nothing but the variable goes away in an app whose value has no
///   code.
/// - The code depends on one role, so a template reads the variable
///   outside every mustache section, that of the presence flag of another
///   role included. Code that needs a second role goes into a brick of its
///   own, which the module contributes with a [Contribution.when] of that
///   role and whose template reads the variable.
/// - Only the whole value of a variable of a brick depends on a role: a
///   `RoleVar` is no item of a list or a map and no value of another
///   `RoleVar`. The variables of a render hook take none: a hook asks for
///   the presence of the roles that its role requires or uses itself (see
///   [RoleHookInput.has]).
///
/// Like any variable of a brick, it needs no template that reads it.
@immutable
final class RoleVar {
  /// Creates a value that is the code [present] in an app with [role] and
  /// the code [absent] in an app without it.
  const RoleVar(this.role, {required this.present, required this.absent});

  /// The role whose presence decides the code.
  final Role role;

  /// The code in an app with [role]: a [Fragment], or a string of code that
  /// needs no imports.
  final Object present;

  /// The code in an app without [role]: a [Fragment], or a string of code
  /// that needs no imports.
  final Object absent;
}
