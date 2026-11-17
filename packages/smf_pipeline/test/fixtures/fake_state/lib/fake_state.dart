/// Fake providers of the state management role, for the tests of the SMF
/// pipeline. Not modules to use.
///
/// Each follows the values that controllers of the app keep in a form of
/// its own, other than that of the state managers of the CLI: the generic
/// class of its bridges is in a brick, which a broken provider of the tests
/// can change, and its render hook writes a bridge for each value into a
/// file of its own in an app with such values.
library;

import 'package:fake_state/bundles/fake_bloc_state_bundle.dart';
import 'package:fake_state/bundles/fake_riverpod_state_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// A provider of the state management role that adds BLoC to the app, with
/// a cubit for each value that a controller of the app keeps, which a
/// widget reads with `context.watch`.
final class FakeBlocModule extends SmfModule {
  /// Creates the module.
  const FakeBlocModule();

  /// The id of the module.
  static const id = ModuleId('fake_bloc');

  /// The path of the file of the cubits, which the render hook writes.
  static const bridgesFile = 'lib/core/state/fixture_state_cubits.dart';

  /// The path of the file of the generic cubit, from the brick.
  static const listenableFile = 'lib/core/state/fixture_listenable_cubit.dart';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'State with BLoC (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [_FakeBlocProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeBlocStateBundle),
        const PubspecContribution.hosted('flutter_bloc', '^9.1.1'),
        stateManagementRole.data(const _FakeBlocBridges()),
      ];
}

/// A provider of the state management role that adds Riverpod to the app,
/// with its `ProviderScope` around the root widget, and with a provider for
/// each value that a controller of the app keeps, which a widget reads
/// with `ref.watch`.
final class FakeRiverpodModule extends SmfModule {
  /// Creates the module.
  const FakeRiverpodModule();

  /// The id of the module.
  static const id = ModuleId('fake_riverpod');

  /// The path of the file of the providers, which the render hook writes.
  static const bridgesFile = 'lib/core/state/fixture_state_providers.dart';

  /// The path of the file of the generic notifier, from the brick.
  static const listenableFile =
      'lib/core/state/fixture_listenable_notifier.dart';

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'State with Riverpod (fixture)',
        kind: ModuleKinds.infrastructure,
        providers: [_FakeRiverpodProvider()],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(fakeRiverpodStateBundle),
        const PubspecContribution.hosted('flutter_riverpod', '^3.0.0'),
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
        stateManagementRole.data(const _FakeRiverpodBridges()),
      ];
}

/// What the file of the fixture Riverpod imports of its own.
const _riverpodImports = [
  ImportRef(
    'package:flutter_riverpod/flutter_riverpod.dart',
    show: ['NotifierProvider'],
  ),
  ImportRef.app('core/state/fixture_listenable_notifier.dart'),
];

/// What the file of the fixture BLoC imports of its own.
const _blocImports = [
  ImportRef(
    'package:flutter/widgets.dart',
    show: ['BuildContext', 'StatelessWidget', 'Widget'],
  ),
  ImportRef(
    'package:flutter_bloc/flutter_bloc.dart',
    show: ['BlocProvider', 'MultiBlocProvider'],
  ),
  ImportRef.app('core/state/fixture_listenable_cubit.dart'),
];

/// The name of the bridge of [entry] in the file of the fixture Riverpod:
/// its name with `Bridge`, such as `themeModeBridge`.
String _riverpodBridgeOf(SharedState entry) => '${entry.name}Bridge';

/// The name of the bridge of [entry] in the file of the fixture BLoC: its
/// name in UpperCamelCase with `Bridge`, such as `ThemeModeBridge`.
String _blocBridgeOf(SharedState entry) =>
    '${entry.name[0].toUpperCase()}${entry.name.substring(1)}Bridge';

/// A widget reads a provider of the fixture Riverpod with `ref.watch`.
final class _FakeRiverpodBridges extends StateBridges {
  const _FakeRiverpodBridges();

  @override
  Fragment watch(SharedState entry, String child) => Fragment(
        'Consumer(builder: (context, ref, _) => '
        '($child)(ref.watch(bridges.${_riverpodBridgeOf(entry)})))',
        imports: const [
          ImportRef(
            'package:flutter_riverpod/flutter_riverpod.dart',
            show: ['Consumer'],
          ),
          ImportRef.app(
            'core/state/fixture_state_providers.dart',
            prefix: 'bridges',
          ),
        ],
      );
}

/// A widget reads a cubit of the fixture BLoC with `context.watch`.
final class _FakeBlocBridges extends StateBridges {
  const _FakeBlocBridges();

  @override
  Fragment watch(SharedState entry, String child) => Fragment(
        'Builder(builder: (context) => '
        '($child)(context.watch<bridges.${_blocBridgeOf(entry)}>().state))',
        imports: const [
          ImportRef('package:flutter/widgets.dart', show: ['Builder']),
          ImportRef('package:flutter_bloc/flutter_bloc.dart'),
          ImportRef.app(
            'core/state/fixture_state_cubits.dart',
            prefix: 'bridges',
          ),
        ],
      );
}

/// Writes the providers of the fixture Riverpod.
final class _FakeRiverpodProvider extends RoleProvider<StateData> {
  const _FakeRiverpodProvider();

  @override
  Role<StateData> get role => stateManagementRole;

  @override
  RoleOutput render(RoleHookInput<StateData> input) {
    final entries = [
      for (final entry in stateManagementRole.sharedStateIn(input)) entry.state,
    ];
    if (entries.isEmpty) return const RoleOutput();
    final code = SharedStateCode(entries, appName: input.context.appName);
    final bridges = [
      for (final state in entries) _riverpodBridge(state, code),
    ];
    return RoleOutput(
      files: {
        FakeRiverpodModule.bridgesFile: '''
// The bridges of the fixture Riverpod (fixture).
${code.directives(_riverpodImports).join('\n')}

${bridges.join('\n\n')}
''',
      },
    );
  }
}

/// The provider of [state], whose type and function [code] writes.
String _riverpodBridge(SharedState state, SharedStateCode code) {
  final type = code.typeOf(state);
  return [
    ...code.docOf(state),
    'final ${_riverpodBridgeOf(state)} =',
    '    NotifierProvider<FixtureListenableNotifier<$type>, $type>(',
    '  () => FixtureListenableNotifier(${code.functionOf(state)}),',
    ');',
  ].join('\n');
}

/// Writes the cubits of the fixture BLoC, and puts the widget that
/// provides them around the root of the app.
final class _FakeBlocProvider extends RoleProvider<StateData> {
  const _FakeBlocProvider();

  @override
  Role<StateData> get role => stateManagementRole;

  @override
  RoleOutput render(RoleHookInput<StateData> input) {
    final entries = [
      for (final entry in stateManagementRole.sharedStateIn(input)) entry.state,
    ];
    if (entries.isEmpty) return const RoleOutput();
    final code = SharedStateCode(entries, appName: input.context.appName);
    final bridges = [for (final state in entries) _blocBridge(state, code)];
    final providers = [
      for (final state in entries)
        '        BlocProvider(create: (_) => ${_blocBridgeOf(state)}()),',
    ];
    return RoleOutput(
      files: {
        FakeBlocModule.bridgesFile: '''
// The bridges of the fixture BLoC (fixture).
${code.directives(_blocImports).join('\n')}

${bridges.join('\n\n')}

/// Provides the bridges around the root of the app (fixture).
final class FixtureStateBridges extends StatelessWidget {
  /// Creates the widget around [child].
  const FixtureStateBridges({required this.child, super.key});

  /// The root of the app.
  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
      providers: [
${providers.join('\n')}
      ],
      child: child,
    );
}
''',
      },
      fragments: const [
        SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'FixtureStateBridges(child: ',
            ')',
            imports: [
              ImportRef.app(
                'core/state/fixture_state_cubits.dart',
                show: ['FixtureStateBridges'],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The cubit of [state], whose type and function [code] writes.
String _blocBridge(SharedState state, SharedStateCode code) {
  final bridge = _blocBridgeOf(state);
  final type = code.typeOf(state);
  return [
    ...code.docOf(state),
    'final class $bridge extends FixtureListenableCubit<$type> {',
    '  /// Creates the cubit (fixture).',
    '  $bridge() : super(${code.functionOf(state)}());',
    '}',
  ].join('\n');
}
