import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

enum StrictMode { strict, lenient }

/// Execution context passed across generators and hooks.
class CliContext {
  /// Creates a new [CliContext].
  const CliContext({
    required this.name,
    required this.selectedModules,
    required this.outputDirectory,
    required this.logger,
    required this.strictMode,
    this.packageName,
    this.initialRoute,
  });

  /// Human-readable project name.
  final String name;

  /// Modules selected by the user for inclusion.
  final List<IModuleCodeContributor> selectedModules;

  /// Absolute path where files will be generated.
  final String outputDirectory;

  /// Optional organization/package name used in identifiers.
  final String? packageName;

  /// Optional initial route for the application.
  final String? initialRoute;

  /// Logger for interactive feedback and diagnostics.
  final Logger logger;

  /// Strictness mode for generation behavior (errors vs warnings).
  final StrictMode strictMode;
}
