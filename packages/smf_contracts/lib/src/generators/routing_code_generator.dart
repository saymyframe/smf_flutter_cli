import 'package:smf_contracts/smf_contracts.dart';

/// Reserved marker interface for routing code generators.
///
/// It has no members and the CLI does not use it yet; routing modules
/// generate their code as a [DslAwareCodeGenerator].
abstract interface class RoutingCodeGenerator {}
