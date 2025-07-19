import 'package:smf_contracts/src/generators/dsl_context.dart';

abstract interface class DslAwareCodeGenerator {
  Future<void> generateFromDsl(DslContext context);
}
