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
/// The file imports the library of each type and function once, with a
/// prefix of its own, `state0`, `state1`, ..., in the order it first names
/// them, so names of two feeders never clash.
String cubitsFileOf(List<SharedState> entries, String appName) {
  final libraries = _Libraries(appName);
  final cubits = [
    for (final entry in entries)
      _cubitOf(entry, libraries.typeOf(entry), libraries.functionOf(entry)),
  ];
  return [
    '// The cubits that follow the values that controllers of the app keep,',
    '// one for each value, which the bloc module generates for the state',
    '// management role, and the widget that provides them around the root',
    '// of the app. A widget reads one with context.watch, and code changes',
    '// the value only through the controller that the doc of its cubit',
    '// names.',
    ...[
      ...libraries.prefixed,
      directiveOf(
        'package:flutter/foundation.dart',
        show: const ['ValueListenable'],
      ),
      directiveOf(
        'package:flutter/widgets.dart',
        show: const ['BuildContext', 'StatelessWidget', 'Widget'],
      ),
      directiveOf(
        'package:flutter_bloc/flutter_bloc.dart',
        show: const ['BlocProvider', 'Cubit', 'MultiBlocProvider'],
      ),
    ].sortedByUri,
    '',
    cubits.join('\n\n'),
    '',
    _providerWidgetOf(entries),
    '',
    _listenableCubit,
  ].join('\n');
}

/// The cubit of [entry], with the doc of its description, whose value has
/// the type [type] and whose listenable [function] returns, each as the
/// file writes it.
String _cubitOf(SharedState entry, String type, String function) => [
      ...docOf(entry.description),
      'final class ${cubitOf(entry)} extends ListenableCubit<$type> {',
      '  /// Creates the cubit, with the value that the controller has.',
      '  ${cubitOf(entry)}() : super($function());',
      '}',
    ].join('\n');

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

  /// The function of [entry] as the bridges call it.
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
