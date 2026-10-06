part of '../role.dart';

/// What the pipeline knows when it runs the hooks of roles and providers.
///
/// The pipeline builds one request per stage and passes it to
/// [Role.hookInput], which narrows it down to what a role may see.
final class RoleHookRequest {
  /// Creates the request.
  const RoleHookRequest({
    required this.data,
    required this.presentRoles,
    required this.context,
    this.choices = const {},
  });

  /// The data of all roles, each with its origin: that of the modules, in
  /// the order the modules were selected, and then that of the templates of
  /// roles, in the order of the first provider of each role.
  final List<RoleData<Object>> data;

  /// The roles present in the app.
  final Set<Role> presentRoles;

  /// The app being generated.
  final ModuleContext context;

  /// The results of the roles' [RoleTemplate.choose] hooks, from the stage
  /// they run on.
  final Map<Role, Object?> choices;
}

/// The input of a hook of a role's template or of one of its providers.
///
/// Create it with [Role.hookInput].
final class RoleHookInput<D extends Object> {
  RoleHookInput._({
    required this.role,
    required this.data,
    required Set<Role> present,
    required Map<Role, List<RoleData<Object>>> visibleData,
    required this.choice,
    required this.context,
  })  : _present = present,
        _visibleData = visibleData;

  /// The role whose hook runs.
  final Role<D> role;

  /// The data of [role] that applies in the app, each with its origin: that
  /// of the modules, in the order the modules were selected, and then that
  /// of the templates of roles, in the order of the first provider of each
  /// role.
  final List<RoleData<D>> data;

  /// The result of the role's [RoleTemplate.choose] hook, or `null` before
  /// it runs or if the role has none.
  ///
  /// A role that makes a choice offers a typed accessor for it.
  final Object? choice;

  /// The app being generated.
  final ModuleContext context;

  final Set<Role> _present;
  final Map<Role, List<RoleData<Object>>> _visibleData;

  /// The platforms and the platform identifiers of the app.
  AppIdentity get appIdentity => context.appIdentity;

  /// Whether [other] is present in the app.
  ///
  /// A hook may ask only about its own role and the roles it requires or
  /// uses (see [Role.visibleRoles]); throws an [ArgumentError] for any
  /// other.
  bool has(Role other) {
    if (identical(other, role)) return true;
    if (!role.visibleRoles.contains(other)) {
      throw ArgumentError.value(
        other,
        'other',
        'The $role neither requires nor uses the $other, so its hooks cannot '
            'check its presence',
      );
    }
    return _present.contains(other);
  }
}

/// What the pipeline knows when it runs the [RoleTemplate.choose] hooks.
final class RoleChoiceRequest {
  /// Creates the request.
  const RoleChoiceRequest({
    required this.data,
    required this.presentRoles,
    required this.optionValues,
    required this.environment,
    required this.context,
  });

  /// The data of all roles, each with its origin: that of the modules, in
  /// the order the modules were selected, and then that of the templates of
  /// roles, in the order of the first provider of each role.
  final List<RoleData<Object>> data;

  /// The roles present in the app.
  final Set<Role> presentRoles;

  /// The values of all role options given on the command line, by option
  /// name.
  final Map<String, String?> optionValues;

  /// The machine and the user.
  final SmfEnvironment environment;

  /// The app being generated.
  final ModuleContext context;
}

/// The input of a [RoleTemplate.choose] hook.
///
/// Create it with [Role.choiceContext].
final class RoleChoiceContext<D extends Object> {
  RoleChoiceContext._({
    required this.role,
    required this.data,
    required Set<Role> present,
    required Map<String, String?> optionValues,
    required this.environment,
    required this.context,
  })  : _present = present,
        _optionValues = optionValues;

  /// The role whose hook runs.
  final Role<D> role;

  /// The data of [role] that applies in the app: that of the modules, in
  /// the order the modules were selected, and then that of the templates of
  /// roles, in the order of the first provider of each role.
  final List<RoleData<D>> data;

  /// The machine and the user; ask only if [SmfEnvironment.interactive].
  final SmfEnvironment environment;

  /// The app being generated.
  final ModuleContext context;

  final Set<Role> _present;
  final Map<String, String?> _optionValues;

  /// Whether [other] is present in the app.
  ///
  /// A hook may ask only about its own role and the roles it requires or
  /// uses (see [Role.visibleRoles]), as [RoleHookInput.has] lets the other
  /// hooks; throws an [ArgumentError] for any other.
  bool has(Role other) {
    if (identical(other, role)) return true;
    if (!role.visibleRoles.contains(other)) {
      throw ArgumentError.value(
        other,
        'other',
        'The $role neither requires nor uses the $other, so its hooks cannot '
            'check its presence',
      );
    }
    return _present.contains(other);
  }

  /// The value of the role's option [name], or `null` if it was not given.
  ///
  /// Throws an [ArgumentError] if [name] is not one of the role's
  /// [Role.options].
  String? option(String name) {
    if (!_optionValues.containsKey(name)) {
      throw ArgumentError.value(name, 'name', 'The $role has no such option');
    }
    return _optionValues[name];
  }
}

/// What the [RoleTemplate.render] or [RoleProvider.render] hook adds to the
/// app.
final class RoleOutput {
  /// Creates the output of a render hook.
  const RoleOutput({
    this.fragments = const [],
    this.vars = const {},
    this.files = const {},
  });

  /// Code and values for sockets, with the same access rules as the
  /// contributions of the hook's owner.
  final List<SocketContribution> fragments;

  /// Variables for the bricks of the hook's owner: the role's template or
  /// the provider's module, the bricks of its variant included.
  ///
  /// They are plain data, such as strings, numbers, booleans and lists and
  /// maps of them, and follow the rules of [BrickContribution.vars], but
  /// none is a [RoleVar]: a hook asks for the presence of the roles that
  /// its role requires or uses itself (see [RoleHookInput.has]). A variable
  /// that two hooks of one module, or a hook and a brick of its owner, both
  /// set is an error.
  ///
  /// A variable may also be a [Fragment] of code with the imports it needs,
  /// such as the routes a router renders from the data of its role. The
  /// variable renders as the fragment's code, and the pipeline adds the
  /// imports to every Dart file of the owner's bricks that reads it, as it
  /// does for the fragments of a socket: an import the file has already is
  /// not added again, and the harness knows who needs each.
  /// - A template reads such a variable as it is, `{{{routes}}}`, outside
  ///   mustache sections; a path cannot read one.
  /// - One with imports can be read only by a Dart library, not by a part
  ///   file or a file that is not Dart.
  /// - A line that holds nothing but a variable without code goes away.
  /// - A fragment variable that no template of the owner reads is an error,
  ///   since its code would be lost; one that only a brick the app leaves
  ///   out reads, such as a brick for when a role is present, is not. The
  ///   bricks of the variants of the owner for other providers do not
  ///   count.
  final Map<String, Object?> vars;

  /// Text files of the hook's owner, the role's template or the provider's
  /// module: the text of each by its path relative to the root of the app,
  /// with forward slashes, such as `lib/core/clock/zones/zone_1.dart`.
  ///
  /// A brick has the same files in every app, so the files whose number or
  /// paths depend on the data of the role or on its choice come from the
  /// hook, such as one file for each item that the modules of the app give
  /// the role. What every app of the owner has stays in a brick.
  ///
  /// The pipeline takes each file as it is, text and path: it renders no
  /// mustache, fills no tag of a socket and adds no import, and mason,
  /// which removes a backslash before a line break or a non-ASCII character
  /// from what it renders, does not read it. Once the app is written,
  /// `dart fix` and `dart format` go over a Dart file among them as over
  /// the rest of the app. Otherwise it is a file of the app like those of
  /// the bricks, and follows their rules:
  /// - the path is inside the app, and is not of a file that belongs to one
  ///   machine or one build, such as `.dart_tool/` or `pubspec.lock`;
  /// - the file of a provider is where the kind of its module may generate
  ///   files (see [ModuleKind.allowsFile]);
  /// - every file of the app is generated once: a path that a brick or
  ///   another hook generates too is an error, also when the paths differ
  ///   only in case.
  ///
  /// The path comes from the data of the role, which the author of the
  /// hook does not see as the author of a brick sees its paths, so two
  /// more rules hold:
  /// - every machine can write the file: the path has no control character
  ///   or line break and none of `< > : " | ? *`, which Windows allows in
  ///   no name of a file, and no segment of it ends with a dot or a space,
  ///   which Windows removes;
  /// - a path of the app is a file or a directory, not both: a file where
  ///   another file of the app has a directory, or in what is a file of the
  ///   app, is an error, whatever the case of the paths.
  ///
  /// The contract harness checks such a file like any other. A Dart file
  /// among them parses and imports only what its owner may use: for a
  /// provider, as for its fragments, also the files and the packages of the
  /// modules whose data it renders. No file of the app, of a hook or of a
  /// brick, is at a path where code generation or the localizations of
  /// Flutter write theirs once the app is rendered.
  final Map<String, String> files;
}
