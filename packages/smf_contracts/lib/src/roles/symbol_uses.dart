import 'package:smf_contracts/lego_core.dart';

/// Whether [file] uses one of [names] from the library at [libraryPath],
/// a path relative to the project root such as
/// `lib/core/di/service_locator.dart`: calls it, tears it off or reads it.
///
/// A name counts without a target only if [file] imports the library
/// without a prefix, and with a target only if the target is the prefix of
/// an import of the library, so a member of another object or a
/// declaration of the file with the same name does not count.
bool usesSymbols(DartFileIndex file, Set<String> names, String libraryPath) {
  var unprefixed = false;
  final prefixes = <String>{};
  for (final import in file.imports) {
    if (_pathOf(import.uri, file.path) != libraryPath) continue;
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
/// in the file at [from], or `null` for a library outside the app.
///
/// `package:` URIs are taken to be of the app, as `package:<app>/<path>`
/// stands for `lib/<path>`; a library of another package with the same
/// path would count too, which no real package has.
String? _pathOf(String uri, String from) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    final slash = uri.indexOf('/');
    return slash < 0 ? null : 'lib/${uri.substring(slash + 1)}';
  }
  return Uri.parse(from).resolve(uri).path;
}
