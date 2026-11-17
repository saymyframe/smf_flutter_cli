import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_riverpod/src/agents.dart';
import 'package:smf_riverpod/src/bridges.dart';

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
///
/// In an app whose controllers keep values that screens read, such as the
/// theme mode, its render hook gives each value a `NotifierProvider` in
/// `lib/core/state/shared_state_providers.dart`, which follows the
/// `ValueListenable` of the value from its first read until the
/// `ProviderScope` disposes of it, and which a widget reads with
/// `ref.watch`. The providers are read-only: code changes a value through
/// its controller.
///
/// The section of the state management in the guide for coding agents of
/// the app has the note of the module: how a screen with state is written
/// with a provider, which provider holds the state that several screens
/// read, what a notifier minds around a call that it awaits, that a widget
/// talks only to providers, and that the scope stays above the widgets
/// that read them. In an app with such values, a second note tells where
/// their providers are.
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
        providers: [RiverpodStateProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        const PubspecContribution.hosted('flutter_riverpod', '^3.4.3'),
        const SocketContribution.wrap(
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
        AppEntryRole.agentSections.entry(
          stateManagementRole.description,
          AgentNote(agentNote),
        ),
        stateManagementRole.data(const RiverpodBridges()),
      ];
}
