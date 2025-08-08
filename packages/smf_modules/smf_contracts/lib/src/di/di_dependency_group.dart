import 'package:smf_contracts/smf_contracts.dart';

enum DiScope { core, module }

class DiDependencyGroup {
  DiDependencyGroup({
    required this.diDependencies,
    required this.scope,
    required this.imports,
    this.pathToDiTemplate,
  }) : assert(
         scope != DiScope.module || pathToDiTemplate?.trim().isNotEmpty == true,
         'pathToDiTemplate must be provided and non-empty if scope is DiScope.module',
       );

  final List<DiDependency> diDependencies;
  final DiScope scope;
  final List<Import> imports;
  final String? pathToDiTemplate;
}
