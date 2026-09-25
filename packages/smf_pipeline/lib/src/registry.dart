import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/request.dart';

/// The modules the CLI offers and the roles they declare, checked against
/// the rules of the lego model.
///
/// The registry is checked once, before the command line is parsed, because
/// the options of the roles become options of the command.
final class ModuleRegistry {
  /// Creates the registry of [modules].
  ///
  /// Throws a [RegistryException] with every problem found; see
  /// [problemsOf].
  factory ModuleRegistry(List<SmfModule> modules) {
    final problems = problemsOf(modules);
    if (problems.isNotEmpty) throw RegistryException(problems);
    return ModuleRegistry._(
      List.unmodifiable(modules),
      List.unmodifiable(rolesOf(modules)),
      {for (final module in modules) module.descriptor.id: module},
    );
  }

  ModuleRegistry._(this.modules, this.roles, this._byId);

  /// The modules, in the order the CLI offers them.
  final List<SmfModule> modules;

  /// Every role the modules declare, directly or through other roles, in the
  /// order of first appearance.
  final List<Role> roles;

  final Map<ModuleId, SmfModule> _byId;

  /// The module [id], or `null` if it is not registered.
  SmfModule? operator [](ModuleId id) => _byId[id];

  /// The ids of all modules.
  Iterable<ModuleId> get ids => _byId.keys;

  /// The modules that provide [role], in registry order.
  List<SmfModule> providersOf(Role role) => [
        for (final module in modules)
          if (module.descriptor.provides.contains(role)) module,
      ];

  /// The roles that every module may use without declaring them; see
  /// [Role.openToAllModules].
  Set<Role> get openRoles => {
        for (final role in roles)
          if (role.openToAllModules) role,
      };

  /// Every role [modules] declare, directly or through other roles, in the
  /// order of first appearance.
  static List<Role> rolesOf(List<SmfModule> modules) {
    final roles = <Role>{};
    void add(Role role) {
      if (!roles.add(role)) return;
      role.requires.forEach(add);
      role.uses.forEach(add);
    }

    for (final module in modules) {
      final descriptor = module.descriptor;
      final kind = descriptor.kind;
      [
        ...descriptor.provides,
        ...descriptor.requires,
        ...descriptor.uses,
        if (descriptor.variants case final variants?) variants.role,
        ...kind.mustProvide,
        ...kind.impliedRequires,
        ...kind.requiredData,
        ...kind.forbiddenData,
      ].forEach(add);
    }
    return roles.toList();
  }

  /// Describes what is wrong with a registry of [modules], or returns an
  /// empty list.
  ///
  /// It checks the names that become Dart identifiers, tags and options,
  /// the dependencies between modules, the rules of module kinds, the
  /// variants, and the sockets.
  static List<String> problemsOf(List<SmfModule> modules) {
    final roles = rolesOf(modules);
    return [
      ..._moduleIdProblems(modules),
      ..._roleIdProblems(roles, modules),
      ..._dependencyProblems(modules),
      for (final module in modules) ..._descriptorProblems(module, modules),
      ..._socketProblems(roles, modules),
      ..._optionProblems(roles),
      for (final role in roles)
        if (role.cardinality == RoleCardinality.exactlyOne &&
            !modules.any((m) => m.descriptor.provides.contains(role)))
          'Every app needs the ${role.id}, but no module provides it.',
    ];
  }
}

/// Names of members that every Dart object has, which generated getters
/// such as `context.nav.<module>` must not shadow.
const _objectMembers = {'hashCode', 'runtimeType', 'toString', 'noSuchMethod'};

List<String> _moduleIdProblems(List<SmfModule> modules) {
  final problems = <String>[];
  final seen = <ModuleId>{};
  final byIdentifier = <String, ModuleId>{};
  for (final module in modules) {
    final id = module.descriptor.id;
    if (!ModuleId.isValid(id.value)) {
      problems.add('The module id "$id" is not lower snake_case.');
      continue;
    }
    if (!seen.add(id)) {
      problems.add('Two modules have the id $id.');
      continue;
    }
    if (id.value == 'pipeline') {
      problems.add(
        'The module id pipeline names the pipeline in the order of '
        'contributions and in diagnostics.',
      );
    }
    final identifier = id.lowerCamelCase;
    if (!SmfNames.isDartIdentifier(identifier) ||
        _objectMembers.contains(identifier)) {
      problems.add(
        'The module id $id becomes the Dart name $identifier, which is '
        'reserved.',
      );
    }
    if (byIdentifier.putIfAbsent(identifier, () => id) case final other
        when other != id) {
      problems.add(
        'The module ids $other and $id both become the Dart name '
        '$identifier.',
      );
    }
  }
  return problems;
}

List<String> _roleIdProblems(List<Role> roles, List<SmfModule> modules) {
  final problems = <String>[];
  final byId = <String, Role>{};
  final moduleIds = {for (final module in modules) module.descriptor.id.value};
  for (final role in roles) {
    if (!SmfNames.isSnakeCase(role.id)) {
      problems.add('The role id "${role.id}" is not lower snake_case.');
      continue;
    }
    if (byId.putIfAbsent(role.id, () => role) case final other
        when !identical(other, role)) {
      problems.add(
        'Two different roles have the id ${role.id}; a role must have one '
        'instance.',
      );
    }
    if (moduleIds.contains(role.id)) {
      problems.add(
        'The role ${role.id} and the module ${role.id} have the same id, so '
        'their sockets would have the same tags.',
      );
    }
  }
  return problems;
}

List<String> _dependencyProblems(List<SmfModule> modules) {
  final problems = <String>[];
  final byId = {for (final module in modules) module.descriptor.id: module};
  final kinds = <String, ModuleKind>{};
  for (final module in modules) {
    final kind = module.descriptor.kind;
    if (kinds.putIfAbsent(kind.id, () => kind) case final other
        when !identical(other, kind)) {
      problems.add('Two different module kinds have the id ${kind.id}.');
    }
  }
  for (final module in modules) {
    final descriptor = module.descriptor;
    for (final dependency in descriptor.dependsOn) {
      if (dependency == descriptor.id) {
        problems.add('The module ${descriptor.id} depends on itself.');
      } else if (!byId.containsKey(dependency)) {
        problems.add(
          'The module ${descriptor.id} depends on $dependency, which is not '
          'registered.',
        );
      }
    }
  }

  // Cycles of dependsOn, reported once per cycle.
  final done = <ModuleId>{};
  final reported = <String>{};
  void visit(ModuleId id, List<ModuleId> stack) {
    if (done.contains(id)) return;
    final index = stack.indexOf(id);
    if (index >= 0) {
      final cycle = [...stack.sublist(index), id];
      final key = ([...cycle.skip(1).map((id) => id.value)]..sort()).join(',');
      if (reported.add(key)) {
        problems.add('The modules depend on each other: ${cycle.join(' → ')}.');
      }
      return;
    }
    final module = byId[id];
    if (module == null) return;
    for (final dependency in module.descriptor.dependsOn) {
      if (dependency != id) visit(dependency, [...stack, id]);
    }
    done.add(id);
  }

  for (final module in modules) {
    visit(module.descriptor.id, const []);
  }
  return problems;
}

List<String> _descriptorProblems(SmfModule module, List<SmfModule> modules) {
  final descriptor = module.descriptor;
  final id = descriptor.id;
  final kind = descriptor.kind;
  final problems = <String>[];

  final provided = <Role>{};
  for (final provider in descriptor.providers) {
    if (!provided.add(provider.role)) {
      problems.add('The module $id has two providers of the ${provider.role}.');
    }
  }
  for (final role in kind.mustProvide) {
    if (!provided.contains(role)) {
      problems.add(
        'The module $id is of the $kind, so it must provide the $role.',
      );
    }
  }
  for (final role in provided) {
    if (descriptor.requires.contains(role) || descriptor.uses.contains(role)) {
      problems.add(
        'The module $id provides the $role, so it must not also require or '
        'use it.',
      );
    }
  }

  final variants = descriptor.variants;
  if (variants != null) {
    final role = variants.role;
    if (!kind.allowsVariants) {
      problems.add('The module $id is of the $kind, which has no variants.');
    }
    if (role.cardinality.allowsMany) {
      problems.add(
        'The variants of the module $id are for the $role, which can have '
        'several providers; variants need a role with at most one.',
      );
    }
    if (provided.contains(role)) {
      problems.add(
        'The module $id provides the $role, so it cannot have variants for '
        'it.',
      );
    }
    if (variants.byProvider.isEmpty) {
      problems.add('The module $id declares variants but has none.');
    }
    final providers = {
      for (final other in modules)
        if (other.descriptor.provides.contains(role)) other.descriptor.id,
    };
    for (final key in variants.byProvider.keys) {
      if (!providers.contains(key)) {
        problems.add(
          'The module $id has a variant for $key, which is not a registered '
          'provider of the $role.',
        );
      }
    }
  }
  return problems;
}

List<String> _socketProblems(List<Role> roles, List<SmfModule> modules) {
  final problems = <String>[];
  final owners = <String, String>{};
  final families = <SocketFamily<Object?, SocketKind>>[];

  void addSocket(SocketRef socket) {
    problems.addAll(socket.problems());
    for (final tag in socket.tags) {
      if (owners.putIfAbsent(tag, () => '$socket') case final other
          when other != '$socket') {
        problems.add('The $other and the $socket have the same tag $tag.');
      }
    }
  }

  PipelineSockets.all.forEach(addSocket);
  for (final role in roles) {
    for (final socket in role.sockets) {
      if (!identical(socket.role, role) || socket.familyKey.isNotEmpty) {
        problems.add('The ${role.id} declares the $socket, which is not its.');
        continue;
      }
      addSocket(socket);
    }
    for (final family in role.socketFamilies) {
      if (!identical(family.role, role)) {
        problems.add(
          'The ${role.id} declares the socket family ${family.name} of '
          '${family.ownerName}.',
        );
        continue;
      }
      families.add(family);
    }
  }
  for (final module in modules) {
    final descriptor = module.descriptor;
    for (final socket in descriptor.sockets) {
      if (socket.module != descriptor.id || socket.familyKey.isNotEmpty) {
        problems.add(
          'The module ${descriptor.id} declares the $socket, which is not its.',
        );
        continue;
      }
      addSocket(socket);
    }
    for (final family in descriptor.socketFamilies) {
      if (family.module != descriptor.id) {
        problems.add(
          'The module ${descriptor.id} declares the socket family '
          '${family.name} of ${family.ownerName}.',
        );
        continue;
      }
      families.add(family);
    }
  }

  for (final family in families) {
    if (!SmfNames.isSnakeCase(family.name)) {
      problems.add(
        'The socket family name "${family.name}" of ${family.ownerName} is '
        'not lower snake_case.',
      );
    }
    for (final MapEntry(key: tag, value: socket) in owners.entries) {
      if (tag.startsWith(family.tagPrefix)) {
        problems.add(
          'The tag $tag of the $socket starts like the members of the socket '
          'family ${family.ownerName}.${family.name}.',
        );
      }
    }
    for (final other in families) {
      if (!identical(other, family) &&
          other.tagPrefix.startsWith(family.tagPrefix)) {
        problems.add(
          'The socket families ${family.ownerName}.${family.name} and '
          '${other.ownerName}.${other.name} have overlapping tags.',
        );
      }
    }
  }
  return problems;
}

final RegExp _kebabCase = RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$');

List<String> _optionProblems(List<Role> roles) {
  final problems = <String>[];
  final owners = <String, Role>{};
  for (final role in roles) {
    for (final option in role.options) {
      final name = option.name;
      if (!_kebabCase.hasMatch(name)) {
        problems.add(
          'The option --$name of the ${role.id} is not lower kebab-case.',
        );
      }
      if (CreateOptions.names.contains(name) ||
          name == 'help' ||
          name.startsWith('no-')) {
        problems.add(
          'The option --$name of the ${role.id} is an option of the '
          'pipeline, or starts with no-, which negates its flags.',
        );
      }
      if (role.template == null) {
        problems.add(
          'The ${role.id} has the option --$name but no template, whose '
          'choose hook would read it.',
        );
      }
      if (owners.putIfAbsent(name, () => role) case final other
          when !identical(other, role)) {
        problems.add(
          'The ${other.id} and the ${role.id} both have the option --$name.',
        );
      }
    }
  }
  return problems;
}
