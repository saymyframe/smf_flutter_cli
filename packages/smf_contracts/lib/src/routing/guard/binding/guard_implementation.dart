import 'package:smf_contracts/src/routing/import/import.dart';

abstract class GuardImplementation {
  const GuardImplementation({required this.code, this.imports = const []});

  final String code;
  final List<RouteImport> imports;
}
