import 'package:smf_contracts/smf_contracts.dart';

/// A file produced by a [DslAwareCodeGenerator] for the CLI to write.
class GeneratedFile {
  /// Creates a file with [content] to be written to [path].
  const GeneratedFile(this.path, this.content);

  /// Absolute path of the file, usually joined from
  /// [DslContext.projectRootPath].
  ///
  /// A relative path would resolve against the CLI's working directory, not
  /// the project. An existing file at this path is replaced.
  final String path;

  /// Complete content of the file.
  final String content;
}
