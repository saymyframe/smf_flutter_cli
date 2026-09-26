/// Rules for the names that the lego model turns into Dart identifiers,
/// route paths and template tags: module ids, role ids and socket names.
abstract final class SmfNames {
  static final RegExp _snakeCase = RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$');

  static final RegExp _identifier = RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$');

  static final RegExp _word =
      RegExp('[A-Z]+(?=[A-Z][a-z])|[A-Z]?[a-z0-9]+|[A-Z]+');

  /// The reserved words of Dart, which no identifier may be, plus `await` and
  /// `yield`, which cannot name anything inside asynchronous and generator
  /// functions.
  static const Set<String> reservedWords = {
    'assert',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'if',
    'in',
    'is',
    'new',
    'null',
    'rethrow',
    'return',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };

  /// Whether [name] is lower snake_case, such as `firebase_core`.
  ///
  /// A valid name starts with a letter, uses only lowercase letters, digits
  /// and single underscores between words, and does not end with an
  /// underscore. Template tags join names with a double underscore, so a
  /// valid name never contains one.
  static bool isSnakeCase(String name) => _snakeCase.hasMatch(name);

  /// Whether [name] can name a variable, function or type in Dart: it has
  /// the form of an identifier and is not one of the [reservedWords].
  static bool isDartIdentifier(String name) =>
      _identifier.hasMatch(name) && !reservedWords.contains(name);

  /// Converts a snake_case [name] to lowerCamelCase: `firebase_core` becomes
  /// `firebaseCore`.
  static String lowerCamelCase(String name) {
    final upper = upperCamelCase(name);
    return upper.isEmpty ? upper : upper[0].toLowerCase() + upper.substring(1);
  }

  /// Converts a snake_case [name] to UpperCamelCase: `firebase_core` becomes
  /// `FirebaseCore`.
  static String upperCamelCase(String name) {
    return name
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join();
  }

  /// Converts [identifier], a camelCase Dart identifier made of letters and
  /// digits, to lower snake_case: `HomeScreen` becomes `home_screen`,
  /// `userId` becomes `user_id` and `HTTPClient` becomes `http_client`.
  ///
  /// Digits stay with a word that has lowercase letters, so `Screen2`
  /// becomes `screen2`, but `HTTP2Client` becomes `http_2_client`. Names
  /// that differ only in case, such as `userId` and `userID`, convert to the
  /// same name.
  /// Throws an [ArgumentError] if [identifier] does not start with a letter
  /// or has characters other than letters and digits.
  static String snakeCaseOf(String identifier) {
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9]*$').hasMatch(identifier)) {
      throw ArgumentError.value(
        identifier,
        'identifier',
        'Only identifiers of letters and digits that start with a letter '
            'convert to snake_case',
      );
    }
    return _word
        .allMatches(identifier)
        .map((match) => match.group(0)!.toLowerCase())
        .join('_');
  }

  /// Returns [text] as a single-quoted Dart string literal, such as
  /// `'It\'s here'`, that mason renders unchanged.
  ///
  /// It escapes quotes, backslashes, dollar signs and control characters.
  /// mason removes a backslash that precedes a non-ASCII character, so such
  /// a character right after an escaped backslash becomes a `\u{…}` escape.
  static String dartString(String text) {
    final buffer = StringBuffer("'");
    var afterBackslash = false;
    for (final rune in text.runes) {
      final escaped = switch (rune) {
        0x5C => r'\\',
        0x27 => r"\'",
        0x24 => r'\$',
        0x0A => r'\n',
        0x0D => r'\r',
        0x09 => r'\t',
        < 0x20 || 0x7F => '\\x${rune.toRadixString(16).padLeft(2, '0')}',
        > 0x7F when afterBackslash => '\\u{${rune.toRadixString(16)}}',
        _ => String.fromCharCode(rune),
      };
      buffer.write(escaped);
      afterBackslash = rune == 0x5C;
    }
    buffer.write("'");
    return buffer.toString();
  }
}
