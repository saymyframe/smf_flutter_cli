import 'package:smf_contracts/lego_core.dart';

/// A check that a role applies to the generated code of an app, such as
/// "`resolve` is called only in composition files".
///
/// The contract test harness renders modules, indexes every Dart file of the
/// result (see [DartFileIndex]) and runs the [Role.structuralRules] of the
/// present roles over the indexes. Rules are pure functions of their input,
/// so the harness needs no knowledge of any role.
final class StructuralRule {
  /// Creates the rule [id] that runs [check].
  ///
  /// To keep a rule constant, [check] must be a top-level or static
  /// function.
  const StructuralRule({
    required this.id,
    required this.description,
    required this.check,
  });

  /// A unique id, such as `app_entry.bootstrap_is_ui_free`.
  final String id;

  /// What the rule requires, as a sentence.
  final String description;

  /// Returns the problems the rule finds in [StructuralRuleInput].
  final List<SmfIssue> Function(StructuralRuleInput input) check;
}

/// The generated app a [StructuralRule] checks.
final class StructuralRuleInput {
  /// Creates the input of a structural rule.
  const StructuralRuleInput({
    required this.files,
    this.owners = const {},
    this.modules = const [],
    this.presentRoles = const {},
  });

  /// The indexes of the Dart files, by path relative to the project root.
  final Map<String, DartFileIndex> files;

  /// Who generated each file, by path.
  final Map<String, ContributionOrigin> owners;

  /// The descriptors of the modules in the app.
  final List<ModuleDescriptor> modules;

  /// The roles present in the app.
  final Set<Role> presentRoles;

  /// The descriptor of the module [id], if it is in the app.
  ModuleDescriptor? module(ModuleId id) {
    for (final module in modules) {
      if (module.id == id) return module;
    }
    return null;
  }
}

/// A check that a role applies to the data of each module that provides,
/// requires or uses it, before anything is rendered.
///
/// The pipeline runs the [Role.moduleRules] during validation. For checks of
/// the generated code, see [StructuralRule].
final class ModuleRule {
  /// Creates the rule [id] that runs [check].
  ///
  /// To keep a rule constant, [check] must be a top-level or static
  /// function.
  const ModuleRule({
    required this.id,
    required this.description,
    required this.check,
  });

  /// A unique id, such as `router.routes_in_namespace`.
  final String id;

  /// What the rule requires, as a sentence.
  final String description;

  /// Returns the problems the rule finds in [ModuleRuleInput].
  final List<SmfIssue> Function(ModuleRuleInput input) check;
}

/// The module a [ModuleRule] checks.
final class ModuleRuleInput {
  /// Creates the input of a module rule.
  const ModuleRuleInput({
    required this.module,
    required this.contributions,
    this.presentRoles = const {},
  });

  /// The descriptor of the module.
  final ModuleDescriptor module;

  /// The contributions of the module and its variant that apply in this
  /// app, that is, whose [Contribution.when] roles are present.
  final List<Contribution> contributions;

  /// The roles present in the app.
  final Set<Role> presentRoles;
}
