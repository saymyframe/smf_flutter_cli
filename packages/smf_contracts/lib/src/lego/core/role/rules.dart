part of '../role.dart';

/// A check that a role applies to the generated code of an app, such as
/// "`resolve` is called only in composition files".
///
/// The contract test harness renders modules, indexes every Dart file of the
/// result (see [DartFileIndex]) and runs the [Role.structuralRules] of every
/// present role with [Role.checkStructure]. A rule gets the role's data, so
/// it can compare the code with what modules declared, such as the
/// parameters of a route with the constructor of its screen. Rules are pure
/// functions of their input, so the harness needs no knowledge of any role.
final class StructuralRule<D extends Object> {
  /// Creates the rule [id] that runs [check].
  ///
  /// To keep a rule constant, [check] must be a top-level or static
  /// function.
  const StructuralRule({
    required this.id,
    required this.description,
    required List<SmfIssue> Function(StructuralRuleInput<D> input) check,
  }) : _check = check;

  /// A unique id, such as `app_entry.main_sequence`.
  final String id;

  /// What the rule requires, as a sentence.
  final String description;

  final List<SmfIssue> Function(StructuralRuleInput<D> input) _check;

  /// Returns the problems the rule finds in [input].
  List<SmfIssue> check(StructuralRuleInput<D> input) => _check(input);
}

/// What the contract test harness knows when it runs the structural rules
/// of a role; see [Role.checkStructure].
final class StructuralRuleRequest {
  /// Creates the request.
  const StructuralRuleRequest({
    required this.hook,
    required this.files,
    this.owners = const {},
    this.modules = const [],
  });

  /// The data and roles of the app, as for the role's hooks.
  final RoleHookRequest hook;

  /// The indexes of the Dart files, by path relative to the project root.
  final Map<String, DartFileIndex> files;

  /// Who generated each file, by path.
  final Map<String, ContributionOrigin> owners;

  /// The descriptors of the modules in the app.
  final List<ModuleDescriptor> modules;
}

/// The generated app a [StructuralRule] checks.
///
/// [Role.checkStructure] creates it.
final class StructuralRuleInput<D extends Object> {
  StructuralRuleInput._({
    required this.roleInput,
    required this.files,
    required this.owners,
    required this.modules,
  });

  /// The role's data and view of the app, as its hooks get them.
  final RoleHookInput<D> roleInput;

  /// The indexes of the Dart files, by path relative to the project root.
  final Map<String, DartFileIndex> files;

  /// Who generated each file, by path.
  final Map<String, ContributionOrigin> owners;

  /// The descriptors of the modules in the app.
  final List<ModuleDescriptor> modules;

  /// The descriptor of the module [id], if it is in the app.
  ModuleDescriptor? module(ModuleId id) {
    for (final module in modules) {
      if (module.id == id) return module;
    }
    return null;
  }
}

/// A check that a role applies, during validation and before anything is
/// rendered, to each module that provides, requires or uses the role.
///
/// The pipeline runs the [Role.moduleRules] with [Role.checkModule]. For
/// checks of the generated code, see [StructuralRule].
final class ModuleRule<D extends Object> {
  /// Creates the rule [id] that runs [check].
  ///
  /// To keep a rule constant, [check] must be a top-level or static
  /// function.
  const ModuleRule({
    required this.id,
    required this.description,
    required List<SmfIssue> Function(ModuleRuleInput<D> input) check,
  }) : _check = check;

  /// A unique id, such as `router.routes_have_screens`.
  final String id;

  /// What the rule requires, as a sentence.
  final String description;

  final List<SmfIssue> Function(ModuleRuleInput<D> input) _check;

  /// Returns the problems the rule finds in [input].
  List<SmfIssue> check(ModuleRuleInput<D> input) => _check(input);
}

/// What the pipeline knows when it runs the module rules of a role for one
/// module; see [Role.checkModule].
final class ModuleRuleRequest {
  /// Creates the request.
  const ModuleRuleRequest({
    required this.hook,
    required this.module,
    required this.contributions,
  });

  /// The data and roles of the app, as for the role's hooks.
  final RoleHookRequest hook;

  /// The descriptor of the module.
  final ModuleDescriptor module;

  /// The contributions of the module and its variant.
  final List<Contribution> contributions;
}

/// The module a [ModuleRule] checks.
///
/// [Role.checkModule] creates it.
final class ModuleRuleInput<D extends Object> {
  ModuleRuleInput._({
    required this.roleInput,
    required this.module,
    required this.data,
    required this.contributions,
  });

  /// The role's data and view of the app, as its hooks get them.
  final RoleHookInput<D> roleInput;

  /// The descriptor of the module.
  final ModuleDescriptor module;

  /// The data the module and its variant contributed to the role.
  final List<RoleData<D>> data;

  /// The contributions of the module and its variant that apply in this
  /// app: those whose [Contribution.when] roles, and for [RoleData] whose
  /// role, are present.
  final List<Contribution> contributions;
}
