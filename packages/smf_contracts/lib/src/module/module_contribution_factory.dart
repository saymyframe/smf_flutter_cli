import 'package:smf_contracts/smf_contracts.dart';

/// Creates a module's [IModuleCodeContributor] for the project's
/// [ModuleProfile].
///
/// Every module provides a factory, registered in the CLI under the module's
/// [ModuleDescriptor.name] so that other modules' [ModuleDescriptor.dependsOn]
/// entries resolve to it. The factory lets a module offer variants, for
/// example one contributor per [StateManager], and decline profiles it
/// cannot generate for.
abstract interface class IModuleContributorFactory {
  /// Whether this module can be generated for [profile].
  ///
  /// When it returns `false`, strict mode stops generation with an error,
  /// while lenient mode skips the module with a warning. The CLI calls
  /// [create] only after this returns `true`.
  bool supports(ModuleProfile profile);

  /// Creates the module's contributor for [profile].
  IModuleCodeContributor create(ModuleProfile profile);
}
