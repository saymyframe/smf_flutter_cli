part of 'app_entry.dart';

/// The value of a `<meta-data>` element in
/// [AppEntryRole.androidManifestApplicationMeta]: an `android:value` or an
/// `android:resource`.
@immutable
final class AndroidMetaData {
  /// An `android:value`, such as `true` or a string.
  const AndroidMetaData.value(this.text) : isResource = false;

  /// An `android:resource`, such as `@drawable/ic_notification`.
  const AndroidMetaData.resource(this.text) : isResource = true;

  /// The value or the resource.
  final String text;

  /// Whether this is an `android:resource`.
  final bool isResource;

  /// The attribute of the element, such as `android:value="true"`.
  String get attribute =>
      '${isResource ? 'android:resource' : 'android:value'}='
      '"${_escapeXml(text)}"';

  @override
  bool operator ==(Object other) =>
      other is AndroidMetaData &&
      other.text == text &&
      other.isResource == isResource;

  @override
  int get hashCode => Object.hash(text, isResource);

  @override
  String toString() => attribute;
}

/// A value of a key of a property list: of `Info.plist` in
/// [AppEntryRole.infoPlist], or of the entitlements of the iOS app in
/// [AppEntryRole.iosEntitlements].
@immutable
sealed class PlistValue {
  const PlistValue();

  /// The plist XML of the value, each line indented by [indent].
  String toXml(String indent);
}

/// A `<string>` value.
final class PlistString extends PlistValue {
  /// Creates the value [value].
  const PlistString(this.value);

  /// The string.
  final String value;

  @override
  String toXml(String indent) => '$indent<string>${_escapeXml(value)}</string>';

  @override
  bool operator ==(Object other) =>
      other is PlistString && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// A `<true/>` or `<false/>` value.
final class PlistBoolean extends PlistValue {
  /// Creates the value [value].
  // ignore: avoid_positional_boolean_parameters, a plist value wraps a bool.
  const PlistBoolean(this.value);

  /// The boolean.
  final bool value;

  @override
  String toXml(String indent) => '$indent<$value/>';

  @override
  bool operator ==(Object other) =>
      other is PlistBoolean && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}

/// An `<integer>` value.
final class PlistInteger extends PlistValue {
  /// Creates the value [value].
  const PlistInteger(this.value);

  /// The integer.
  final int value;

  @override
  String toXml(String indent) => '$indent<integer>$value</integer>';

  @override
  bool operator ==(Object other) =>
      other is PlistInteger && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}

/// An `<array>` of strings, such as the values of `UIBackgroundModes`.
final class PlistStringArray extends PlistValue {
  /// Creates the array of [values].
  const PlistStringArray(this.values);

  /// The strings, in order.
  final List<String> values;

  /// Renders each value once, in the order of first appearance.
  @override
  String toXml(String indent) => [
        '$indent<array>',
        for (final value in {...values})
          '$indent\t<string>${_escapeXml(value)}</string>',
        '$indent</array>',
      ].join('\n');

  @override
  bool operator ==(Object other) {
    if (other is! PlistStringArray || other.values.length != values.length) {
      return false;
    }
    for (var i = 0; i < values.length; i++) {
      if (other.values[i] != values[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(values);

  @override
  String toString() => '$values';
}

/// Merges the values of a key of a property list, such as `Info.plist`:
/// string arrays are united, other values must be equal.
final class PlistMergePolicy extends MergePolicy<PlistValue> {
  /// Creates the policy.
  const PlistMergePolicy();

  @override
  PlistValue merge(String key, PlistValue existing, PlistValue incoming) {
    if (existing is PlistStringArray && incoming is PlistStringArray) {
      return PlistStringArray(
        const UnionPolicy<String>()
            .merge(key, existing.values, incoming.values),
      );
    }
    return const ConflictPolicy<PlistValue>().merge(key, existing, incoming);
  }
}

/// Keeps one text for each heading of the README, and checks that a
/// heading is one line and that a section has text.
final class _ReadmeSectionPolicy extends MergePolicy<String> {
  const _ReadmeSectionPolicy();

  @override
  String? problemWith(String key, String value) {
    if (key.isEmpty ||
        key != key.trim() ||
        key.contains('\n') ||
        key.contains('\r')) {
      return 'The heading "$key" of a section of the README is not one line '
          'of text without spaces around it.';
    }
    if (value.trim().isEmpty) {
      return 'The section "$key" of the README has no text.';
    }
    if (Fragment.hasStrippedBackslash(key) ||
        Fragment.hasStrippedBackslash(value)) {
      return 'The section "$key" of the README has a backslash before a line '
          'break or a non-ASCII character, which mason removes; for a line '
          'break in Markdown, end the line with two spaces instead.';
    }
    return null;
  }

  @override
  String merge(String key, String existing, String incoming) =>
      const ConflictPolicy<String>().merge(key, existing, incoming);
}

String _renderString(String value) => value;

/// Each section under its heading, after an empty line.
String _renderReadmeSections(List<MapEntry<String, String>> entries) => entries
    .map((entry) => '\n## ${entry.key}\n\n${entry.value.trim()}')
    .join('\n');

String _renderAndroidPermissions(List<MapEntry<String, NoValue>> entries) =>
    entries
        .map(
          (entry) =>
              '    <uses-permission android:name="${_escapeXml(entry.key)}"/>',
        )
        .join('\n');

String _renderAndroidMetaData(
  List<MapEntry<String, AndroidMetaData>> entries,
) =>
    entries
        .map(
          (entry) =>
              '        <meta-data android:name="${_escapeXml(entry.key)}" '
              '${entry.value.attribute}/>',
        )
        .join('\n');

/// The entries of the top-level dictionary of a property list, each key
/// with its value.
String _renderPlistEntries(List<MapEntry<String, PlistValue>> entries) =>
    entries
        .map(
          (entry) => '\t<key>${_escapeXml(entry.key)}</key>\n'
              '${entry.value.toXml('\t')}',
        )
        .join('\n');

String _renderGradleSettingsPlugins(List<MapEntry<String, String>> entries) =>
    entries
        .map(
          (entry) => '    id("${_escapeKotlin(entry.key)}") '
              'version("${_escapeKotlin(entry.value)}") apply false',
        )
        .join('\n');

String _renderGradleAppPlugins(List<MapEntry<String, NoValue>> entries) =>
    entries.map((entry) => '    id("${_escapeKotlin(entry.key)}")').join('\n');

String _renderGradleDependencies(List<MapEntry<String, String>> entries) =>
    entries.map(
      (entry) {
        final coordinates =
            '${_escapeKotlin(entry.key)}:${_escapeKotlin(entry.value)}';
        return '    implementation("$coordinates")';
      },
    ).join('\n');

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _escapeKotlin(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll(r'$', r'\$');

/// The sockets that render complete lines of a file, with the file.
const _lineSockets = <(SocketRef, String)>[
  (
    AppEntryRole.androidManifestPermissions,
    AppEntryRole.androidManifestFile,
  ),
  (
    AppEntryRole.androidManifestApplicationMeta,
    AppEntryRole.androidManifestFile,
  ),
  (AppEntryRole.mainActivityIntentFilters, AppEntryRole.androidManifestFile),
  (AppEntryRole.infoPlist, AppEntryRole.infoPlistFile),
  (AppEntryRole.iosEntitlements, AppEntryRole.iosEntitlementsFile),
  (AppEntryRole.gradleSettingsPlugins, AppEntryRole.gradleSettingsFile),
  (AppEntryRole.gradleAppPlugins, AppEntryRole.gradleAppFile),
  (AppEntryRole.gradleAppDependencies, AppEntryRole.gradleAppFile),
  (AppEntryRole.readmeSections, AppEntryRole.readmeFile),
];

List<SmfIssue> _checkTagLines(ModuleRuleInput<NoDsl> input) {
  final origin = ModuleOrigin(input.module.id);
  final templates = _templatesOf(input.contributions);
  final issues = <SmfIssue>[];
  for (final (socket, path) in _lineSockets) {
    final tag = '{{{${socket.tag}}}}';
    for (final MapEntry(key: template, value: text) in templates.entries) {
      if (!text.contains(tag)) continue;
      if (template != path) {
        issues.add(
          SmfIssue(
            'The tag $tag is in $template, but its lines belong in $path.',
            origin: origin,
            path: template,
          ),
        );
      } else if (tag.allMatches(text).length !=
          text.split('\n').where((line) => line.trimRight() == tag).length) {
        issues.add(
          SmfIssue(
            'The tag $tag must stand alone at the start of a line of $path, '
            'because its contributions render as complete lines.',
            origin: origin,
            path: path,
          ),
        );
      }
    }
  }
  return issues;
}

List<SmfIssue> _checkNativeKeys(StructuralRuleInput<NoDsl> input) {
  final issues = <SmfIssue>[];
  void once(String path, String what, List<String> keys) {
    final seen = <String>{};
    final reported = <String>{};
    for (final key in keys) {
      if (seen.add(key) || !reported.add(key)) continue;
      issues.add(
        SmfIssue(
          '$path has $what $key more than once.',
          hint: 'A module cannot contribute a key that the template of the '
              'app entry role has already.',
          origin: input.owners[path],
          path: path,
        ),
      );
    }
  }

  final texts = input.texts;
  for (final path in const [
    AppEntryRole.infoPlistFile,
    AppEntryRole.iosEntitlementsFile,
  ]) {
    if (texts[path] case final plist?) once(path, 'the key', _plistKeys(plist));
  }
  if (texts[AppEntryRole.androidManifestFile] case final manifest?) {
    const path = AppEntryRole.androidManifestFile;
    once(
      path,
      'the permission',
      _childNames(manifest, 'manifest', 'uses-permission'),
    );
    once(
      path,
      'the meta-data',
      _childNames(manifest, 'application', 'meta-data'),
    );
  }
  for (final path in const [
    AppEntryRole.gradleSettingsFile,
    AppEntryRole.gradleAppFile,
  ]) {
    for (final plugins in _gradlePluginBlocks(texts[path] ?? '')) {
      once(path, 'the plugin', plugins);
    }
  }
  return issues;
}

/// The build settings of each build configuration of an Xcode project, with
/// the name of the configuration when it follows them, as Xcode writes it.
/// The settings have no braces inside: Xcode writes a list in parentheses.
final _buildSettings = RegExp(
  r'buildSettings\s*=\s*\{([^{}]*)\};(?:\s*name\s*=\s*"?([^";]*)"?\s*;)?',
);

/// The setting `INFOPLIST_FILE` of build settings, with its value.
final _infoPlistSetting = RegExp(
  r'^\s*"?INFOPLIST_FILE"?\s*=\s*"?([^";]*)"?\s*;',
  multiLine: true,
);

/// A setting `CODE_SIGN_ENTITLEMENTS` of build settings, with its
/// condition, such as `[sdk=iphoneos*]`, if any, and its value.
final _entitlementsSetting = RegExp(
  r'^\s*"?CODE_SIGN_ENTITLEMENTS(\[[^\]]*\])?"?\s*=\s*"?([^";]*)"?\s*;',
  multiLine: true,
);

/// [path], a path of the app in its iOS project, as the build settings of
/// [AppEntryRole.xcodeProjectFile] name it: from the directory of that
/// project, such as `Runner/Info.plist`.
String _inIosProject(String path) => path.substring(path.indexOf('/') + 1);

List<SmfIssue> _checkIosEntitlementsSigned(StructuralRuleInput<NoDsl> input) {
  const path = AppEntryRole.xcodeProjectFile;
  const file = AppEntryRole.iosEntitlementsFile;
  final project = input.texts[path];
  if (project == null) return const [];
  final origin = input.owners[path];
  final infoPlist = _inIosProject(AppEntryRole.infoPlistFile);
  final entitlements = _inIosProject(file);
  final issues = <SmfIssue>[];
  var ofApp = 0;
  for (final configuration in _buildSettings.allMatches(project)) {
    final settings = configuration[1]!;
    final named = switch (configuration[2]) {
      final name? => 'The build configuration $name',
      null => 'A build configuration',
    };
    final signing = [
      for (final setting in _entitlementsSetting.allMatches(settings))
        (condition: setting[1], value: setting[2]!.trim()),
    ];
    final readsInfoPlist = _infoPlistSetting
        .allMatches(settings)
        .any((setting) => setting[1]!.trim() == infoPlist);
    if (readsInfoPlist) {
      ofApp++;
      if (signing case [(condition: null, :final value)]
          when value == entitlements) {
        continue;
      }
      issues.add(
        SmfIssue(
          '$named of the app target in $path does not sign the app with '
          '$file.',
          hint: 'Each build configuration with INFOPLIST_FILE = $infoPlist '
              'has CODE_SIGN_ENTITLEMENTS = $entitlements; and no other '
              'CODE_SIGN_ENTITLEMENTS. Without it the app builds and signs, '
              'but has none of the entitlements that the modules add.',
          origin: origin,
          path: path,
        ),
      );
    } else if (signing.isNotEmpty) {
      issues.add(
        SmfIssue(
          '$named in $path, which is not one of the app target, names '
          'entitlements in CODE_SIGN_ENTITLEMENTS.',
          hint: 'Only the app target signs with $file: they are the '
              'entitlements of the app, and a setting of the project reaches '
              'every target, such as the tests.',
          origin: origin,
          path: path,
        ),
      );
    }
  }
  if (ofApp == 0) {
    issues.add(
      SmfIssue(
        '$path has no build configuration of the app target, with '
        'INFOPLIST_FILE = $infoPlist, that signs the app with $file.',
        origin: origin,
        path: path,
      ),
    );
  }
  return issues;
}

/// [text] without its XML comments.
String _withoutXmlComments(String text) =>
    text.replaceAll(RegExp('<!--.*?-->', dotAll: true), '');

/// [text] with the predefined entities of XML decoded.
String _unescapeXml(String text) => text
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// The keys of the top-level dictionary of the property list [text], in
/// order.
List<String> _plistKeys(String text) {
  final keys = <String>[];
  var depth = 0;
  final tokens = RegExp(r'<(/?)(dict|array)\s*(/?)>|<key>([^<]*)</key>');
  for (final match in tokens.allMatches(_withoutXmlComments(text))) {
    if (match[4] case final key?) {
      if (depth == 1) keys.add(_unescapeXml(key.trim()));
    } else if (match[3] != '/') {
      depth += match[1] == '/' ? -1 : 1;
    }
  }
  return keys;
}

/// The `android:name` of every element [element] that is a child of the
/// first element [parent] in the XML [text], in order.
List<String> _childNames(String text, String parent, String element) {
  final names = <String>[];
  final name = RegExp(r'android:name\s*=\s*"([^"]*)"');
  final tags = RegExp(r'<(/?)([A-Za-z][\w:.-]*)((?:[^>"]|"[^"]*")*?)(/?)>');
  // The tags after the one that opens the parent, if any.
  final inParent = tags
      .allMatches(_withoutXmlComments(text))
      .skipWhile((match) => !_opensElement(match, parent))
      .skip(1);
  // 0 directly in the parent, more in its descendants.
  var depth = 0;
  for (final match in inParent) {
    if (match[1] == '/') {
      if (depth == 0) break;
      depth--;
      continue;
    }
    if (depth == 0 && match[2] == element) {
      if (name.firstMatch(match[3]!) case final attribute?) {
        names.add(_unescapeXml(attribute[1]!));
      }
    }
    if (match[4] != '/') depth++;
  }
  return names;
}

/// Whether [tag], a match of the tags of [_childNames], is the start tag of
/// an element [name]: neither a closing tag nor an empty-element tag, such
/// as `<name/>`.
bool _opensElement(RegExpMatch tag, String name) =>
    tag[1] != '/' && tag[4] != '/' && tag[2] == name;

/// The plugin ids of each top-level `plugins { … }` block of the Gradle
/// script [text], which has no braces inside.
List<List<String>> _gradlePluginBlocks(String text) {
  final withoutComments = text.replaceAll(RegExp('//[^\n]*'), '');
  final id = RegExp(r'''\bid\s*\(?\s*["']([^"']+)["']''');
  return [
    for (final block in RegExp(r'^plugins\s*\{([^{}]*)\}', multiLine: true)
        .allMatches(withoutComments))
      [for (final plugin in id.allMatches(block[1]!)) plugin[1]!],
  ];
}
