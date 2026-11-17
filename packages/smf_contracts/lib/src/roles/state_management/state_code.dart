part of '../state_management.dart';

/// The longest line that `dart format` writes.
const _lineLength = 80;

/// The code with which the file of the bridges of a provider of the
/// [StateManagementRole] names the type and the function of each entry of
/// an app, so that every provider keeps the rule of the role on prefixes.
///
/// The file imports the library of each type and function once, with a
/// prefix of its own: `state0`, `state1`, ..., in the order of the entries,
/// the type of an entry before its function. So the names of two feeders
/// never clash with each other or with the names of the provider, which the
/// file imports without such a prefix. A type of `dart:core` needs no
/// import.
///
/// ```dart
/// final entries = [
///   for (final entry in stateManagementRole.sharedStateIn(input))
///     entry.state,
/// ];
/// final code = SharedStateCode(entries, appName: input.context.appName);
/// final text = [
///   ...code.directives(const [
///     ImportRef('package:flutter/foundation.dart', show: ['ValueListenable']),
///   ]),
///   for (final entry in entries) ...[
///     '',
///     ...code.docOf(entry),
///     'ValueListenable<${code.typeOf(entry)}> ${entry.name}Bridge() =>',
///     '    ${code.functionOf(entry)}();',
///   ],
/// ].join('\n');
/// ```
final class SharedStateCode {
  /// The code of [entries] in the app whose package is named [appName].
  SharedStateCode(Iterable<SharedState> entries, {required String appName})
      : _appName = appName {
    for (final entry in entries) {
      for (final import in [
        if (entry.type.import case final ofType?) ofType,
        entry.listenable.import,
      ]) {
        _prefixes.putIfAbsent(
          import.resolveUri(appName),
          () => 'state${_prefixes.length}',
        );
      }
    }
  }

  final String _appName;

  /// The prefixes of the libraries of the entries, by their URIs in the
  /// app, in the order they were given.
  final Map<String, String> _prefixes = {};

  /// The imports of the libraries of the types and functions of the
  /// entries, each once with its prefix, in the order of the prefixes.
  List<ImportRef> get imports => [
        for (final MapEntry(key: uri, value: prefix) in _prefixes.entries)
          ImportRef(uri, prefix: prefix),
      ];

  /// The import directives of the file: [imports] and [own], the imports of
  /// the names of the provider, merged by [ImportRef.merge] and in its
  /// order, each as `dart format` writes it.
  List<String> directives(Iterable<ImportRef> own) => [
        for (final import
            in ImportRef.merge([...imports, ...own], appName: _appName))
          _directiveOf(import),
      ];

  /// The directive of [import] on one line, or with its combinators on a
  /// line of their own when that line would be longer than `dart format`
  /// keeps it.
  String _directiveOf(ImportRef import) {
    final line = import.toDirective(_appName);
    if (line.length <= _lineLength ||
        (import.prefix == null && import.show.isEmpty)) {
      return line;
    }
    final uri = "import '${import.uri}'";
    return '$uri\n    ${line.substring(uri.length + 1)}';
  }

  /// The type of the value of [entry], one of the entries of this code, as
  /// the file writes it, with its prefix and `?` if it is nullable.
  String typeOf(SharedState entry) => entry.typeWith(
        switch (entry.type.import) {
          null => null,
          final import => _prefixOf(entry, import),
        },
      );

  /// The function of [entry], one of the entries of this code, as the file
  /// calls or tears it off, with its prefix.
  String functionOf(SharedState entry) =>
      entry.listenable.codeWith(_prefixOf(entry, entry.listenable.import));

  /// The lines of the doc comment of the bridge of [entry]: its
  /// description, on lines of at most 80 characters but for a word that is
  /// longer.
  List<String> docOf(SharedState entry) {
    final lines = <String>[];
    var line = StringBuffer('///');
    for (final word in entry.description.split(' ')) {
      if (line.length > 3 && line.length + 1 + word.length > _lineLength) {
        lines.add('$line');
        line = StringBuffer('///');
      }
      line.write(' $word');
    }
    return [...lines, '$line'];
  }

  /// The prefix of [import], a library of [entry].
  String _prefixOf(SharedState entry, ImportRef import) =>
      _prefixes[import.resolveUri(_appName)] ??
      (throw ArgumentError.value(
        entry,
        'entry',
        'Not one of the entries that the code was created with',
      ));
}
