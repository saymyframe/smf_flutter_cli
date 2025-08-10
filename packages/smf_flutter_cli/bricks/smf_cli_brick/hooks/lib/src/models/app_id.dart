import 'package:mason/mason.dart';

/// Strongly-typed application identifier with helpers and validation.
extension type AppId(String appId) {
  /// Derives a sensible Android application id from organization and app names.
  factory AppId.fallbackAndroid({
    required String orgName,
    required String appName,
  }) {
    final segments = <String>[];
    for (final part in orgName.split('.')) {
      if (part.isEmpty) continue;
      segments.add(part.snakeCase);
    }

    segments.add(appName.snakeCase);

    return AppId(segments.join('.'));
  }

  /// Derives a sensible iOS bundle id from organization and app names.
  factory AppId.fallbackiOS({
    required String orgName,
    required String appName,
  }) {
    final segments = <String>[];
    for (final part in orgName.split('.')) {
      if (part.isEmpty) continue;
      segments.add(part.paramCase);
    }

    segments.add(appName.paramCase);

    return AppId(segments.join('.'));
  }

  /// Returns true when the identifier has at least two dot-separated segments
  /// and each segment starts with a letter and contains only [a-zA-Z0-9_].
  bool get isValid {
    final segments = appId.split('.');
    if (segments.length < 2) {
      return false;
    }

    final isLetter = RegExp('^[a-zA-Z]');
    final isAlphanumeric = RegExp(r'^[a-zA-Z0-9_]+$');

    for (final segment in segments) {
      if (segment.isEmpty || !isLetter.hasMatch(segment[0])) {
        return false;
      }

      if (!isAlphanumeric.hasMatch(segment)) {
        return false;
      }
    }

    return true;
  }
}
