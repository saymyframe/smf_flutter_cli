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
          AgentNote(bridgesAgentNote(providerOf(entries.first))),
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
/// The file imports the library of each type and function once, with a
/// prefix of its own, `state0`, `state1`, ..., in the order it first names
/// them, so names of two feeders never clash.
String providersFileOf(List<SharedState> entries, String appName) {
  final libraries = _Libraries(appName);
  final providers = [
    for (final entry in entries)
      _providerOf(entry, libraries.typeOf(entry), libraries.functionOf(entry)),
  ];
  return [
    '// The providers that follow the values that controllers of the app',
    '// keep, one for each value, which the riverpod module generates for the',
    '// state management role. A widget reads one with ref.watch, and code',
    '// changes the value only through the controller that the doc of its',
    '// provider names.',
    ...[
      ...libraries.prefixed,
      directiveOf(
        'package:flutter/foundation.dart',
        show: const ['ValueListenable'],
      ),
      directiveOf(
        'package:flutter_riverpod/flutter_riverpod.dart',
        show: const ['Notifier', 'NotifierProvider'],
      ),
    ].sortedByUri,
    '',
    providers.join('\n\n'),
    '',
    _listenableNotifier,
  ].join('\n');
}

/// The provider of [entry], with the doc of its description, whose value
/// has the type [type] and whose listenable [function] returns, each as
/// the file writes it.
String _providerOf(SharedState entry, String type, String function) => [
      ...docOf(entry.description),
      'final NotifierProvider<ListenableNotifier<$type>, $type>',
      '${providerOf(entry)} = NotifierProvider(',
      '  () => ListenableNotifier($function),',
      ');',
    ].join('\n');

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

/// The libraries that the code of the bridges names, each imported once
/// with a prefix of its own.
final class _Libraries {
  _Libraries(this._appName);

  final String _appName;

  /// The prefixes of the libraries, by their URIs in the app.
  final Map<String, String> _prefixes = {};

  /// The directives that import the libraries, in the order they were
  /// first named.
  List<({String uri, String line})> get prefixed => [
        for (final MapEntry(key: uri, value: prefix) in _prefixes.entries)
          directiveOf(uri, prefix: prefix),
      ];

  /// The prefix of the library of [import].
  String _prefixOf(ImportRef import) => _prefixes.putIfAbsent(
        import.resolveUri(_appName),
        () => 'state${_prefixes.length}',
      );

  /// The type of the value of [entry] as the bridges write it.
  String typeOf(SharedState entry) => entry.typeWith(
        switch (entry.type.import) {
          null => null,
          final import => _prefixOf(import),
        },
      );

  /// The function of [entry] as the bridges tear it off.
  String functionOf(SharedState entry) =>
      entry.listenable.codeWith(_prefixOf(entry.listenable.import));
}

/// The directive that imports [uri], with [prefix] or [show] if given, as
/// `dart format` writes it: on one line, or with the rest on a line of its
/// own when the line would be longer than 80 characters.
({String uri, String line}) directiveOf(
  String uri, {
  String? prefix,
  List<String> show = const [],
}) {
  final rest = [
    if (prefix != null) 'as $prefix',
    if (show.isNotEmpty) 'show ${show.join(', ')}',
  ].join(' ');
  final line = rest.isEmpty ? "import '$uri';" : "import '$uri' $rest;";
  return (
    uri: uri,
    line: line.length <= 80 ? line : "import '$uri'\n    $rest;",
  );
}

/// The lines of a doc comment with [text], with at most 80 characters on a
/// line but for a word that is longer.
List<String> docOf(String text) {
  final lines = <String>[];
  var line = StringBuffer('///');
  for (final word in text.split(' ')) {
    if (line.length > 3 && line.length + 1 + word.length > 80) {
      lines.add('$line');
      line = StringBuffer('///');
    }
    line.write(' $word');
  }
  return [...lines, '$line'];
}

/// The lines of a list of directives, in the order of their URIs, and of
/// their lines for one URI.
extension on List<({String uri, String line})> {
  List<String> get sortedByUri => [
        for (final directive in [...this]..sort(_byUri)) directive.line,
      ];
}

int _byUri(({String uri, String line}) a, ({String uri, String line}) b) =>
    switch (a.uri.compareTo(b.uri)) {
      0 => a.line.compareTo(b.line),
      final order => order,
    };
