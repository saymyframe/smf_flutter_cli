import 'package:smf_contracts/lego_core.dart';

/// Stage 2 of the pipeline: the names and platform identifiers of the app.
///
/// These are pure functions of what the user typed; they throw an
/// [SmfUsageException] for names that cannot become valid identifiers.
abstract final class AppNames {
  /// The organization used when none is given.
  static const defaultOrg = 'com.example';

  static final RegExp _separators = RegExp('[^A-Za-z0-9]+');

  /// The words of [text]: runs of letters and digits, split further at
  /// camelCase boundaries and lowercased.
  static List<String> _words(String text) => [
        for (final part in text.split(_separators))
          if (part.isNotEmpty)
            ...(RegExp('^[A-Za-z]').hasMatch(part)
                ? SmfNames.snakeCaseOf(part).split('_')
                : [part.toLowerCase()]),
      ];

  /// The Dart package name of the app named [name], in snake_case:
  /// `My App` and `myApp` become `my_app`.
  ///
  /// Throws an [SmfUsageException] if the result is not a valid package
  /// name.
  static String packageName(String name) {
    final result = _words(name).join('_');
    if (!SmfNames.isSnakeCase(result) || !SmfNames.isDartIdentifier(result)) {
      throw SmfUsageException(
        '"$name" cannot name an app: the package name "$result" must start '
        'with a letter and not be a reserved word of Dart.',
      );
    }
    return result;
  }

  /// The segments of the organization [org] in snake_case, such as
  /// `[com, example]` for `Com.Example`.
  ///
  /// Throws an [SmfUsageException] if a segment does not start with a
  /// letter.
  static List<String> orgSegments(String org) {
    final segments = <String>[];
    for (final part in org.split('.')) {
      final segment = _words(part).join('_');
      if (segment.isEmpty) continue;
      if (!SmfNames.isSnakeCase(segment)) {
        throw SmfUsageException(
          '"$org" is not an organization in reverse domain notation, such '
          'as com.example: every part must start with a letter.',
        );
      }
      segments.add(segment);
    }
    if (segments.isEmpty) {
      throw SmfUsageException(
        '"$org" is not an organization in reverse domain notation, such as '
        'com.example.',
      );
    }
    return segments;
  }

  /// The context of the app named [name] by the organization [org]:
  /// - the package name in snake_case;
  /// - the organization with its parts in snake_case, joined by dots;
  /// - the Android application id and namespace, `<org>.<package name>`;
  /// - the iOS bundle id, the same with hyphens instead of underscores,
  ///   which bundle ids do not allow.
  static ModuleContext contextOf({required String name, required String org}) {
    final package = packageName(name);
    final segments = orgSegments(org);
    final androidId = [...segments, package].join('.');
    return ModuleContext(
      appName: package,
      orgName: segments.join('.'),
      appIdentity: AppIdentity(
        androidApplicationId: androidId,
        iosBundleId: androidId.replaceAll('_', '-'),
        androidNamespace: androidId,
      ),
    );
  }
}
