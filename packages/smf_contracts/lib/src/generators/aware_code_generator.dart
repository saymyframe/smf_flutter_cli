import 'package:smf_contracts/smf_contracts.dart';

abstract interface class DslAwareCodeGenerator {
  Future<List<GeneratedFile>> generateFromDsl(DslContext context);
}
