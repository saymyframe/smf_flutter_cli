import 'package:meta/meta.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contracts/src/roles/symbol_uses.dart';

part 'state_management/state_dsl.dart';
part 'state_management/state_rules.dart';
part 'state_management/state_template.dart';

/// The state management role; see [StateManagementRole].
const stateManagementRole = StateManagementRole._();

/// The role of the library that holds the state of screens, such as BLoC or
/// Riverpod.
///
/// The screens of a feature use the library directly. A feature supports
/// several libraries through [Variants] of this role, keyed by the id of
/// the provider module, and the provider adds what the library needs to the
/// app, such as Riverpod's `ProviderScope` around the root widget.
///
/// The role also follows the values that the controllers of the app keep
/// and that screens read, such as the theme mode of the theme role or the
/// session of the auth role. A module or the template of a role that keeps
/// such a value feeds the role (see [ModuleDescriptor.feeds] and
/// [Role.feeds]) with a [SharedState], an entry: its name, the function of
/// a file of the app that returns the controller as a `ValueListenable`,
/// the type of the value, and a description. [sharedStateIn] has the
/// entries of an app. The data applies only where the role is present, so
/// the feeder renders the same files with or without a state manager.
///
/// A provider gives the app a bridge for each entry, in a file of its own
/// that its render hook writes only in an app with entries: a value of the
/// state manager that follows the listenable of the entry, from its first
/// read until the end of the app, such as a `NotifierProvider` that a
/// widget reads with `ref.watch`, or a `Cubit` that it reads with
/// `context.watch`. It names the bridge after the entry, such as
/// `themeModeProvider` or `ThemeModeCubit` for the entry `themeMode`, and
/// gives it the description of the entry as its doc. A bridge is
/// read-only: code changes the value only through the controller, which
/// the description names, and the controller saves it where it does. The
/// provider imports the file of each type and function with a prefix of
/// its own, such as `state0`, so the names of two feeders never clash with
/// each other or with the names of the provider. It gives the role
/// [StateBridges] once, which tells code that knows only the role how a
/// widget follows a bridge.
///
/// The rule `state_management.listenable_functions` checks the function of
/// each entry, and `state_management.bridges_rendered` that the files of
/// the provider call or tear off the function of every entry, so the tests
/// of a feeder check its entry through [sharedStateIn], not in the files of
/// a provider. Whether a bridge follows its listenable as the value
/// changes is for a test of the role in running apps.
///
/// The template of the role checks the entries of the templates of roles
/// and the entries of two owners with one name, and gives the note of the
/// role in the guide for coding agents. A provider tells in a note of its
/// own where its bridges are and how a widget reads one.
final class StateManagementRole extends Role<StateData> {
  const StateManagementRole._();

  @override
  String get id => 'state_management';

  @override
  String get description => 'State management';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  RoleTemplate<StateData> get template => const _StateManagementTemplate();

  @override
  List<ModuleRule<StateData>> get moduleRules => const [
        ModuleRule(
          id: 'state_management.shared_state',
          description: 'The entries of a module have names in lowerCamelCase '
              'of two words or more that start with the id of the module in '
              'lowerCamelCase, each once, a function in a file of the app, a '
              'type, and a description of one line of at most 100 '
              'characters. Only a provider of the role gives it StateBridges, '
              'exactly once.',
          check: _checkSharedState,
        ),
      ];

  @override
  List<StructuralRule<StateData>> get structuralRules => const [
        StructuralRule(
          id: 'state_management.listenable_functions',
          description: 'The function of every entry is a top-level function '
              'of its file that takes no arguments and returns a '
              'ValueListenable of the type of the entry.',
          check: _checkListenableFunctions,
        ),
        StructuralRule(
          id: 'state_management.bridges_rendered',
          description: 'The files of the provider of the role call or tear '
              'off the function of every entry.',
          check: _checkBridgesRendered,
        ),
      ];

  /// The entries of the app in [input], the input of a hook of this role,
  /// of its provider, or of a role that requires or uses this role: those
  /// of the modules, in the order the modules were selected, and then those
  /// of the templates of roles. The entries of one owner keep its order.
  ///
  /// A provider renders a bridge for each, in this order.
  List<AppSharedState> sharedStateIn(RoleHookInput<Object> input) => [
        for (final data in dataIn(input))
          if (data.value case final SharedState state)
            // Every data that a hook gets has an origin.
            AppSharedState._(_ownerOf(data.origin!), state),
      ];

  /// What the provider of the role in [input], the input of a hook of this
  /// role, of its provider, or of a role that requires or uses this role,
  /// gives the role to tell how a widget follows a bridge, or `null` when
  /// it gives none, which the module rule of the role reports.
  StateBridges? bridgesIn(RoleHookInput<Object> input) => [
        for (final data in dataIn(input))
          if (data.value case final StateBridges bridges) bridges,
      ].firstOrNull;
}
