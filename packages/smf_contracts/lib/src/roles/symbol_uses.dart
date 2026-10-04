import 'package:smf_contracts/core.dart';

/// Whether [file] uses one of [names] from the library at [libraryPath],
/// a path relative to the project root such as
/// `lib/core/di/service_locator.dart`: calls it, tears it off or reads it.
///
/// A name counts without a target only if [file] imports the library
/// without a prefix, and with a target only if the target is the prefix of
/// an import of the library, so a member of another object or a
/// declaration of the file with the same name does not count.
bool usesSymbols(DartFileIndex file, Set<String> names, String libraryPath) =>
    _uses(file, names, (uri) => _pathOf(uri, file.path) == libraryPath);

/// Whether [file] uses [name] from the library that [import] imports, as
/// [usesSymbols] tells: a file of the app, which [file] may import by a
/// relative or a `package:` URI, or a library of a package or of Dart,
/// which [file] imports by the URI of [import].
bool usesImported(DartFileIndex file, String name, ImportRef import) =>
    import.isAppFile
        ? usesSymbols(file, {name}, 'lib/${import.uri}')
        : _uses(file, {name}, (uri) => uri == import.uri);

/// Whether [file] invokes [name] of the library at [libraryPath], a path
/// relative to the project root, through a prefix of its own: one that an
/// import of the library has and no import of another library, as in
/// `entry0.ThemeSetting()` after `import '…/theme_setting.dart' as entry0;`.
///
/// So the name is of that library whatever other libraries declare. An
/// import without a prefix, or with a prefix that the import of another
/// library shares, does not count: a name that two such libraries declare
/// is ambiguous there. Nor does a read or a tear-off of the name, which
/// invokes nothing.
bool invokesThroughOwnPrefix(
  DartFileIndex file,
  String name,
  String libraryPath,
) {
  final own = <String>{};
  final shared = <String>{};
  for (final IndexedImport(:uri, :prefix) in file.imports) {
    if (prefix == null) continue;
    (_pathOf(uri, file.path) == libraryPath ? own : shared).add(prefix);
  }
  return file.invocations.any(
    (call) =>
        call.name == name &&
        own.contains(call.target) &&
        !shared.contains(call.target),
  );
}

/// Whether [file] uses one of [names] from the libraries whose URIs
/// [isLibrary] accepts; see [usesSymbols].
bool _uses(
  DartFileIndex file,
  Set<String> names,
  bool Function(String uri) isLibrary,
) {
  var unprefixed = false;
  final prefixes = <String>{};
  for (final import in file.imports) {
    if (!isLibrary(import.uri)) continue;
    if (import.prefix case final prefix?) {
      prefixes.add(prefix);
    } else {
      unprefixed = true;
    }
  }
  if (!unprefixed && prefixes.isEmpty) return false;
  bool through(String? target) =>
      target == null ? unprefixed : prefixes.contains(target);
  return file.invocations.any(
        (call) => names.contains(call.name) && through(call.target),
      ) ||
      (unprefixed &&
          file.references.any((reference) => names.contains(reference.name))) ||
      file.memberAccesses.any(
        (access) =>
            names.contains(access.name) && prefixes.contains(access.target),
      );
}

/// The path relative to the project root of the library that [uri] imports
/// in the file at [from], or `null` for a `package:` URI without a path.
///
/// `package:` URIs are taken to be of the app, as `package:<app>/<path>`
/// stands for `lib/<path>`; a library of another package with the same
/// path would count too, which no real package has. A `dart:` library
/// resolves to its name alone, such as `async`, which is no path in `lib/`.
String? _pathOf(String uri, String from) {
  if (uri.startsWith('package:')) {
    final slash = uri.indexOf('/');
    return slash < 0 ? null : 'lib/${uri.substring(slash + 1)}';
  }
  return Uri.parse(from).resolve(uri).path;
}
