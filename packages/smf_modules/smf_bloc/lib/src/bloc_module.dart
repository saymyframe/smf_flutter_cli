import 'package:smf_bloc/src/agents.dart';
import 'package:smf_bloc/src/bridges.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// The module that manages the state of screens with BLoC, and so provides
/// the state management role.
///
/// It adds `flutter_bloc` to the dependencies of the app: BLoC needs no
/// start-up code. Modules with screens support BLoC through their variant
/// for [id], which creates the Cubits and Blocs of their screens and
/// provides them where the screens need them. A variant depends on
/// `flutter_bloc` with the constraint `any`, so the version is the one of
/// this module.
///
/// In an app whose controllers keep values that screens read, such as the
/// theme mode, its render hook gives each value a cubit in
/// `lib/core/state/shared_state_cubits.dart`, which follows the
/// `ValueListenable` of the value from its first read, and puts
/// `SharedStateCubits`, which provides them lazily, among the root
/// wrappers of the app entry. A widget reads such a cubit with
/// `context.watch`. The cubits are read-only: code changes a value through
/// its controller.
///
/// The section of the state management in the guide for coding agents of
/// the app has the note of the module: how a screen with state is written
/// with a cubit, where the state that several screens read is provided,
/// what a cubit minds after a call that it awaited, and that a widget
/// talks only to a cubit. In an app with such values, a second note tells
/// where their cubits are.
final class BlocModule extends SmfModule {
  /// Creates the module.
  const BlocModule();

  /// The id of the module, by which other modules key their variants for
  /// BLoC.
  static const id = ModuleId('bloc');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'BLoC with flutter_bloc',
        kind: ModuleKinds.infrastructure,
        providers: [BlocStateProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        const PubspecContribution.hosted('flutter_bloc', '^9.1.1'),
        AppEntryRole.agentSections.entry(
          stateManagementRole.description,
          AgentNote(agentNote),
        ),
        stateManagementRole.data(const BlocBridges()),
      ];
}
