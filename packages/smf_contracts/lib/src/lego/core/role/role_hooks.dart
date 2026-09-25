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

  /// The data of all roles, each with its origin, in the order the modules
  /// were selected.
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

  /// The data of [role] from all modules, each with its origin, in the order
  /// the modules were selected.
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

  /// The platform identifiers of the app.
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
    required this.optionValues,
    required this.environment,
    required this.context,
  });

  /// The data of all roles, each with its origin, in the order the modules
  /// were selected.
  final List<RoleData<Object>> data;

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
    required Map<String, String?> optionValues,
    required this.environment,
    required this.context,
  }) : _optionValues = optionValues;

  /// The role whose hook runs.
  final Role<D> role;

  /// The data of [role] from all modules, in the order the modules were
  /// selected.
  final List<RoleData<D>> data;

  /// The machine and the user; ask only if [SmfEnvironment.interactive].
  final SmfEnvironment environment;

  /// The app being generated.
  final ModuleContext context;

  final Map<String, String?> _optionValues;

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
  const RoleOutput({this.fragments = const [], this.vars = const {}});

  /// Code and values for sockets, with the same access rules as the
  /// contributions of the hook's owner.
  final List<SocketContribution> fragments;

  /// Variables for the bricks of the hook's owner: the role's template or
  /// the provider's module.
  final Map<String, Object?> vars;
}
