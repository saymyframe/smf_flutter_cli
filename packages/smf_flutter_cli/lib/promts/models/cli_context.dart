import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

class CliContext {
  const CliContext({
    required this.name,
    required this.selectedModules,
    required this.outputDirectory,
    required this.logger,
    this.packageName,
    this.initialRoute,
  });

  final String name;
  final List<IModuleCodeContributor> selectedModules;
  final String outputDirectory;
  final String? packageName;
  final String? initialRoute;
  final Logger logger;
}
