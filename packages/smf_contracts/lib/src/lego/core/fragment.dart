import 'package:meta/meta.dart';
import 'package:smf_contracts/lego_core.dart';

/// A piece of code for a socket, with the imports it needs.
///
/// The pipeline puts the imports of a fragment into the file that holds the
/// tag of its socket, so a fragment never imports anything itself.
///
/// A fragment for a [WrapperSocket] is created with [Fragment.wrap] and has an
/// opening and a closing part, such as `ProviderScope(child: ` and `)`.
@immutable
final class Fragment {
  /// Creates a fragment of [code] that needs [imports].
  const Fragment(this.code, {this.imports = const []}) : closing = null;

  /// Creates a fragment for a [WrapperSocket]: [opening] and [closing] go
  /// around the wrapped code, in the order of the wrapper's contributions.
  const Fragment.wrap(
    String opening,
    String this.closing, {
    this.imports = const [],
  }) : code = opening;

  /// The code of the fragment, or the opening part of a wrapper.
  final String code;

  /// The closing part of a wrapper, or `null` if this is not one.
  final String? closing;

  /// The imports [code] and [closing] need.
  final List<ImportRef> imports;

  /// Whether this fragment was created with [Fragment.wrap].
  bool get isWrapper => closing != null;

  // mason's renderer removes a backslash that precedes a line break or a
  // non-ASCII character anywhere in its output, including inserted code.
  static final RegExp _strippedBackslash =
      RegExp(r'\\(?:\r\n|\r|\n|[^\x00-\x7F])');

  /// Whether mason would remove a backslash from [text] when it renders it:
  /// a backslash right before a line break or a non-ASCII character.
  ///
  /// It applies to all text the pipeline passes to mason, not only to
  /// fragments: rendered sockets and brick variables too.
  static bool hasStrippedBackslash(String text) =>
      _strippedBackslash.hasMatch(text);

  /// Describes what is wrong with this fragment, or returns an empty list.
  ///
  /// A fragment must not contain a backslash right before a line break or a
  /// non-ASCII character: mason would drop that backslash when it renders
  /// the file. Every import must be valid, see [ImportRef.problems].
  List<String> problems() {
    final problems = <String>[];
    for (final part in [code, if (closing != null) closing!]) {
      if (hasStrippedBackslash(part)) {
        problems.add(
          'The fragment contains a backslash before a line break or a '
          'non-ASCII character, which mason removes: "${_excerpt(part)}".',
        );
      }
    }
    for (final import in imports) {
      problems.addAll(import.problems());
    }
    return problems;
  }

  static String _excerpt(String code) {
    final match = _strippedBackslash.firstMatch(code)!;
    final start = match.start < 20 ? 0 : match.start - 20;
    return code.substring(start, match.end).replaceAll('\n', r'\n');
  }
}

/// An import that a [Fragment] needs.
///
/// Two imports are the same import when they have the same URI and prefix;
/// the pipeline merges them into one directive and unites their [show]
/// lists. Hiding names is not supported, because a merged import could not
/// hide a name that another fragment uses.
@immutable
final class ImportRef {
  /// Imports [uri], a `dart:` or `package:` URI, optionally with a [prefix]
  /// and only the names in [show].
  const ImportRef(this.uri, {this.prefix, this.show = const []})
      : isAppFile = false;

  /// Imports a file of the generated app by its [path] below `lib/`, such
  /// as `core/app/fallback_start_screen.dart`.
  ///
  /// The pipeline turns it into a `package:` URI with the app's package
  /// name, which modules do not need to know.
  const ImportRef.app(String path, {this.prefix, this.show = const []})
      : uri = path,
        isAppFile = true;

  /// The imported URI, or the path below `lib/` of an [ImportRef.app].
  final String uri;

  /// The import prefix, as in `import '...' as prefix;`, if any.
  final String? prefix;

  /// The only names imported, as in `import '...' show a, b;`; empty to
  /// import all names.
  final List<String> show;

  /// Whether this imports a file of the generated app; see [ImportRef.app].
  final bool isAppFile;

  static final RegExp _identifier = RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$');

  /// This import with [prefix] instead of its own prefix and without a
  /// `show` combinator, such as a template's own prefix for the file of
  /// another module, which keeps the names of that file apart from its own.
  ImportRef withPrefix(String prefix) => isAppFile
      ? ImportRef.app(uri, prefix: prefix)
      : ImportRef(uri, prefix: prefix);

  /// The URI of the import in an app whose package is named [appName].
  String resolveUri(String appName) =>
      isAppFile ? 'package:$appName/$uri' : uri;

  /// The import directive in an app whose package is named [appName], such
  /// as `import 'package:go_router/go_router.dart' as go show GoRouter;`.
  String toDirective(String appName) {
    final buffer = StringBuffer("import '${resolveUri(appName)}'");
    if (prefix != null) buffer.write(' as $prefix');
    if (show.isNotEmpty) buffer.write(' show ${show.join(', ')}');
    buffer.write(';');
    return buffer.toString();
  }

  /// Describes what is wrong with this import, or returns an empty list.
  List<String> problems() {
    final validUri = isAppFile
        ? uri.endsWith('.dart') &&
            !uri.startsWith('/') &&
            !uri.startsWith('lib/') &&
            !uri.split('/').contains('..')
        : uri.startsWith('dart:') || uri.startsWith('package:');
    final problems = <String>[];
    if (!validUri) {
      problems.add(
        isAppFile
            ? 'The app import "$uri" must be a .dart path below lib/, '
                'without the lib/ prefix, such as core/app/app.dart.'
            : 'The import "$uri" must be a dart: or package: URI; use '
                'ImportRef.app for files of the generated app.',
      );
    }
    if (prefix != null && !_identifier.hasMatch(prefix!)) {
      problems.add(
        'The import prefix "$prefix" of "$uri" is not a Dart identifier.',
      );
    }
    for (final name in show) {
      if (!_identifier.hasMatch(name)) {
        problems.add(
          'The shown name "$name" of "$uri" is not a Dart identifier.',
        );
      }
    }
    return problems;
  }

  /// Merges [imports] into the directives of one file, in an app whose
  /// package is named [appName].
  ///
  /// Imports of the same URI with the same prefix become one: the result
  /// shows the union of their names, or all names if any of them shows all.
  /// The result is sorted like `directives_ordering` expects: `dart:`
  /// imports first, then `package:` imports, each by URI and then prefix.
  static List<ImportRef> merge(
    Iterable<ImportRef> imports, {
    required String appName,
  }) {
    final shown = <(String, String?), Set<String>?>{};
    for (final import in imports) {
      final key = (import.resolveUri(appName), import.prefix);
      if (!shown.containsKey(key)) {
        shown[key] = import.show.isEmpty ? null : {...import.show};
      } else if (import.show.isEmpty) {
        shown[key] = null;
      } else {
        shown[key]?.addAll(import.show);
      }
    }

    final merged = [
      for (final MapEntry(key: (uri, prefix), value: names) in shown.entries)
        ImportRef(
          uri,
          prefix: prefix,
          show: names == null ? const [] : (names.toList()..sort()),
        ),
    ];
    return merged..sort(_compareDirectives);
  }

  static int _compareDirectives(ImportRef a, ImportRef b) {
    int group(ImportRef import) => import.uri.startsWith('dart:') ? 0 : 1;

    final byGroup = group(a).compareTo(group(b));
    if (byGroup != 0) return byGroup;
    final byUri = a.uri.compareTo(b.uri);
    if (byUri != 0) return byUri;
    return (a.prefix ?? '').compareTo(b.prefix ?? '');
  }

  @override
  bool operator ==(Object other) =>
      other is ImportRef &&
      other.uri == uri &&
      other.isAppFile == isAppFile &&
      other.prefix == prefix &&
      _sameNames(other.show, show);

  @override
  int get hashCode => Object.hash(uri, isAppFile, prefix, Object.hashAll(show));

  static bool _sameNames(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => isAppFile ? 'ImportRef.app($uri)' : 'ImportRef($uri)';
}
