import 'package:smf_contracts/lego.dart';

/// The module that manages the state of screens with Riverpod, without code
/// generation, and so provides the state management role.
///
/// It adds `flutter_riverpod` to the dependencies of the app and a
/// `ProviderScope` to the root wrappers of the app entry, so that `main()`
/// runs the app as:
///
/// ```dart
/// runApp(ProviderScope(child: const App()));
/// ```
///
/// Modules with screens support Riverpod through their variant for [id],
/// which brings the providers of their screens. A variant depends on
/// `flutter_riverpod` with the constraint `any`, so the version is the one
/// of this module.
///
/// The `ProviderScope` has to be above every widget that reads a provider,
/// not above every other widget. The root wrappers of the modules come in
/// the order of their contributions (see [SocketContribution]), the first
/// outermost, and a module comes after the providers of the roles it
/// requires and after the modules it depends on. By the rules of the module
/// model, a module uses the packages of another module only through its
/// variant for it, which makes the module require the role of that
/// provider, or by depending on it. So the root wrappers of a module that
/// uses Riverpod go inside the `ProviderScope`. The wrappers of the other
/// modules read no provider, and their place around it follows their ids.
final class RiverpodModule extends SmfModule {
  /// Creates the module.
  const RiverpodModule();

  /// The id of the module, by which other modules key their variants for
  /// Riverpod.
  static const id = ModuleId('riverpod');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Riverpod with flutter_riverpod',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(stateManagementRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [
        PubspecContribution.hosted('flutter_riverpod', '^3.4.3'),
        SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'ProviderScope(child: ',
            ')',
            imports: [
              ImportRef(
                'package:flutter_riverpod/flutter_riverpod.dart',
                show: ['ProviderScope'],
              ),
            ],
          ),
        ),
      ];
}
