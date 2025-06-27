import 'package:mason/mason.dart';

extension type AppId(String appId) {
  factory AppId.fallback({
    required String orgName,
    required String appName,
  }) {
    final segments = <String>[];
    for (final part in orgName.split('.')) {
      if (part.isEmpty) continue;
      segments.add(part.lowerCase);
    }

    segments.add(appName.lowerCase);

    return AppId(segments.join('.'));
  }

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
