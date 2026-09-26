import 'package:smf_contracts/lego.dart';

/// The module that manages the state of screens with BLoC, and so provides
/// the state management role.
///
/// It adds `flutter_bloc` to the dependencies of the app, and nothing else:
/// BLoC needs neither a widget around the app nor start-up code. Modules
/// with screens support BLoC through their variant for [id], which creates
/// the Cubits and Blocs of their screens and provides them where the screens
/// need them. A variant depends on `flutter_bloc` with the constraint `any`,
/// so the version is the one of this module.
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
        providers: [RoleProvider.plain(stateManagementRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      const [PubspecContribution.hosted('flutter_bloc', '^9.1.1')];
}
