import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/errors.dart';
import 'package:smf_pipeline/src/host.dart';
import 'package:smf_pipeline/src/pipeline.dart';
import 'package:smf_pipeline/src/postgen.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/request.dart';
import 'package:smf_pipeline/src/shell.dart';

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

  /// The user cancelled the run, as with Ctrl-C: 128 plus the number of
  /// `SIGINT`, as shells report a command that Ctrl-C stopped.
  static const cancelled = 130;
}

/// Creates the host of a run, which may report more with [verbose].
typedef SmfHostFactory = SmfHost Function({required bool verbose});

/// Runs the `smf` command line with [arguments] and returns its exit code;
/// see [SmfExitCodes].
///
/// The command `create` generates an app from [modules], with the options
/// of their roles; see [CreatePipeline]. [hostFor] creates the machine of
/// the run once the flag `--verbose` is known, which comes before the
/// command or after `create`. With [version], `--version` prints it, then
/// runs the command, if one is given. Help is wrapped at [usageLineLength],
/// such as the width of the terminal. [onCreated] gets every app that
/// `create` generated, after the report of the run.
///
/// Every error is reported through the host's logger and becomes an exit
/// code: a usage error of the command line or of a module's choice is 64, a
/// failed generation is 1, a run the user cancelled is 130, and anything
/// else, which is a bug, is 70. So are [modules] that break the rules of the
/// registry; see [ModuleRegistry].
Future<int> runSmf(
  List<String> arguments, {
  required List<SmfModule> modules,
  required SmfHostFactory hostFor,
  String executableName = 'smf',
  String? version,
  int? usageLineLength,
  void Function(GeneratedApp app)? onCreated,
}) async {
  final registry = _registryOf(modules, executableName, hostFor);
  if (registry == null) return SmfExitCodes.software;

  late final SmfHost host;
  final runner = _Runner(executableName, () => host.logger, usageLineLength)
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
  runner.addCommand(
    _CreateCommand(registry, () => host, onCreated, usageLineLength),
  );

  final ArgResults results;
  try {
    results = runner.parse(arguments);
  } on UsageException catch (error) {
    host = hostFor(verbose: false);
    return _usageError(host.logger, error.message, error.usage);
  }
  final command = results.command;
  final verbose = _isVerbose(results);
  host = hostFor(verbose: verbose);
  final logger = host.logger;
  try {
    if (version != null && results.flag('version')) {
      logger.info(version);
      if (command == null) return SmfExitCodes.success;
    }
    return await runner.runCommand(results) ?? SmfExitCodes.success;
  } on UsageException catch (error) {
    return _usageError(logger, error.message, error.usage);
  } on SmfUsageException catch (error) {
    return _usageError(logger, error.message);
  } on GenerationFailedException catch (error) {
    return _generationFailed(logger, error);
  } on SmfCancelledException {
    logger.info('Cancelled. No app was created.');
    return SmfExitCodes.cancelled;
  } on Object catch (error, stackTrace) {
    logger
      ..error('$executableName stopped because of an unexpected error: $error')
      ..detail('$stackTrace');
    if (!verbose) {
      logger.info('Run it again with --verbose for the full log.');
    }
    return SmfExitCodes.software;
  }
}

/// The registry of [modules], or `null` after reporting that they break its
/// rules, which is a bug of [executableName].
ModuleRegistry? _registryOf(
  List<SmfModule> modules,
  String executableName,
  SmfHostFactory hostFor,
) {
  try {
    return ModuleRegistry(modules);
  } on RegistryException catch (error) {
    final logger = hostFor(verbose: false).logger
      ..error(
        'The modules of $executableName break the rules of the registry, '
        'which is a bug:',
      );
    for (final problem in error.problems) {
      logger.error('  $problem');
    }
    return null;
  }
}

/// Whether [results] have the flag `--verbose`, before the command or after
/// it.
bool _isVerbose(ArgResults results) {
  final command = results.command;
  return results.flag('verbose') ||
      (command != null &&
          command.options.contains('verbose') &&
          command.flag('verbose'));
}

/// Reports [error], a generation that failed, with its issues, and returns
/// the exit code of it.
int _generationFailed(SmfLogger logger, GenerationFailedException error) {
  logger.error(error.message);
  for (final issue in error.issues) {
    logger.error('  $issue');
  }
  return SmfExitCodes.generationFailed;
}

int _usageError(SmfLogger logger, String message, [String? usage]) {
  logger.error(message);
  if (usage != null) logger.info('\n$usage');
  return SmfExitCodes.usage;
}

/// The runner of the `smf` commands, which prints help through the host's
/// logger.
final class _Runner extends CommandRunner<int> {
  _Runner(String executableName, this._logger, int? usageLineLength)
      : super(
          executableName,
          'Generates Flutter apps from independent modules.',
          usageLineLength: usageLineLength,
        );

  final SmfLogger Function() _logger;

  @override
  void printUsage() => _logger().info(usage);
}

/// `smf create`.
final class _CreateCommand extends Command<int> {
  _CreateCommand(
    this._registry,
    this._host,
    this._onCreated,
    int? usageLineLength,
  ) : argParser = ArgParser(usageLineLength: usageLineLength) {
    CreateOptions.addTo(argParser, _registry.roles);
    // `--verbose` is global; it is accepted after the command too.
    argParser.addFlag('verbose', negatable: false, hide: true);
  }

  final ModuleRegistry _registry;
  final SmfHost Function() _host;
  final void Function(GeneratedApp app)? _onCreated;

  @override
  final ArgParser argParser;

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
    final CreateRequest request;
    try {
      request = CreateRequest.fromArgs(argResults!, _registry.roles);
    } on SmfUsageException catch (error) {
      usageException(error.message);
    }
    final app =
        await CreatePipeline(registry: _registry, host: host).run(request);
    if (app != null) {
      _report(app, host);
      _onCreated?.call(app);
    }
    return SmfExitCodes.success;
  }

  /// Tells the user what came out, what is missing and what to run later.
  ///
  /// Only what went wrong is a warning: a module that was left out, and a
  /// step that could not run or failed. The steps that were left for later,
  /// as the user or the options of the run asked, come after the line of
  /// the app as a list; see [_leftForLater].
  void _report(GeneratedApp app, SmfHost host) {
    final logger = host.logger;
    if (app.leftOut.isNotEmpty) {
      logger.warn(
        'The app is without ${app.leftOut.map((m) => m.module).join(', ')}, '
        'which could not work; see above. With --${CreateOptions.strict}, '
        'such a problem stops the run instead.',
      );
    }
    final later = <SkippedStep>[];
    for (final step in app.skippedSteps) {
      if (!step.failed) {
        later.add(step);
        continue;
      }
      final notice = step.notice;
      logger.warn(
        '${step.description} is not done, because ${step.reason}. Run it '
        'in the app: ${step.command}'
        // On a line of its own, since nothing else ends the command.
        '${notice == null ? '' : '\n$notice'}',
      );
    }
    logger.success('Created ${app.name} in ${app.path}.');
    if (later.isNotEmpty) logger.info(_leftForLater(later));
    logger.info(
      // After the steps, since the run does not know which of them the app
      // needs to start.
      '${later.isEmpty ? 'Run it' : 'Then run the app'}:\n'
      '  cd ${shellQuoted(app.path, host.operatingSystem)}\n'
      '  flutter run',
    );
  }
}

/// The list of [steps], which the run left for later, in the order in which
/// they run: each with why it is left, its command on a line of its own,
/// whole, since the user copies it, and its notice below the command. Several
/// steps are numbered.
String _leftForLater(List<SkippedStep> steps) {
  final numbered = steps.length > 1;
  final lines = [
    if (numbered)
      '${steps.length} steps are left for later. Run them in the app, in '
          'this order:'
    else
      'One step is left for later. Run it in the app:',
  ];
  for (final (index, step) in steps.indexed) {
    final mark = numbered ? '${index + 1}. ' : '';
    final below = ' ' * (numbered ? 2 + mark.length : 4);
    // A step that was left with a step of the list names that step by its
    // number, which tells two steps of one description apart. The step that
    // it continues may also have failed: then a warning told of it, and the
    // reason names it by its description.
    final after = step.after;
    final place = after == null ? -1 : steps.indexOf(after);
    final reason = place < 0 ? step.reason : 'it runs after step ${place + 1}';
    final notice = step.notice;
    lines.addAll([
      '  $mark${step.description} ($reason):',
      '$below${step.command}',
      if (notice != null) '$below$notice',
    ]);
  }
  return lines.join('\n');
}
