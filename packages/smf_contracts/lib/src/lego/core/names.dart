/// Rules for the names that the lego model turns into Dart identifiers,
/// route paths and template tags: module ids, role ids and socket names.
abstract final class SmfNames {
  static final RegExp _snakeCase = RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$');

  /// Whether [name] is lower snake_case, such as `firebase_core`.
  ///
  /// A valid name starts with a letter, uses only lowercase letters, digits
  /// and single underscores between words, and does not end with an
  /// underscore. Template tags join names with a double underscore, so a
  /// valid name never contains one.
  static bool isSnakeCase(String name) => _snakeCase.hasMatch(name);

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
}
