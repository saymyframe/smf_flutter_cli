/// A greeting that opens a run in a terminal, or is not said at all.
///
/// The prompter says it before its first question, and the logger drops it
/// once the run has printed anything else. So a run whose first question
/// comes after other output, such as a question at the end of generation
/// when every other answer came from the command line, says no greeting in
/// the middle of its output.
final class Greeting {
  /// Creates the greeting with [text].
  Greeting(String text) : _text = text;

  String? _text;

  /// The text of the greeting the first time, and `null` once it was said
  /// or dropped.
  String? take() {
    final text = _text;
    _text = null;
    return text;
  }

  /// Drops the greeting, since the run has printed something before it.
  void drop() => _text = null;
}
