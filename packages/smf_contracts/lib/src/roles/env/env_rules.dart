part of '../env.dart';

/// The code of a variable of a brick that reads a value of the app, with
/// the getter of the key.
final RegExp _readsKey = RegExp('^$_appEnv\\.([A-Za-z0-9_\$]+)\$');

/// The problems of the data of the module of [input], which the module rule
/// `env.keys` reports: those of its keys, a variable of its bricks that
/// reads a key that neither the module nor a module that it depends on
/// gives, and tool arguments from a module that does not provide the role,
/// more than once, or with an argument that is not one line.
///
/// The template of the role checks the keys of the templates of roles and
/// refuses tool arguments from them.
List<SmfIssue> _checkKeys(ModuleRuleInput<EnvData> input) {
  final module = input.module;
  final origin = ModuleOrigin(module.id);
  final keys = [
    for (final data in input.data)
      if (data.value case final EnvKey key) key,
  ];
  final arguments = [
    for (final data in input.data)
      if (data.value case final EnvToolArguments given) given,
  ];
  final provides = module.provides.contains(envRole);
  return [
    for (final problem in _keyProblems(keys, module.id.value))
      SmfIssue(problem, origin: origin),
    ..._variableIssues(input, origin),
    if (arguments.isNotEmpty && !provides)
      SmfIssue(
        'The module gives the $envRole tool arguments, which only a provider '
        'of the role gives.',
        hint: 'Give the role the keys that your code reads instead.',
        origin: origin,
      ),
    if (provides && arguments.length > 1)
      SmfIssue(
        'A provider of the $envRole gives it tool arguments at most once, but '
        'the module gives them ${arguments.length} times.',
        hint: 'Give all of them in one EnvToolArguments, in their order.',
        origin: origin,
      ),
    for (final given in arguments)
      for (final problem in given.problems()) SmfIssue(problem, origin: origin),
  ];
}

/// The code of [value], a value of a [RoleVar]: a fragment or a string of
/// code.
String _codeOf(Object value) => value is Fragment ? value.code : '$value';

/// The problems of the variables of the bricks of the module of [input]
/// that read a value of the app, as those of [EnvRole.varsOf] do: one that
/// reads a getter that no key of the module, or of a module that it depends
/// on, has.
List<SmfIssue> _variableIssues(
  ModuleRuleInput<EnvData> input,
  ModuleOrigin origin,
) {
  final readable = {
    origin,
    for (final dependency in input.module.dependsOn) ModuleOrigin(dependency),
  };
  final getters = {
    for (final key in envRole.keysIn(input.roleInput))
      if (readable.contains(key.owner)) key.getter,
  };
  return [
    for (final brick in input.contributions.whereType<BrickContribution>())
      for (final MapEntry(key: name, value: variable) in brick.vars.entries)
        if (variable case RoleVar(:final role, :final present)
            when identical(role, envRole))
          if (_readsKey.firstMatch(_codeOf(present))?[1] case final getter?
              when !getters.contains(getter))
            SmfIssue(
              'The variable $name of the brick ${brick.bundle.name} reads '
              '$_appEnv.$getter, but neither the module nor a module that it '
              'depends on has a key with the getter $getter.',
              hint: 'Give the role the keys of the variables as data too, '
                  'and make the variables with envRole.varsOf() from them.',
              origin: origin,
            ),
  ];
}

/// The keys of the app that the provider of the role does not render: those
/// for which the `AppEnv` of the provider declares no static getter of the
/// name of their getter.
///
/// So no provider leaves out a key that a module gives the role, and the
/// tests of the modules need not look into the files of any provider.
/// Without the descriptor of a provider in [input], or without its
/// `AppEnv`, which the check of the interface of the role reports, there is
/// nothing to check.
List<SmfIssue> _checkKeysRendered(StructuralRuleInput<EnvData> input) {
  if (!input.modules.any((module) => module.provides.contains(envRole))) {
    return const [];
  }
  const path = EnvRole.readerFile;
  final declaration = input.files[path]?.declaration(_appEnv);
  if (declaration == null) return const [];
  bool declares(String getter) => declaration.members.any(
        (member) =>
            member.name == getter &&
            member.isStatic &&
            member.kind == MemberKind.getter,
      );
  return [
    for (final key in envRole.keysIn(input.roleInput))
      if (!declares(key.getter))
        SmfIssue(
          'The provider of the $envRole does not render the $key: $_appEnv '
          'in $path declares no static getter ${key.getter}.',
          hint: 'Declare a static String? getter for every key of '
              'EnvRole.keysIn(), named by EnvKey.getter.',
          origin: input.owners[path],
          path: path,
        ),
  ];
}

/// Whether [target], the expression before a dot, is the class `AppEnv`, as
/// code names it: on its own, or after the prefix of an import.
bool _isAppEnv(String? target) =>
    target != null && (target == _appEnv || target.endsWith('.$_appEnv'));

/// Whether the rule `env.key_access` looks at the files of [owner], whose
/// descriptor is [module] if it is a module of the app.
///
/// It looks at the files of a module with the role among its roles, which
/// may read its own keys and those of the modules it depends on, at the
/// files of the template of a role that requires or uses the role, which
/// may read its own keys, and at the files of the pipeline, which has none.
/// The harness reports the import of
/// [EnvRole.readerFile] by a module without the role among its roles and by
/// the template of a role that neither requires nor uses it. The provider
/// of the role declares `AppEnv`. A module whose descriptor the app lacks
/// has no roles to tell by.
bool _readsKeys(ContributionOrigin owner, ModuleDescriptor? module) =>
    switch (owner) {
      ModuleOrigin() => module != null &&
          module.roles.contains(envRole) &&
          !module.provides.contains(envRole),
      RoleTemplateOrigin(:final role) =>
        identical(role, envRole) || role.visibleRoles.contains(envRole),
      PipelineOrigin() => true,
    };

List<SmfIssue> _checkKeyAccess(StructuralRuleInput<EnvData> input) {
  final byGetter = {
    for (final key in envRole.keysIn(input.roleInput)) key.getter: key,
  };
  return [
    for (final MapEntry(key: path, value: file) in input.files.entries)
      ..._keyAccessIssuesOf(input, path, file, byGetter),
  ];
}

/// The issues of the rule `env.key_access` in [file], the file at [path],
/// whose keys by the names of their getters are [byGetter]: none when the
/// rule does not look at the files of its owner.
List<SmfIssue> _keyAccessIssuesOf(
  StructuralRuleInput<EnvData> input,
  String path,
  DartFileIndex file,
  Map<String, AppEnvKey> byGetter,
) {
  final generatedBy = input.owners[path];
  if (generatedBy == null) return const [];
  final owner = _ownerOf(generatedBy);
  final module = switch (owner) {
    ModuleOrigin(:final module) => input.module(module),
    _ => null,
  };
  if (!_readsKeys(owner, module)) return const [];
  final readable = {
    owner,
    for (final dependency in module?.dependsOn ?? const <ModuleId>{})
      ModuleOrigin(dependency),
  };
  return [
    for (final access in file.memberAccesses)
      if (_isAppEnv(access.target))
        if (_readIssueOf(
          path,
          '${access.target}.${access.name}',
          access.name,
          byGetter[access.name],
          owner: owner,
          readable: readable,
        )
            case final issue?)
          issue,
    for (final call in file.invocations)
      if (_isAppEnv(call.target))
        SmfIssue(
          '$path calls ${call.target}.${call.name}(), but the values of the '
          'app are getters, each named by the role.',
          hint: 'Read a value as the getter of its key, without arguments.',
          origin: owner,
          path: path,
        ),
  ];
}

/// The issue of [read], the read of the getter [getter] of `AppEnv` at
/// [path] by [owner], whose key is [key], or `null` when [owner] may read
/// it: it reads a key of the app, and the key is one of those in [readable].
SmfIssue? _readIssueOf(
  String path,
  String read,
  String getter,
  AppEnvKey? key, {
  required ContributionOrigin owner,
  required Set<ContributionOrigin> readable,
}) {
  if (key == null) {
    return SmfIssue(
      '$path reads $read, but no key of the app has the getter $getter.',
      hint: 'Give the role the key as data of the code that reads it, and '
          'read it as the getter that the role names for it, such as '
          '$_appEnv.myServiceKey for MY_SERVICE_KEY.',
      origin: owner,
      path: path,
    );
  }
  if (!readable.contains(key.owner)) {
    final mayRead = owner is ModuleOrigin
        ? 'its own keys and those of the modules it depends on'
        : 'its own keys';
    return SmfIssue(
      '$path reads $read, the $key, but ${_named(owner)} may only read '
      '$mayRead.',
      hint: 'Give the role a key of your own.',
      origin: owner,
      path: path,
    );
  }
  return null;
}
