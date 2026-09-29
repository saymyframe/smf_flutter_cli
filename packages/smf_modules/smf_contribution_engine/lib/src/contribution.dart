import 'package:dart_style/dart_style.dart';

/// A change to one Dart file, such as an import to add or a widget to
/// replace.
///
/// A contribution parses the file without resolving it, so it finds its
/// target by the names written in the source. Each subclass says what it does
/// when the target is missing, and whether it reformats the whole file with
/// [dartFormater] after the edit.
///
/// `PatchEngine` applies contributions to a project and renders the Mustache
/// placeholders in the text they insert.
abstract class Contribution {
  /// Creates a change to [file].
  const Contribution({required this.file});

  /// The path of the file to change, relative to the project root.
  final String file;

  /// Returns [original], the content of [file], with this change applied.
  Future<String> apply(String original);

  /// The formatter contributions run over the code they produce.
  ///
  /// It throws a [FormatterException] on invalid code, so a broken insert
  /// fails the contribution instead of reaching the file.
  ///
  /// It reads the code at the latest language version that the resolved
  /// `dart_style` supports, so newer syntax such as dot shorthands passes,
  /// and formats it in the tall style of Dart 3.7 and later, unless a
  /// `// @dart=` comment in the file picks an older version. It keeps
  /// trailing commas, so a list or argument list that has one stays split.
  DartFormatter get dartFormater => DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
        trailingCommas: TrailingCommas.preserve,
      );
}
