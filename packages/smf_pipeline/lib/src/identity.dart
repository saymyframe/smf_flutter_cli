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

  /// The words that `flutter create` does not accept as the name of an
  /// app: the keywords of Dart, including the contextual ones.
  static const Set<String> flutterKeywords = {
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'inout',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'native',
    'new',
    'null',
    'of',
    'on',
    'operator',
    'out',
    'part',
    'patch',
    'required',
    'rethrow',
    'return',
    'set',
    'show',
    'source',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };

  /// The packages every Flutter app depends on, which `flutter create` does
  /// not accept as the name of an app.
  static const Set<String> flutterPackages = {
    'collection',
    'flutter',
    'flutter_test',
    'meta',
  };

  /// The words that cannot be a part of an Android application id, which
  /// is also the package of the app's Java and Kotlin code: the keywords of
  /// Java and the hard keywords of Kotlin.
  static const Set<String> androidKeywords = {
    'abstract',
    'as',
    'assert',
    'boolean',
    'break',
    'byte',
    'case',
    'catch',
    'char',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'double',
    'else',
    'enum',
    'extends',
    'false',
    'final',
    'finally',
    'float',
    'for',
    'fun',
    'goto',
    'if',
    'implements',
    'import',
    'in',
    'instanceof',
    'int',
    'interface',
    'is',
    'long',
    'native',
    'new',
    'null',
    'object',
    'package',
    'private',
    'protected',
    'public',
    'return',
    'short',
    'static',
    'strictfp',
    'super',
    'switch',
    'synchronized',
    'this',
    'throw',
    'throws',
    'transient',
    'true',
    'try',
    'typealias',
    'typeof',
    'val',
    'var',
    'void',
    'volatile',
    'when',
    'while',
  };

  /// The Dart package name of the app named [name], in snake_case:
  /// `My App` and `myApp` become `my_app`.
  ///
  /// Throws an [SmfUsageException] if the result is not a package name that
  /// `flutter create` accepts and that can end an Android application id.
  static String packageName(String name) {
    if (name.runes.any((rune) => rune > 0x7F)) {
      throw SmfUsageException(
        '"$name" cannot name an app: a package name has only Latin letters, '
        'digits and underscores.',
      );
    }
    final result = _words(name).join('_');
    if (!SmfNames.isSnakeCase(result) ||
        !SmfNames.isDartIdentifier(result) ||
        flutterKeywords.contains(result)) {
      throw SmfUsageException(
        '"$name" cannot name an app: the package name "$result" must start '
        'with a letter and not be a keyword of Dart.',
      );
    }
    if (flutterPackages.contains(result)) {
      throw SmfUsageException(
        '"$name" cannot name an app, because every Flutter app depends on '
        'the package $result.',
      );
    }
    if (androidKeywords.contains(result)) {
      throw SmfUsageException(
        '"$name" cannot name an app, because $result is a keyword of Java '
        'or Kotlin and cannot end the Android application id.',
      );
    }
    return result;
  }

  static final RegExp _orgPart = RegExp(r'^[a-z][a-z0-9_\- ]*$');

  /// The parts of the organization [org], lowercased, as they are written:
  /// `Com.MyCompany` gives `com` and `mycompany`. A part may have hyphens,
  /// underscores and spaces between its letters and digits; the platform
  /// identifiers replace them as each platform requires.
  ///
  /// Throws an [SmfUsageException] for a part that does not start with a
  /// letter, has other characters, or is a keyword of Java or Kotlin.
  static List<String> orgSegments(String org) {
    final segments = <String>[];
    for (final part in org.split('.')) {
      final segment = part.trim().toLowerCase();
      if (segment.isEmpty) continue;
      if (!_orgPart.hasMatch(segment)) {
        throw SmfUsageException(
          '"$org" is not an organization in reverse domain notation, such '
          'as com.example: every part must start with a letter and have only '
          'letters, digits, hyphens and underscores.',
        );
      }
      if (androidKeywords.contains(_android(segment))) {
        throw SmfUsageException(
          '"$org" cannot start the Android application id, because '
          '"$segment" is a keyword of Java or Kotlin.',
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

  /// [segment] as a part of an Android id: underscores for other
  /// separators.
  static String _android(String segment) =>
      segment.replaceAll(RegExp(r'[\- ]+'), '_');

  /// [segment] as a part of an iOS bundle id: hyphens for other separators.
  static String _ios(String segment) =>
      segment.replaceAll(RegExp('[_ ]+'), '-');

  /// The context of the app named [name] by the organization [org]:
  /// - the package name in snake_case;
  /// - the organization as the Android application id starts;
  /// - the Android application id and namespace, `<org>.<package name>`,
  ///   with underscores for other separators;
  /// - the iOS bundle id, with hyphens instead, since bundle ids allow no
  ///   underscores.
  ///
  /// `flutter create` would give the iOS bundle id the name in camelCase,
  /// `myApp`, where this gives `my-app`.
  static ModuleContext contextOf({required String name, required String org}) {
    final package = packageName(name);
    final segments = orgSegments(org);
    final androidOrg = segments.map(_android).join('.');
    final androidId = '$androidOrg.$package';
    return ModuleContext(
      appName: package,
      orgName: androidOrg,
      appIdentity: AppIdentity(
        androidApplicationId: androidId,
        iosBundleId: [...segments.map(_ios), _ios(package)].join('.'),
        androidNamespace: androidId,
      ),
    );
  }
}
