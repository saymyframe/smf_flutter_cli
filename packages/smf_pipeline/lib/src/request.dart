import 'package:args/args.dart';
import 'package:smf_contracts/lego_core.dart';

/// What to do when the target directory of the app already exists and is
/// not empty.
enum OnConflict {
  /// Ask the user, which needs an interactive run.
  prompt,

  /// Replace the directory once the app has been generated.
  replace,

  /// Generate the app into a new directory next to it.
  copy,

  /// Stop without generating anything.
  cancel,
}

/// The options of the `create` command.
///
/// The options of the roles in the registry are added next to them, so
/// their names must differ from these; see [names].
abstract final class CreateOptions {
  /// `-m`, `--modules`: the modules to add, separated by commas.
  static const modules = 'modules';

  /// `--org`: the organization in reverse domain notation.
  static const org = 'org';

  /// `-o`, `--output`: the directory to create the app in.
  static const output = 'output';

  /// `--on-conflict`: what to do if the app's directory exists.
  static const onConflict = 'on-conflict';

  /// `--strict`: fail instead of leaving out modules that cannot work.
  static const strict = 'strict';

  /// `--explain`: print what would happen and stop.
  static const explain = 'explain';

  /// `--skip-external-setup`: never install tools, log in or configure
  /// external services; print instructions instead.
  static const skipExternalSetup = 'skip-external-setup';

  /// `--[no-]input`: whether the run may ask the user.
  static const input = 'input';

  /// `--[no-]dart-fix`: whether to run the full `dart fix` on the app;
  /// hidden, for CI, which checks the generated code as it is.
  static const dartFix = 'dart-fix';

  /// The names of all options of the command, which role options must not
  /// take.
  static const Set<String> names = {
    modules,
    org,
    output,
    onConflict,
    strict,
    explain,
    skipExternalSetup,
    input,
    dartFix,
  };

  /// Adds the options of the command and the options of [roles] to
  /// [parser].
  static void addTo(ArgParser parser, Iterable<Role> roles) {
    parser
      ..addOption(
        modules,
        abbr: 'm',
        valueHelp: 'module,module',
        help: 'The modules to add, separated by commas. Modules they need '
            'are added too.',
      )
      ..addOption(
        org,
        valueHelp: 'com.example',
        help: 'The organization in reverse domain notation; it starts the '
            'application id.',
      )
      ..addOption(
        output,
        abbr: 'o',
        valueHelp: 'directory',
        defaultsTo: '.',
        help: "The directory to create the app's own directory in.",
      )
      ..addOption(
        onConflict,
        allowed: [for (final value in OnConflict.values) value.name],
        allowedHelp: {
          OnConflict.prompt.name: 'Ask, in a terminal.',
          OnConflict.replace.name:
              'Replace the directory once the app is generated.',
          OnConflict.copy.name: 'Create the app next to it.',
          OnConflict.cancel.name: 'Generate nothing and exit with code 1.',
        },
        defaultsTo: OnConflict.prompt.name,
        help: "What to do if the app's directory exists and is not empty.",
      )
      ..addFlag(
        strict,
        negatable: false,
        help: 'Fail instead of leaving out modules that cannot work.',
      )
      ..addFlag(
        explain,
        negatable: false,
        help: 'Print what would be generated and the state of the machine, '
            'then stop without changing anything.',
      )
      ..addFlag(
        skipExternalSetup,
        negatable: false,
        help: 'Never install tools, log in or configure external services; '
            'print what to run instead.',
      )
      ..addFlag(
        input,
        defaultsTo: true,
        help: 'Ask questions in the terminal. With --no-input, everything '
            'comes from the options.',
      )
      ..addFlag(dartFix, defaultsTo: true, hide: true);
    for (final role in roles) {
      for (final option in role.options) {
        parser.addOption(
          option.name,
          help: option.help,
          valueHelp: option.valueHelp,
          allowed: option.allowed,
        );
      }
    }
  }
}

/// The command line of `smf create`, parsed.
final class CreateRequest {
  /// Creates the request.
  const CreateRequest({
    this.appName,
    this.org,
    this.outputDirectory = '.',
    this.onConflict = OnConflict.prompt,
    this.strict = false,
    this.explain = false,
    this.skipExternalSetup = false,
    this.input = true,
    this.dartFix = true,
    this.modules,
    this.roleOptions = const {},
  });

  /// Parses [results] of a parser set up with [CreateOptions.addTo] for
  /// [roles].
  ///
  /// Throws an [SmfUsageException] for more than one app name or for a
  /// module name that is not a valid id.
  factory CreateRequest.fromArgs(ArgResults results, Iterable<Role> roles) {
    if (results.rest.length > 1) {
      throw SmfUsageException(
        'Give one app name, not ${results.rest.length}: '
        '${results.rest.join(' ')}.',
      );
    }
    return CreateRequest(
      appName: results.rest.firstOrNull,
      org: results.option(CreateOptions.org),
      outputDirectory: results.option(CreateOptions.output) ?? '.',
      onConflict: OnConflict.values.byName(
        results.option(CreateOptions.onConflict) ?? OnConflict.prompt.name,
      ),
      strict: results.flag(CreateOptions.strict),
      explain: results.flag(CreateOptions.explain),
      skipExternalSetup: results.flag(CreateOptions.skipExternalSetup),
      input: results.flag(CreateOptions.input),
      dartFix: results.flag(CreateOptions.dartFix),
      modules: switch (results.option(CreateOptions.modules)) {
        null => null,
        final value => parseModules(value),
      },
      roleOptions: {
        for (final role in roles)
          for (final option in role.options)
            if (results.wasParsed(option.name))
              option.name: results.option(option.name),
      },
    );
  }

  /// The name of the app as given, or `null` to ask for it.
  final String? appName;

  /// The organization as given, or `null` to ask for it or use the
  /// default.
  final String? org;

  /// The directory to create the app in.
  final String outputDirectory;

  /// What to do if the app's directory exists and is not empty.
  final OnConflict onConflict;

  /// Whether to fail instead of leaving out modules that cannot work.
  final bool strict;

  /// Whether to print what would happen and stop.
  final bool explain;

  /// Whether to skip installing tools and setting up external services.
  final bool skipExternalSetup;

  /// Whether the run may ask the user, if a terminal is attached.
  final bool input;

  /// Whether to run the full `dart fix` on the generated app.
  final bool dartFix;

  /// The modules given with `-m`, in order and without repeats, or `null`
  /// if the option was not given.
  final List<ModuleId>? modules;

  /// The values of the role options given on the command line, by option
  /// name.
  final Map<String, String?> roleOptions;

  /// Parses the value of `-m`: ids separated by commas, in order, without
  /// empty items and repeats.
  ///
  /// Throws an [SmfUsageException] for an item that is not a valid id.
  static List<ModuleId> parseModules(String value) {
    final ids = <ModuleId>[];
    for (final item in value.split(',')) {
      final name = item.trim();
      if (name.isEmpty) continue;
      if (!ModuleId.isValid(name)) {
        throw SmfUsageException(
          '"$name" is not a module name; module names are lower snake_case, '
          'such as go_router.',
        );
      }
      final id = ModuleId(name);
      if (!ids.contains(id)) ids.add(id);
    }
    return ids;
  }
}
