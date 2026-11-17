import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_riverpod/src/agents.dart';

/// The path of the file with the providers that follow the values that
/// controllers of the app keep, which the module generates in an app with
/// such values.
const bridgesFile = 'lib/core/state/shared_state_providers.dart';

/// The name of the provider that follows the value of [entry]: its name
/// with `Provider`, such as `themeModeProvider` for `themeMode`.
String providerOf(SharedState entry) => '${entry.name}Provider';

/// How a widget follows a provider of [bridgesFile]: a `Consumer` that
/// reads it with `ref.watch`, as a widget of the app does.
final class RiverpodBridges extends StateBridges {
  /// Creates the bridges of the module.
  const RiverpodBridges();

  @override
  Fragment watch(SharedState entry, String child) => Fragment(
        'Consumer(builder: (context, ref, _) => '
        '($child)(ref.watch(bridges.${providerOf(entry)})))',
        imports: const [
          ImportRef(
            'package:flutter_riverpod/flutter_riverpod.dart',
            show: ['Consumer'],
          ),
          ImportRef.app(
            'core/state/shared_state_providers.dart',
            prefix: 'bridges',
          ),
        ],
      );
}

/// Renders a provider for each value that a controller of the app keeps
/// into [bridgesFile], and tells coding agents of them, in an app with such
/// values.
final class RiverpodStateProvider extends RoleProvider<StateData> {
  /// Creates the provider of the module.
  const RiverpodStateProvider();

  @override
  Role<StateData> get role => stateManagementRole;

  @override
  RoleOutput render(RoleHookInput<StateData> input) {
    final entries = [
      for (final entry in stateManagementRole.sharedStateIn(input)) entry.state,
    ];
    if (entries.isEmpty) return const RoleOutput();
    return RoleOutput(
      files: {bridgesFile: providersFileOf(entries, input.context.appName)},
      fragments: [
        AppEntryRole.agentSections.entry(
          stateManagementRole.description,
          AgentNote(bridgesAgentNote),
        ),
      ],
    );
  }
}

/// The text of [bridgesFile] in the app [appName] with [entries]: a
/// `NotifierProvider` of a `ListenableNotifier` for each, in their order,
/// with the description of the entry as its doc, and the class
/// `ListenableNotifier`.
///
/// The file imports the library of each type and function as
/// [SharedStateCode] says, so names of two feeders never clash.
String providersFileOf(List<SharedState> entries, String appName) {
  final code = SharedStateCode(entries, appName: appName);
  return [
    '// The providers that follow the values that controllers of the app',
    '// keep, one for each value, which the riverpod module generates for the',
    '// state management role. A widget reads one with ref.watch, and code',
    '// changes the value only through the controller that the doc of its',
    '// provider names.',
    ...code.directives(const [
      ImportRef('package:flutter/foundation.dart', show: ['ValueListenable']),
      ImportRef(
        'package:flutter_riverpod/flutter_riverpod.dart',
        show: ['Notifier', 'NotifierProvider'],
      ),
    ]),
    '',
    [for (final entry in entries) _providerOf(entry, code)].join('\n\n'),
    '',
    _listenableNotifier,
  ].join('\n');
}

/// The provider of [entry], with the doc of its description, whose value
/// has the type and whose listenable the function of the entry returns,
/// each as [code] writes it.
String _providerOf(SharedState entry, SharedStateCode code) {
  final type = code.typeOf(entry);
  return [
    ...code.docOf(entry),
    'final NotifierProvider<ListenableNotifier<$type>, $type>',
    '${providerOf(entry)} = NotifierProvider(',
    '  () => ListenableNotifier(${code.functionOf(entry)}),',
    ');',
  ].join('\n');
}

/// The class of the providers of [bridgesFile].
const _listenableNotifier = '''
/// A notifier whose state is the value of a [ValueListenable], from the first
/// read of its provider until the `ProviderScope` disposes of it. It only
/// follows the value: code changes it through the controller of the
/// listenable.
final class ListenableNotifier<T> extends Notifier<T> {
  /// Creates the notifier of the listenable that [listenable] returns.
  ListenableNotifier(this._listenable);

  final ValueListenable<T> Function() _listenable;

  @override
  T build() {
    final listenable = _listenable();
    void follow() => state = listenable.value;
    listenable.addListener(follow);
    ref.onDispose(() => listenable.removeListener(follow));
    return listenable.value;
  }
}
''';
