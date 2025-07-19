import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/generators/generator.dart';

/// The [DslGenerator] is responsible for invoking all registered [DslAwareCodeGenerator]
/// implementations with a unified [DslContext].
///
/// ### Architectural rationale:
/// Instead of relying on type checks like `if (generator is DiDslGenerator)`
/// and branching per-DSL, this class delegates responsibility to each module-specific
/// DSL generator by passing a shared context object.
///
/// This respects the Open/Closed Principle:
/// - New DSL types can be supported by creating new `DslAwareCodeGenerator` implementations.
/// - The [DslGenerator] class itself remains unchanged in its logic, only the context may evolve.
///
/// ### About [DslContext]:
/// [DslContext] acts as a container for all DSL-relevant data (e.g., DI dependencies, route definitions),
/// which are aggregated here. When a new DSL type is introduced, this is the only place
/// that needs minor adjustment—to enrich the context with the corresponding data.
///
/// While this may formally seem like a deviation from OCP, it's a deliberate trade-off
/// to avoid over-architecting via excessive abstractions (e.g., collectors, resolvers, or reflection),
/// which would reduce readability and traceability.
///
/// ### Summary:
/// This class balances architectural cleanliness and simplicity:
/// - No knowledge of individual DSL types
/// - Single-pass orchestration
/// - Localized and predictable evolution
///
/// This design is intentional, and avoids abstraction for its own sake.
class DslGenerator extends Generator {
  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {
    final dslGenerators = modules.whereType<DslAwareCodeGenerator>().toList();
    final context = DslContext(
      projectRootPath: generateTo,
      mustacheVariables: coreVars,
      logger: logger,
      diGroups: modules.map((m) => m.di).expand((e) => e).toList(),
    );

    for (final dslGenerator in dslGenerators) {
      await dslGenerator.generateFromDsl(context);
    }
  }
}
