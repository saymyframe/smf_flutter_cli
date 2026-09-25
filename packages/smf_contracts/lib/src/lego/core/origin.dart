import 'package:meta/meta.dart';
import 'package:smf_contracts/lego_core.dart';

/// Who contributed something to the app: a module, the template of a role,
/// or the pipeline itself.
///
/// The pipeline records an origin for every contribution. It orders the
/// fragments of a socket by their origins, attributes imports and generated
/// files to them, and names them in error messages. Role hooks see the origin
/// of every [RoleData] they receive.
@immutable
sealed class ContributionOrigin {
  const ContributionOrigin();
}

/// A contribution of a module, possibly from one of its [Variants].
@immutable
final class ModuleOrigin extends ContributionOrigin {
  /// Creates the origin of a contribution of [module], made by its variant
  /// for the provider [variant] if that is set.
  const ModuleOrigin(this.module, {this.variant});

  /// The contributing module.
  final ModuleId module;

  /// The provider the contributing variant of [module] is for, or `null` if
  /// the module contributed it directly.
  final ModuleId? variant;

  @override
  bool operator ==(Object other) =>
      other is ModuleOrigin &&
      other.module == module &&
      other.variant == variant;

  @override
  int get hashCode => Object.hash(module, variant);

  @override
  String toString() => variant == null ? '$module' : '$module ($variant)';
}

/// A contribution of the template of a role, which the pipeline treats as a
/// pseudo-owner named `role:<id>`.
@immutable
final class RoleTemplateOrigin extends ContributionOrigin {
  /// Creates the origin of a contribution of the template of [role].
  const RoleTemplateOrigin(this.role);

  /// The role whose template contributed.
  final Role role;

  @override
  bool operator ==(Object other) =>
      other is RoleTemplateOrigin && identical(other.role, role);

  @override
  int get hashCode => identityHashCode(role);

  @override
  String toString() => 'role:${role.id}';
}

/// A contribution of the pipeline itself, such as the `build_runner`
/// dependency it adds for a [CodegenRequest].
@immutable
final class PipelineOrigin extends ContributionOrigin {
  /// Creates the origin of a contribution of the pipeline.
  const PipelineOrigin();

  @override
  bool operator ==(Object other) => other is PipelineOrigin;

  @override
  int get hashCode => (PipelineOrigin).hashCode;

  @override
  String toString() => 'pipeline';
}
