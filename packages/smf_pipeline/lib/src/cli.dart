import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/pipeline.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/request.dart';

/// The exit codes of the `smf` command line.
abstract final class SmfExitCodes {
  /// The command did what it was asked, or printed help, the version or an
  /// explanation.
  static const success = 0;

  /// Generation failed; the messages say why.
  static const generationFailed = 1;

  /// The command line was wrong, like `EX_USAGE` of `sysexits.h`.
  static const usage = 64;

  /// An error that is a bug in the CLI or a module, like `EX_SOFTWARE` of
  /// `sysexits.h`.
  static const software = 70;
}

/// Creates the host of a run, which may report more with [verbose].
typedef SmfHostFactory = SmfHost Function({required bool verbose});

/// Runs the `smf` command line with [arguments] and returns its exit code;
/// see [SmfExitCodes].
///
/// The command `create` generates an app from the modules of [registry],
/// with the options of their roles; see [CreatePipeline]. [hostFor] creates
/// the machine of the run once the global flag `--verbose` is known. With
/// [version], `--version` prints it.
///
/// Every error is reported through the host's logger and becomes an exit
/// code: a usage error of the command line or of a module's choice is 64, a
/// failed generation is 1, and anything else, which is a bug, is 70.
Future<int> runSmf(
  List<String> arguments, {
  required ModuleRegistry registry,
  required SmfHostFactory hostFor,
  String executableName = 'smf',
  String? version,
}) async {
  late final SmfHost host;
  final runner = _Runner(executableName, () => host.logger)
    ..argParser.addFlag(
      'verbose',
      negatable: false,
      help: 'Report more of what happens.',
    );
  if (version != null) {
    runner.argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the version of $executableName.',
    );
  }
  runner.addCommand(_CreateCommand(registry, () => host));

  final ArgResults results;
  try {
    results = runner.parse(arguments);
  } on UsageException catch (error) {
    host = hostFor(verbose: false);
    return _usageError(host.logger, error.message, error.usage);
  }
  host = hostFor(verbose: results.flag('verbose'));
  final logger = host.logger;
  try {
    if (version != null && results.flag('version')) {
      logger.info(version);
      return SmfExitCodes.success;
    }
    return await runner.runCommand(results) ?? SmfExitCodes.success;
  } on UsageException catch (error) {
    return _usageError(logger, error.message, error.usage);
  } on SmfUsageException catch (error) {
    return _usageError(logger, error.message);
  } on GenerationFailedException catch (error) {
    logger.error(error.message);
    for (final issue in error.issues) {
      logger.error('  $issue');
    }
    return SmfExitCodes.generationFailed;
  } on Object catch (error, stackTrace) {
    logger
      ..error('$executableName stopped because of an unexpected error: $error')
      ..detail('$stackTrace');
    return SmfExitCodes.software;
  }
}

int _usageError(SmfLogger logger, String message, [String? usage]) {
  logger.error(message);
  if (usage != null) logger.info('\n$usage');
  return SmfExitCodes.usage;
}

/// The runner of the `smf` commands, which prints help through the host's
/// logger.
final class _Runner extends CommandRunner<int> {
  _Runner(String executableName, this._logger)
      : super(
          executableName,
          'Generates Flutter apps from independent modules.',
        );

  final SmfLogger Function() _logger;

  @override
  void printUsage() => _logger().info(usage);
}

/// `smf create`.
final class _CreateCommand extends Command<int> {
  _CreateCommand(this._registry, this._host) {
    CreateOptions.addTo(argParser, _registry.roles);
  }

  final ModuleRegistry _registry;
  final SmfHost Function() _host;

  @override
  String get name => 'create';

  @override
  String get description => 'Generates a Flutter app from modules.';

  @override
  String get invocation => '${runner!.executableName} create <app name>';

  @override
  void printUsage() => _host().logger.info(usage);

  @override
  Future<int> run() async {
    final host = _host();
    final request = CreateRequest.fromArgs(argResults!, _registry.roles);
    final app =
        await CreatePipeline(registry: _registry, host: host).run(request);
    if (app != null) _report(app, host.logger);
    return SmfExitCodes.success;
  }

  /// Tells the user what came out and what to run later.
  void _report(GeneratedApp app, SmfLogger logger) {
    for (final step in app.skippedSteps) {
      logger.warn(
        '${step.description} did not run, because ${step.reason}. Run it '
        'in the app later: ${step.command}',
      );
    }
    logger
      ..success('Created ${app.name} in ${app.path}.')
      ..info('Run it: cd ${_quoted(app.path)} && flutter run');
  }
}

String _quoted(String path) =>
    RegExp(r'^[A-Za-z0-9_./:\\-]+$').hasMatch(path) ? path : '"$path"';
