/// Roles with mode options and the modules of synthetic registries with
/// them, for the tests of the matrix: no module of `smf create` has to
/// provide such a role for the matrix to build the apps of its values.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

/// A role that an app has at most one provider of, with the mode options
/// [options] (see [RoleOption.mode]).
///
/// Its choice is the value of each of its options, the one given or the
/// first, which [modeIn] reads for an app of the matrix, as a test of the
/// apps reads what a role chose. In a terminal it asks for each value that
/// no option gives, as a role of `smf create` does, so the contract harness
/// answers its question.
final class ModeRole extends Role<Object> {
  /// Creates the role [id] with the mode options [options].
  const ModeRole(this.id, this.options);

  @override
  final String id;

  @override
  final List<RoleOption> options;

  @override
  String get description => '${id[0].toUpperCase()}${id.substring(1)}';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  RoleTemplate<Object> get template => _ModeTemplate(options);

  /// The value of the option [name] that the role chose for the app of
  /// [hook], the data and choices of its roles.
  String modeIn(RoleHookRequest hook, String name) {
    final values = (hookInput(hook).choice! as String).split(',');
    return values[options.indexWhere((option) => option.name == name)];
  }
}

/// Chooses a value for each of [options]: the one given, or else the first
/// in a run without a terminal and the answer to its question in a
/// terminal, where it offers the first value first.
final class _ModeTemplate extends RoleTemplate<Object> {
  const _ModeTemplate(this.options);

  final List<RoleOption> options;

  @override
  Future<Object?> choose(RoleChoiceContext<Object> context) async {
    final environment = context.environment;
    final values = <String>[];
    for (final option in options) {
      final allowed = option.allowed!;
      values.add(
        context.option(option.name) ??
            (environment.interactive
                ? await environment.prompter.select(
                    'Which value of --${option.name}?',
                    allowed,
                    defaultValue: allowed.first,
                  )
                : allowed.first),
      );
    }
    return values.join(',');
  }

  @override
  Map<String, String> optionsOf(Object? choice) {
    final values = (choice! as String).split(',');
    return {
      for (final (index, option) in options.indexed) option.name: values[index],
    };
  }
}

/// The kind of the modules of the synthetic registries.
const _kind = ModuleKind(id: 'synthetic', label: 'Synthetic');

/// A module [id] that provides [provides] and depends on [dependsOn], and
/// contributes nothing.
final class ModeModule extends SmfModule {
  /// Creates the module [id].
  const ModeModule(
    this.id, {
    this.provides = const {},
    this.dependsOn = const {},
  });

  /// The id of the module.
  final ModuleId id;

  /// The roles that the module provides.
  final Set<Role> provides;

  /// The modules that the module depends on.
  final Set<ModuleId> dependsOn;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'Synthetic',
        kind: _kind,
        dependsOn: dependsOn,
        providers: [for (final role in provides) RoleProvider.plain(role)],
      );
}

/// The mode option `--access` of [doors]: `members`, the default, `guests`
/// or `anyone`.
const access = RoleOption.mode(
  name: 'access',
  help: 'Who may use the app.',
  values: ['members', 'guests', 'anyone'],
);

/// A role with the mode option [access], which `lock` provides.
const doors = ModeRole('doors', [access]);

/// The mode option `--chime` of [bells]: `on`, the default, or `off`.
const chime = RoleOption.mode(
  name: 'chime',
  help: 'Whether the bells of the app ring.',
  values: ['on', 'off'],
);

/// A second role with a mode option, [chime], which `tower` provides.
const bells = ModeRole('bells', [chime]);

/// A role without options that takes one provider, `oak` or `pine`.
const wood = ModeRole('wood', []);

/// The provider of [doors].
const lock = ModeModule(ModuleId('lock'), provides: {doors});

/// The provider of [bells].
const tower = ModeModule(ModuleId('tower'), provides: {bells});

/// The first provider of [wood].
const oak = ModeModule(ModuleId('oak'), provides: {wood});

/// The second provider of [wood].
const pine = ModeModule(ModuleId('pine'), provides: {wood});

/// A registry with the app entry of flutter_core, the doors, whose mode
/// option has three values, and the two providers of the wood: two apps
/// with every module, each once more for each of the two other values of
/// the option.
const List<SmfModule> doorsOfWood = [FlutterCoreModule(), lock, oak, pine];
