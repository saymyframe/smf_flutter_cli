import 'dart:collection';

import 'package:analyzer/dart/ast/token.dart';

/// Text to insert into a source at `offset`.
typedef Insertion = ({int offset, String text});

/// Returns [source] with [insertions] made, each at its offset in [source].
///
/// Insertions at the same offset go in the order given.
String applyInsertions(String source, Iterable<Insertion> insertions) {
  final textsByOffset = SplayTreeMap<int, StringBuffer>();
  for (final (:offset, :text) in insertions) {
    textsByOffset.putIfAbsent(offset, StringBuffer.new).write(text);
  }

  final result = StringBuffer();
  var copied = 0;
  textsByOffset.forEach((offset, text) {
    result
      ..write(source.substring(copied, offset))
      ..write(text);
    copied = offset;
  });
  return (result..write(source.substring(copied))).toString();
}

/// Inserts [text] on lines of its own after [token], past any comment that
/// trails [token] on its line, with the indentation of that line.
Insertion insertionAfter(String source, Token token, String text) {
  final offset = endOfTrailingComments(source, token);
  final restOfLine = source.substring(offset, _lineEnd(source, offset));
  // Code that follows on the line goes on the next one, out of the reach of
  // a comment that ends the text.
  final lineBreak = restOfLine.trim().isEmpty ? '' : '\n';
  final indentation = _indentation(source, offset);
  return (offset: offset, text: '\n$indentation${text.trim()}$lineBreak');
}

/// Inserts [text] on lines of its own before [token], above the comments
/// that lead up to it, with the indentation of their line.
Insertion insertionBefore(String source, Token token, String text) {
  final offset = startOfLeadingComments(source, token);
  final indentation = _indentation(source, offset);
  return (offset: offset, text: '${text.trim()}\n$indentation');
}

/// The spaces and tabs that start the line where the text before [offset]
/// ends.
///
/// Inserted lines take them, since the formatter leaves a comment at the
/// start of a line where it is.
String _indentation(String source, int offset) {
  final lineStart = source.lastIndexOf('\n', offset - 1) + 1;
  return RegExp('[ \t]*').matchAsPrefix(source, lineStart)![0]!;
}

/// The end of [token], or of the last comment that starts on the line where
/// [token] ends.
int endOfTrailingComments(String source, Token token) {
  final lineEnd = _lineEnd(source, token.end);

  var end = token.end;
  Token? comment = token.next?.precedingComments;
  while (comment != null && comment.offset < lineEnd) {
    end = comment.end;
    comment = comment.next;
  }
  return end;
}

/// The start of the first comment before [token] on the lines after the
/// token that precedes it, or of [token] itself without such a comment.
///
/// A comment on the line of the preceding token trails that token, so it
/// doesn't count.
int startOfLeadingComments(String source, Token token) {
  final previousLineEnd = _lineEnd(source, token.previous!.end);

  Token? comment = token.precedingComments;
  while (comment != null && comment.offset < previousLineEnd) {
    comment = comment.next;
  }
  return comment?.offset ?? token.offset;
}

/// The offset of the line break that ends the line of [offset], or the end
/// of [source] on its last line.
int _lineEnd(String source, int offset) {
  final lineBreak = source.indexOf('\n', offset);
  return lineBreak == -1 ? source.length : lineBreak;
}
