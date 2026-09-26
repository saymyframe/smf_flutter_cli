/// Fake providers of the state management role, for the tests of the SMF
/// pipeline. Not modules to use.
library;

import 'package:smf_contracts/lego.dart';

/// A provider of the state management role that adds BLoC to the app.
final class FakeBlocModule extends SmfModule {
  /// Creates the module.
  const FakeBlocModule();

  /// The id of the module.
  static const id = ModuleId('fake_bloc');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'State with BLoC (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(stateManagementRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      const [PubspecContribution.hosted('flutter_bloc', '^9.1.1')];
}

/// A provider of the state management role that adds Riverpod to the app,
/// with its `ProviderScope` around the root widget.
final class FakeRiverpodModule extends SmfModule {
  /// Creates the module.
  const FakeRiverpodModule();

  /// The id of the module.
  static const id = ModuleId('fake_riverpod');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'State with Riverpod (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(stateManagementRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [
        PubspecContribution.hosted('flutter_riverpod', '^3.0.0'),
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
