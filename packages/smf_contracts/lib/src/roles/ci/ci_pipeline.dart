part of '../ci.dart';

/// The characters of an argument that a POSIX shell takes as they are, in any
/// place of a word but the first of a command.
final RegExp _plainWord = RegExp(r'^[A-Za-z0-9_@%+=:,./-]+$');

/// [argument] as one word of a POSIX shell: as it is, or in single quotes,
/// inside which the shell reads every character as it is but a single quote.
String _shellWord(String argument) => _plainWord.hasMatch(argument)
    ? argument
    : "'${argument.replaceAll("'", r"'\''")}'";

/// A command of CI: the text of a line of a POSIX shell, and a [name] that a
/// provider may show for its step.
@immutable
final class CiCommand {
  const CiCommand._(this.name, this.command);

  /// What the command does, as a host may name a step, such as `Analyze`.
  final String name;

  /// The command, as it runs at the root of the repository.
  final String command;
}

/// A text with the name of an environment inside it, such as the command that
/// builds the app for that environment.
@immutable
final class CiPerEnvironment {
  const CiPerEnvironment._(this._before, this._after);

  final String _before;
  final String _after;

  /// The text for [environment]: a name of [CiBuild.environments], or what
  /// stands for one in the format of a provider, such as a reference to a
  /// variable that the job has.
  String of(String environment) => '$_before$environment$_after';
}

/// The build of the app for an environment, which a developer asks for.
@immutable
final class CiBuild {
  const CiBuild._({
    required this.environments,
    required this.prepare,
    required this.keys,
    required this.name,
    required this.command,
    required this.artifact,
  });

  /// The environments that a developer can choose, which are the names of
  /// [AppEntryRole.flavors]. The first is the default.
  final List<String> environments;

  /// What runs before [command], in this order.
  final List<CiCommand> prepare;

  /// The names of the keys of [EnvRole.keysIn], each of which [prepare] reads
  /// from the variable of the process of that name.
  final List<String> keys;

  /// What the build does, as a host may name a step.
  final String name;

  /// The command that builds the app for an environment.
  final CiPerEnvironment command;

  /// The path of the file that [command] writes for an environment.
  final CiPerEnvironment artifact;
}

/// What CI of an app runs; see [CiRole].
@immutable
final class CiPipeline {
  const CiPipeline._({required this.checks, required this.build});

  /// What runs on each push, in this order.
  final List<CiCommand> checks;

  /// What runs on request, for one environment.
  final CiBuild build;
}
