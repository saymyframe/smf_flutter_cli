import 'package:smf_contracts/smf_contracts.dart';

/// Which DI file the registrations of a [DiDependencyGroup] go to.
enum DiScope {
  /// The app-wide DI setup that the project runs at start-up, such as
  /// `lib/core/di/core_di.dart` with the get_it module.
  core,

  /// A DI file of the module itself, given by
  /// [DiDependencyGroup.pathToDiTemplate].
  module,
}

/// Dependencies that a module registers in the generated app's DI
/// container, with the imports they need.
///
/// Return these from [IModuleCodeContributor.di]. The DI module of the
/// project collects the groups of all selected modules and renders each one
/// into the file of its [scope].
class DiDependencyGroup {
  /// Creates a group of [diDependencies] registered in [scope].
  ///
  /// A [DiScope.module] group must also set a non-blank [pathToDiTemplate],
  /// which an assert checks.
  DiDependencyGroup({
    required this.diDependencies,
    required this.scope,
    required this.imports,
    this.pathToDiTemplate,
  }) : assert(
          scope != DiScope.module ||
              pathToDiTemplate?.trim().isNotEmpty == true,
          'pathToDiTemplate must be provided and non-empty if scope is '
          'DiScope.module',
        );

  /// The registrations of this group.
  final List<DiDependency> diDependencies;

  /// Which DI file the registrations are generated into.
  final DiScope scope;

  /// Imports that the registrations need, added to the same DI file.
  final List<Import> imports;

  /// Path of the module's DI template relative to the project root, for
  /// example `'lib/features/home/di/home_di.dart'`.
  ///
  /// Required for [DiScope.module] and ignored for [DiScope.core]. The module
  /// ships this file in its own brick, with the [MustacheSlots.imports] and
  /// [MustacheSlots.di] slots that receive the imports and registrations.
  /// Groups with the same path are rendered into one file.
  final String? pathToDiTemplate;
}
