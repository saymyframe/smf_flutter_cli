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

/// What the file of the fixture Riverpod takes of its library.
const _notifier = 'NotifierProvider';

/// What the file of the fixture BLoC takes of the widgets of Flutter.
const _widgets = 'BuildContext, StatelessWidget, Widget';

/// What the file of the fixture BLoC takes of its library.
const _bloc = 'BlocProvider, MultiBlocProvider';

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
    final entries = stateManagementRole.sharedStateIn(input);
    if (entries.isEmpty) return const RoleOutput();
    final appName = input.context.appName;
    final code = _Code(appName);
    final bridges = [
      for (final AppSharedState(:state) in entries)
        _riverpodBridge(state, code.typeOf(state), code.functionOf(state)),
    ];
    final imports = code.imports([
      "import 'package:flutter_riverpod/flutter_riverpod.dart' show $_notifier;",
      "import 'package:$appName/core/state/fixture_listenable_notifier.dart';",
    ]);
    return RoleOutput(
      files: {
        FakeRiverpodModule.bridgesFile: '''
// The bridges of the fixture Riverpod (fixture).
${imports.join('\n')}

${bridges.join('\n\n')}
''',
      },
    );
  }
}

/// The provider of [state], whose value has the type [type] and whose
/// listenable [function] returns.
String _riverpodBridge(SharedState state, String type, String function) => '''
/// ${state.description}
final ${_riverpodBridgeOf(state)} =
    NotifierProvider<FixtureListenableNotifier<$type>, $type>(
  () => FixtureListenableNotifier($function),
);''';

/// Writes the cubits of the fixture BLoC, and puts the widget that
/// provides them around the root of the app.
final class _FakeBlocProvider extends RoleProvider<StateData> {
  const _FakeBlocProvider();

  @override
  Role<StateData> get role => stateManagementRole;

  @override
  RoleOutput render(RoleHookInput<StateData> input) {
    final entries = stateManagementRole.sharedStateIn(input);
    if (entries.isEmpty) return const RoleOutput();
    final appName = input.context.appName;
    final code = _Code(appName);
    final bridges = [
      for (final AppSharedState(:state) in entries)
        _blocBridge(state, code.typeOf(state), code.functionOf(state)),
    ];
    final providers = [
      for (final AppSharedState(:state) in entries)
        '        BlocProvider(create: (_) => ${_blocBridgeOf(state)}()),',
    ];
    final imports = code.imports([
      "import 'package:flutter/widgets.dart' show $_widgets;",
      "import 'package:flutter_bloc/flutter_bloc.dart' show $_bloc;",
      "import 'package:$appName/core/state/fixture_listenable_cubit.dart';",
    ]);
    return RoleOutput(
      files: {
        FakeBlocModule.bridgesFile: '''
// The bridges of the fixture BLoC (fixture).
${imports.join('\n')}

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
            imports: [ImportRef.app('core/state/fixture_state_cubits.dart')],
          ),
        ),
      ],
    );
  }
}

/// The cubit of [state], whose value has the type [type] and whose
/// listenable [function] returns.
String _blocBridge(SharedState state, String type, String function) => '''
/// ${state.description}
final class ${_blocBridgeOf(state)} extends FixtureListenableCubit<$type> {
  /// Creates the cubit (fixture).
  ${_blocBridgeOf(state)}() : super($function());
}''';

/// The code of the bridges of an app: the type and the function of each
/// entry, through an import of each library with a prefix of its own.
final class _Code {
  _Code(this._appName);

  final String _appName;

  /// The prefixes of the libraries, by their URIs.
  final Map<String, String> _prefixes = {};

  String _prefixOf(ImportRef import) => _prefixes.putIfAbsent(
        import.resolveUri(_appName),
        () => 'state${_prefixes.length}',
      );

  /// The type of the value of [entry].
  String typeOf(SharedState entry) => entry.typeWith(
        switch (entry.type.import) {
          null => null,
          final import => _prefixOf(import),
        },
      );

  /// The function of [entry].
  String functionOf(SharedState entry) =>
      entry.listenable.codeWith(_prefixOf(entry.listenable.import));

  /// [own] and the imports of the libraries of the types and functions,
  /// each on a line, sorted.
  List<String> imports(List<String> own) => [
        ...own,
        for (final MapEntry(key: uri, value: prefix) in _prefixes.entries)
          "import '$uri' as $prefix;",
      ]..sort();
}
