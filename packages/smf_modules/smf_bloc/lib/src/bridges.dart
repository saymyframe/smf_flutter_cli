import 'package:smf_bloc/src/agents.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// The path of the file with the cubits that follow the values that
/// controllers of the app keep, and with the widget that provides them,
/// which the module generates in an app with such values.
const bridgesFile = 'lib/core/state/shared_state_cubits.dart';

/// The name of the widget of [bridgesFile] that provides the cubits around
/// the root of the app.
const providerWidget = 'SharedStateCubits';

/// The import of [providerWidget] alone, for the file of the root of the
/// app, which has the wrappers of other modules too: no other name of
/// [bridgesFile] reaches that file, where it could clash with one of them.
const _bridgesImport = ImportRef.app(
  'core/state/shared_state_cubits.dart',
  show: [providerWidget],
);

/// The name of the cubit that follows the value of [entry]: its name in
/// UpperCamelCase with `Cubit`, such as `ThemeModeCubit` for `themeMode`.
String cubitOf(SharedState entry) =>
    '${entry.name[0].toUpperCase()}${entry.name.substring(1)}Cubit';

/// How a widget follows a cubit of [bridgesFile]: a `Builder` that reads it
/// with `context.watch`, as a widget of the app does.
final class BlocBridges extends StateBridges {
  /// Creates the bridges of the module.
  const BlocBridges();

  @override
  Fragment watch(SharedState entry, String child) => Fragment(
        'Builder(builder: (context) => '
        '($child)(context.watch<bridges.${cubitOf(entry)}>().state))',
        imports: const [
          ImportRef('package:flutter/widgets.dart', show: ['Builder']),
          ImportRef('package:flutter_bloc/flutter_bloc.dart'),
          ImportRef.app(
            'core/state/shared_state_cubits.dart',
            prefix: 'bridges',
          ),
        ],
      );
}

/// Renders a cubit for each value that a controller of the app keeps into
/// [bridgesFile], with the widget that provides them around the root of
/// the app, and tells coding agents of them, in an app with such values.
final class BlocStateProvider extends RoleProvider<StateData> {
  /// Creates the provider of the module.
  const BlocStateProvider();

  @override
  Role<StateData> get role => stateManagementRole;

  @override
  RoleOutput render(RoleHookInput<StateData> input) {
    final entries = [
      for (final entry in stateManagementRole.sharedStateIn(input)) entry.state,
    ];
    if (entries.isEmpty) return const RoleOutput();
    return RoleOutput(
      files: {bridgesFile: cubitsFileOf(entries, input.context.appName)},
      fragments: [
        const SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            '$providerWidget(child: ',
            ')',
            imports: [_bridgesImport],
          ),
        ),
        AppEntryRole.agentSections.entry(
          stateManagementRole.description,
          AgentNote(bridgesAgentNote(cubitOf(entries.first))),
        ),
      ],
    );
  }
}

/// The text of [bridgesFile] in the app [appName] with [entries]: a
/// `ListenableCubit` for each, in their order, with the description of the
/// entry as its doc, the widget [providerWidget], which provides them, and
/// the class `ListenableCubit`.
///
/// The file imports the library of each type and function as
/// [SharedStateCode] says, so names of two feeders never clash.
String cubitsFileOf(List<SharedState> entries, String appName) {
  final code = SharedStateCode(entries, appName: appName);
  return [
    '// The cubits that follow the values that controllers of the app keep,',
    '// one for each value, which the bloc module generates for the state',
    '// management role, and the widget that provides them around the root',
    '// of the app. A widget reads one with context.watch, and code changes',
    '// the value only through the controller that the doc of its cubit',
    '// names.',
    ...code.directives(const [
      ImportRef('package:flutter/foundation.dart', show: ['ValueListenable']),
      ImportRef(
        'package:flutter/widgets.dart',
        show: ['BuildContext', 'StatelessWidget', 'Widget'],
      ),
      ImportRef(
        'package:flutter_bloc/flutter_bloc.dart',
        show: ['BlocProvider', 'Cubit', 'MultiBlocProvider'],
      ),
    ]),
    '',
    [for (final entry in entries) _cubitOf(entry, code)].join('\n\n'),
    '',
    _providerWidgetOf(entries),
    '',
    _listenableCubit,
  ].join('\n');
}

/// The cubit of [entry], with the doc of its description, whose value has
/// the type and whose listenable the function of the entry returns, each
/// as [code] writes it.
String _cubitOf(SharedState entry, SharedStateCode code) {
  final cubit = cubitOf(entry);
  return [
    ...code.docOf(entry),
    'final class $cubit extends ListenableCubit<${code.typeOf(entry)}> {',
    '  /// Creates the cubit, with the value that the controller has.',
    '  $cubit() : super(${code.functionOf(entry)}());',
    '}',
  ].join('\n');
}

/// The widget [providerWidget], which provides the cubits of [entries].
String _providerWidgetOf(List<SharedState> entries) {
  final providers = [
    for (final entry in entries)
      '      BlocProvider(create: (_) => ${cubitOf(entry)}()),',
  ];
  return '''
/// Provides the cubits of the values that controllers of the app keep to
/// [child], the root of the app. Each cubit is created at its first read,
/// and follows its value until the app ends.
final class $providerWidget extends StatelessWidget {
  /// Creates the widget around [child].
  const $providerWidget({required this.child, super.key});

  /// The root of the app.
  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
${providers.join('\n')}
    ],
    child: child,
  );
}''';
}

/// The class of the cubits of [bridgesFile].
const _listenableCubit = '''
/// A cubit whose state is the value of a [ValueListenable], from its creation
/// until it is closed. It only follows the value: code changes it through
/// the controller of the listenable.
abstract base class ListenableCubit<T> extends Cubit<T> {
  /// Creates the cubit of [listenable], with its value.
  ListenableCubit(this._listenable) : super(_listenable.value) {
    _listenable.addListener(_follow);
  }

  final ValueListenable<T> _listenable;

  void _follow() => emit(_listenable.value);

  @override
  Future<void> close() {
    _listenable.removeListener(_follow);
    return super.close();
  }
}
''';
