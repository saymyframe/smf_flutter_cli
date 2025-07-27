extension StringExt on String {
  String camelCase() {
    final buffer = StringBuffer();
    final parts = replaceAll(
      RegExp(r'[^a-zA-Z0-9]+'),
      ' ',
    ).trim().split(RegExp(r'\s+'));

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
