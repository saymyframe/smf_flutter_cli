import 'package:smf_contracts/smf_contracts.dart';

/// A module that generates code from the DSL declared by all selected
/// modules.
///
/// Implement it on the module's [IModuleCodeContributor] class: the CLI
/// looks for it among the selected module instances. After bricks and shared
/// file contributions are applied, the CLI calls [generateFromDsl] on every
/// such module with the routes, DI groups and shells of all selected
/// modules. This is how, for example, a routing module turns the
/// [RouteGroup]s of every module into one router while the modules stay
/// unaware of each other.
// ignore: one_member_abstracts, modules implement this interface.
abstract interface class DslAwareCodeGenerator {
  /// Generates files from the DSL in [context].
  ///
  /// The CLI writes every returned [GeneratedFile], replacing any existing
  /// file. Typically these are templates from the module's own brick with
  /// their [MustacheSlots] filled in.
  Future<List<GeneratedFile>> generateFromDsl(DslContext context);
}
