/// A word boundary inside a camelCased word: before a capital that follows a
/// lowercase letter or a digit ('home|Screen', 'tab2|View'), and before the
/// last capital of an acronym that starts a new word ('HTTP|Client').
final _camelHump = RegExp('(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])');

/// Helpers for naming generated identifiers.
extension StringExt on String {
  /// This string in lowerCamelCase, with a word for every run of letters and
  /// digits and every camelCase hump: `/user-profile/:id` gives
  /// `userProfileId`, `HTTPClient` gives `httpClient`. Returns an empty
  /// string when there are no words.
  String camelCase() {
    final buffer = StringBuffer();
    final parts = replaceAll(_camelHump, ' ')
        .replaceAll(RegExp('[^a-zA-Z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'));

    if (parts.isEmpty) return '';

    buffer.write(parts.first.toLowerCase());

    for (final part in parts.skip(1)) {
      if (part.isEmpty) continue;
      buffer.write(part[0].toUpperCase());
      buffer.write(part.substring(1).toLowerCase());
    }

    return buffer.toString();
  }
}
