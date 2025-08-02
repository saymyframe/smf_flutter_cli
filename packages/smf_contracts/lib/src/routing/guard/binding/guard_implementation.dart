import 'package:smf_contracts/smf_contracts.dart';

abstract class GuardImplementation {
  const GuardImplementation({required this.code, this.imports = const []});

  final String code;
  final List<Import> imports;
}
