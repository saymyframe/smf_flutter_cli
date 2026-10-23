// The check of whole words that the tests of the onboarding module share in
// an app with the module: on a small phone with a large text size, a text
// of the onboarding breaks between its words and never inside one, and is
// as large as its text size asks, or as large as its longest word allows.
//
// It looks at where the lines of the text start, and not at the words one
// by one: a line may start after a hyphen, as in "Wi-Fi", or after a line
// break of the text itself. Only a line that starts between two letters or
// digits starts inside a word. The texts come from the onboarding and from
// the steps that other modules add to it, so the check takes any text.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The text size of the device on the small phone of the tests: three
/// times the usual one, about the largest that the settings of a device
/// have.
const double largeTextScale = 3;

/// The size of the text below the title of a page at the usual text size,
/// as the module has it.
const double pageTextSize = 18;

/// A letter, a mark that belongs to one, or a digit: a line that starts
/// between two of them starts inside a word.
final RegExp _wordCharacter = RegExp(r'[\p{L}\p{M}\p{N}]', unicode: true);

/// A space between two words, or a line break, where a line may break. A
/// no-break space keeps the words around it together.
final RegExp _space = RegExp(r'[ \t\r\n]');

/// The text of [finder], as it is laid out.
RenderParagraph _paragraphOf(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: finder,
        matching: find.byType(RichText),
        matchRoot: true,
      ),
    );

/// Checks that [shown], the text [text] that [what] names, keeps its words
/// whole on the small phone, in [language]: no line starts between two
/// letters or digits. The text is as large as its text size asks,
/// [largest], or, when its longest word would not fit the width that the
/// text has at that size, as large as that word allows.
void expectWholeWords(
  WidgetTester tester,
  Finder shown,
  String text, {
  required String what,
  required String language,
  required double largest,
}) {
  final paragraph = _paragraphOf(tester, shown);
  // The boxes of the characters from [start] to [end].
  List<TextBox> boxesOf(int start, int end) => paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
  // The top of the line of the character at [index], or `null` for one
  // that the paragraph draws no box for.
  double? lineOf(int index) => boxesOf(index, index + 1).firstOrNull?.top;
  for (var index = 1; index < text.length; index++) {
    if (!_wordCharacter.hasMatch(text[index - 1]) ||
        !_wordCharacter.hasMatch(text[index])) {
      continue;
    }
    final (before, after) = (lineOf(index - 1), lineOf(index));
    if (before == null || after == null) continue;
    final start = text.lastIndexOf(_space, index) + 1;
    final end = switch (text.indexOf(_space, index)) {
      -1 => text.length,
      final space => space,
    };
    expect(
      after,
      closeTo(before, 0.5),
      reason: 'On the small phone, $what "$text" breaks between its words '
          'and not inside "${text.substring(start, end)}", in $language: '
          'where a word would not fit, the text is as large as the word '
          'allows.',
    );
  }
  // The width of the longest word: that of all its boxes, also of a word
  // with a hyphen that a line may break after.
  var widest = 0.0;
  var from = 0;
  for (final word in text.split(_space)) {
    if (word.isEmpty) continue;
    final start = text.indexOf(word, from);
    from = start + word.length;
    final width = boxesOf(start, from).fold(
      0.0,
      (width, box) => width + box.right - box.left,
    );
    if (width > widest) widest = width;
  }
  final size = paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
  final room = paragraph.constraints.maxWidth;
  expect(
    size <= largest + 0.01 &&
        (size >= largest - 0.01 || (widest <= room && widest >= room * 0.9)),
    isTrue,
    reason: 'On the small phone, $what "$text" is as large as its text size '
        'asks, $largest, or as large as its longest word allows, in '
        '$language: it is $size, and its longest word takes $widest of '
        '$room.',
  );
}
