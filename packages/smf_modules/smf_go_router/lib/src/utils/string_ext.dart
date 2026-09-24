/// A word boundary inside a camelCased word: before a capital that follows a
/// lowercase letter or a digit ('home|Screen', 'tab2|View'), and before the
/// last capital of an acronym that starts a new word ('HTTP|Client').
final _camelHump = RegExp(r'(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])');

extension StringExt on String {
  String camelCase() {
    final buffer = StringBuffer();
    final parts = replaceAll(_camelHump, ' ')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' ')
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
