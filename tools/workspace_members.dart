// The members of the workspace that the root pubspec.yaml lists, as the
// tools and the tests of the repository read them. A file of its own that
// imports only package:yaml, so that the scripts that need no more than the
// members, coverage_check.dart and test_annotations.dart, do not load the
// analyzer that workspace.dart imports.
import 'package:yaml/yaml.dart';

/// The characters that make a member of the workspace a glob. pub reads
/// each member as a glob from language version 3.11 on, in which these
/// characters match other paths, as `*` does, or are not valid alone, as
/// `(` is; it reads the other characters, `-` and `,` among them, as they
/// are.
final _glob = RegExp(r'[*?[\]{}()\\]');

/// The paths of the members of the workspace that the root pubspec [text]
/// lists in `workspace:`, from the root of the repository and in its order.
///
/// [text] is read as YAML, as pub reads it, whatever its comments and
/// quotes. Throws a [FormatException] when [text] lists no member, when a
/// member is not a path, and when a member is a glob: pub expands a glob
/// from language version 3.11 on and this function does not, so a glob
/// fails here rather than leave its packages out of the checks.
List<String> workspaceMembers(String text) {
  final workspace = switch (loadYaml(text)) {
    final YamlMap pubspec => pubspec.nodes['workspace'],
    _ => null,
  };
  if (workspace is! YamlList || workspace.isEmpty) {
    throw const FormatException(
      'The root pubspec.yaml lists no member of the workspace.',
    );
  }
  return [
    for (final member in workspace.nodes)
      switch (member.value) {
        final String path when !path.contains(_glob) => path,
        final String path => throw FormatException(
            'The member $path of the workspace is a glob, which pub expands '
            'from language version 3.11 on and the tools of the repository '
            'do not. List the packages it stands for one by one.',
            text,
            member.span.start.offset,
          ),
        final value => throw FormatException(
            'A member of the workspace is not a path: $value.',
            text,
            member.span.start.offset,
          ),
      },
  ];
}
