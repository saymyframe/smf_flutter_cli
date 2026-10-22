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
/// heading is one line, that a section has text, and that only the template
/// of the app entry role writes the section of the steps by hand.
final class _ReadmeSectionPolicy extends MergePolicy<String> {
  const _ReadmeSectionPolicy();

  @override
  String? problemFrom(ContributionOrigin? origin, String key, String value) {
    if (key == AppEntryRole.setupHeading &&
        origin != null &&
        origin != const RoleTemplateOrigin(appEntryRole)) {
      final who = switch (origin) {
        ModuleOrigin(:final module) => 'The module $module',
        RoleTemplateOrigin(:final role) => 'The template of the $role',
        PipelineOrigin() => 'The pipeline',
      };
      return '$who contributes the section "$key" of the README, which only '
          'the template of the app entry role writes, from the steps of the '
          'app that its developer does by hand. A step by hand is a '
          'ManualStep of its contributor, which that section lists.';
    }
    return problemWith(key, value);
  }

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

/// Keeps one comment for each pattern of `.gitignore`, and checks that a
/// pattern is one line that neither comments nor brings back what another
/// line ignores, without a backslash, under a comment of one line.
final class _GitignorePolicy extends MergePolicy<String> {
  const _GitignorePolicy();

  @override
  String? problemWith(String key, String value) {
    if (!_isOneLine(key)) {
      return 'The pattern "$key" of .gitignore is not one line of text '
          'without spaces around it.';
    }
    if (key.contains(r'\')) {
      return 'The pattern "$key" of .gitignore has a backslash, which git '
          'reads as an escape.';
    }
    if (key.startsWith('#')) {
      return 'The pattern "$key" of .gitignore starts with "#", which makes '
          'its line a comment.';
    }
    if (key.startsWith('!')) {
      return 'The pattern "$key" of .gitignore starts with "!", which brings '
          'back what a line before it ignores. The patterns come in the '
          'order of their text, so none may bring back what another ignores.';
    }
    if (!_isOneLine(value)) {
      return 'The comment "$value" of the pattern "$key" of .gitignore is '
          'not one line of text without spaces around it.';
    }
    // As it renders: before a line break.
    if (Fragment.hasStrippedBackslash('$value\n')) {
      return 'The comment "$value" of the pattern "$key" of .gitignore has a '
          'backslash at its end or before a non-ASCII character, which mason '
          'removes.';
    }
    return null;
  }

  @override
  String merge(String key, String existing, String incoming) =>
      const ConflictPolicy<String>().merge(key, existing, incoming);
}

/// Whether [text] is one line of text without spaces around it.
bool _isOneLine(String text) =>
    text.isNotEmpty &&
    text == text.trim() &&
    !text.contains('\n') &&
    !text.contains('\r');

/// Each pattern of `.gitignore` under its comment, after an empty line, in
/// the order of the patterns.
String _renderGitignore(List<MapEntry<String, String>> entries) =>
    ([...entries]..sort((a, b) => a.key.compareTo(b.key)))
        .map((entry) => '\n# ${entry.value}\n${entry.key}')
        .join('\n');

String _renderString(String value) => value;

/// Each section under its heading, after an empty line: the section of the
/// steps by hand first, then the others in the order of the contributions.
String _renderReadmeSections(List<MapEntry<String, String>> entries) {
  bool isSetup(MapEntry<String, String> entry) =>
      entry.key == AppEntryRole.setupHeading;
  return [...entries.where(isSetup), ...entries.where((e) => !isSetup(e))]
      .map((entry) => '\n## ${entry.key}\n\n${entry.value.trim()}')
      .join('\n');
}

List<SmfIssue> _checkReadmeGeneratedWith(StructuralRuleInput<NoDsl> input) {
  const path = AppEntryRole.readmeFile;
  final text = input.texts[path];
  if (text == null) return const [];
  final introduction =
      text.split('\n').takeWhile((line) => !line.startsWith('## '));
  if (introduction.any((line) => line.trim() == AppEntryRole.generatedWith)) {
    return const [];
  }
  return [
    SmfIssue(
      '$path does not say that Say My Frame generated the app: it has no '
      'line "${AppEntryRole.generatedWith}" before its first section.',
      hint: 'Write the line of AppEntryRole.generatedWith under the title of '
          'the README of the provider.',
      origin: input.owners[path],
      path: path,
    ),
  ];
}

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

String _renderDesugaringEnabled(String version) =>
    '        isCoreLibraryDesugaringEnabled = true';

String _renderDesugaringLibrary(String version) {
  final library =
      'com.android.tools:desugar_jdk_libs:${_escapeKotlin(version)}';
  return '    coreLibraryDesugaring("$library")';
}

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _escapeKotlin(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('"', r'\"').replaceAll(r'$', r'\$');

/// The sockets that render complete lines of a file, with the file: every
/// tag of such a socket stands alone on its lines.
const _lineSockets = <(SocketRef, String)>[
  (
    AppEntryRole.androidManifestPermissions,
    AppEntryRole.androidManifestFile,
  ),
  (
    AppEntryRole.androidManifestApplicationMeta,
    AppEntryRole.androidManifestFile,
  ),
  (
    AppEntryRole.androidManifestApplicationComponents,
    AppEntryRole.androidManifestFile,
  ),
  (AppEntryRole.mainActivityIntentFilters, AppEntryRole.androidManifestFile),
  (AppEntryRole.infoPlist, AppEntryRole.infoPlistFile),
  (AppEntryRole.iosEntitlements, AppEntryRole.iosEntitlementsFile),
  (AppEntryRole.iosAppDelegateLaunch, AppEntryRole.appDelegateFile),
  (AppEntryRole.gradleSettingsPlugins, AppEntryRole.gradleSettingsFile),
  (AppEntryRole.gradleAppPlugins, AppEntryRole.gradleAppFile),
  (AppEntryRole.gradleAppDependencies, AppEntryRole.gradleAppFile),
  (AppEntryRole.androidCoreLibraryDesugaring, AppEntryRole.gradleAppFile),
  (AppEntryRole.gitignore, AppEntryRole.gitignoreFile),
  (AppEntryRole.readmeSections, AppEntryRole.readmeFile),
];

List<SmfIssue> _checkTagLines(ModuleRuleInput<NoDsl> input) {
  final origin = ModuleOrigin(input.module.id);
  final templates = _templatesOf(input.contributions);
  return [
    for (final (socket, path) in _lineSockets)
      for (final name in socket.tags)
        ..._tagLineIssues('{{{$name}}}', path, templates, origin),
  ];
}

/// The problems of [tag], the tag of a socket whose lines belong in the
/// file at [path], in the [templates] of a module of [origin]: it is in
/// another template, or not alone at the start of its lines.
Iterable<SmfIssue> _tagLineIssues(
  String tag,
  String path,
  Map<String, String> templates,
  ContributionOrigin origin,
) sync* {
  for (final MapEntry(key: template, value: text) in templates.entries) {
    if (!text.contains(tag)) continue;
    if (template != path) {
      yield SmfIssue(
        'The tag $tag is in $template, but its lines belong in $path.',
        origin: origin,
        path: template,
      );
    } else if (tag.allMatches(text).length !=
        text.split('\n').where((line) => line.trimRight() == tag).length) {
      yield SmfIssue(
        'The tag $tag must stand alone at the start of a line of $path, '
        'because its contributions render as complete lines.',
        origin: origin,
        path: path,
      );
    }
  }
}

/// The sockets of the Android manifest, each with the element whose
/// children its contributions are.
const _manifestSockets = <(SocketRef, String)>[
  (AppEntryRole.androidManifestPermissions, 'manifest'),
  (AppEntryRole.androidManifestApplicationMeta, 'application'),
  (AppEntryRole.androidManifestApplicationComponents, 'application'),
  (AppEntryRole.mainActivityIntentFilters, 'activity'),
];

List<SmfIssue> _checkManifestTagPlaces(ModuleRuleInput<NoDsl> input) {
  const path = AppEntryRole.androidManifestFile;
  final template = _templatesOf(input.contributions)[path] ?? '';
  // The comments, blanked so that the offsets of the rest stay.
  final text = template.replaceAllMapped(
    RegExp('<!--.*?-->', dotAll: true),
    (comment) => ' ' * comment[0]!.length,
  );
  return [
    for (final (socket, parent) in _manifestSockets)
      if (text.indexOf('{{{${socket.tag}}}}') case final offset
          when offset >= 0 && _elementAt(text, offset) != parent)
        SmfIssue(
          'The tag {{{${socket.tag}}}} is in $path, but not among the '
          'children of <$parent>, where its contributions belong.',
          origin: ModuleOrigin(input.module.id),
          path: path,
        ),
  ];
}

/// The name of the innermost element that is open at [offset] of the XML
/// [text], which has no comments, or `null` outside every element.
String? _elementAt(String text, int offset) {
  final open = <String>[];
  for (final tag in _xmlTags.allMatches(text.substring(0, offset))) {
    if (tag[1] == '/') {
      if (open.isNotEmpty) open.removeLast();
    } else if (tag[4] != '/') {
      open.add(tag[2]!);
    }
  }
  return open.lastOrNull;
}

List<SmfIssue> _checkNativeKeys(StructuralRuleInput<NoDsl> input) {
  final texts = input.texts;
  return [
    for (final path in const [
      AppEntryRole.infoPlistFile,
      AppEntryRole.iosEntitlementsFile,
    ])
      if (texts[path] case final plist?)
        ..._repeatedIssues(input, path, 'the key', _plistKeys(plist)),
    if (texts[AppEntryRole.androidManifestFile] case final manifest?)
      ..._repeatedInManifest(input, manifest),
    for (final path in const [
      AppEntryRole.gradleSettingsFile,
      AppEntryRole.gradleAppFile,
    ])
      for (final plugins in _gradlePluginBlocks(texts[path] ?? ''))
        ..._repeatedIssues(input, path, 'the plugin', plugins),
  ];
}

/// The problems of [manifest], the text of the Android manifest of the app
/// of [input]: each permission, meta-data and component of a kind that it
/// declares more than once, a component by its name as Android resolves it
/// against the namespace of the app.
List<SmfIssue> _repeatedInManifest(
  StructuralRuleInput<NoDsl> input,
  String manifest,
) {
  const path = AppEntryRole.androidManifestFile;
  final namespace = _namespaceOf(input.texts[AppEntryRole.gradleAppFile] ?? '');
  return [
    ..._repeatedIssues(
      input,
      path,
      'the permission',
      _childNames(manifest, 'manifest', 'uses-permission'),
    ),
    ..._repeatedIssues(
      input,
      path,
      'the meta-data',
      _childNames(manifest, 'application', 'meta-data'),
    ),
    for (final component in _components)
      ..._repeatedIssues(
        input,
        path,
        'the $component',
        [
          for (final name in _childNames(manifest, 'application', component))
            _resolvedName(name, namespace),
        ],
        hint: 'One module declares a component, and none declares one that '
            'the template of the app entry role has, such as its main '
            'activity.',
      ),
  ];
}

/// The problems of [keys], the keys of a kind [what], such as `the key`,
/// that the file at [path] of the app of [input] has, in their order: each
/// key that it has more than once, reported once, with [hint].
List<SmfIssue> _repeatedIssues(
  StructuralRuleInput<NoDsl> input,
  String path,
  String what,
  List<String> keys, {
  String hint = 'A module cannot contribute a key that the template of the '
      'app entry role has already.',
}) {
  final issues = <SmfIssue>[];
  final seen = <String>{};
  final reported = <String>{};
  for (final key in keys) {
    if (seen.add(key) || !reported.add(key)) continue;
    issues.add(
      SmfIssue(
        '$path has $what $key more than once.',
        hint: hint,
        origin: input.owners[path],
        path: path,
      ),
    );
  }
  return issues;
}

/// The kinds of the components of the application of an Android manifest,
/// each declared once under its `android:name`: the build of the app fails
/// on two declarations of a component that differ, and keeps both of two
/// equal ones in the merged manifest.
const _components = [
  'activity',
  'activity-alias',
  'service',
  'receiver',
  'provider',
];

/// The `namespace` of the Gradle build script of the app [text], against
/// which Android resolves a relative name of a component, or `null` if it
/// sets none.
String? _namespaceOf(String text) => RegExp(
      r'''^\s*namespace\s*=?\s*["']([^"']+)["']''',
      multiLine: true,
    ).firstMatch(text.replaceAll(RegExp('//[^\n]*'), ''))?[1];

/// [name], the `android:name` of a component, as Android resolves it: a
/// name that starts with a dot, or has none, is relative to [namespace],
/// and stays as it is written when the app sets no namespace.
String _resolvedName(String name, String? namespace) {
  if (namespace == null) return name;
  if (name.startsWith('.')) return '$namespace$name';
  return name.contains('.') ? name : '$namespace.$name';
}

/// The text of the Xcode project [text] without its comments: those
/// between `/*` and `*/`, and those from `//` to the end of the line, but
/// none in a string in quotes.
String _withoutProjectComments(String text) {
  final kept = StringBuffer();
  var i = 0;
  while (i < text.length) {
    if (text[i] == '"') {
      final end = _endOfString(text, i);
      kept.write(text.substring(i, end));
      i = end;
    } else if (text.startsWith('/*', i)) {
      final end = text.indexOf('*/', i + 2);
      i = end < 0 ? text.length : end + 2;
    } else if (text.startsWith('//', i)) {
      final end = text.indexOf('\n', i);
      i = end < 0 ? text.length : end;
    } else {
      kept.write(text[i]);
      i++;
    }
  }
  return kept.toString();
}

/// The index after the string in quotes that starts at [start] in [text],
/// or the length of [text] when the string does not end.
int _endOfString(String text, int start) {
  for (var i = start + 1; i < text.length; i++) {
    if (text[i] == r'\') {
      i++;
    } else if (text[i] == '"') {
      return i + 1;
    }
  }
  return text.length;
}

/// The index of the `}` that closes the `{` at [open] in [text], which has
/// no comments, whatever the braces in its strings, or the length of
/// [text] when none does.
int _closingBrace(String text, int open) {
  var depth = 0;
  var i = open;
  while (i < text.length) {
    final char = text[i];
    if (char == '"') {
      i = _endOfString(text, i);
      continue;
    }
    if (char == '{') depth++;
    if (char == '}' && --depth == 0) return i;
    i++;
  }
  return text.length;
}

/// The start of an object of an Xcode project without comments: its id,
/// and its `isa`, which Xcode writes first.
final _projectObject = RegExp(r'(\w+)\s*=\s*\{\s*isa\s*=\s*"?(\w+)"?\s*;');

/// An object of an Xcode project: its `id`, its `isa`, such as
/// `XCBuildConfiguration`, and the text between its braces, its `body`.
typedef _ProjectObject = ({String id, String isa, String body});

/// The objects of the Xcode project [text], which has no comments.
List<_ProjectObject> _projectObjects(String text) {
  final objects = <_ProjectObject>[];
  for (final start in _projectObject.allMatches(text)) {
    final open = text.indexOf('{', start.start);
    objects.add(
      (
        id: start[1]!,
        isa: start[2]!,
        body: text.substring(open + 1, _closingBrace(text, open)),
      ),
    );
  }
  return objects;
}

/// The ids of the build configurations of the project itself, whose
/// settings every target inherits, in the Xcode project of [objects].
Set<String> _projectConfigurations(List<_ProjectObject> objects) {
  final list = RegExp(r'buildConfigurationList\s*=\s*(\w+)\s*;');
  return {
    for (final project in objects)
      if (project.isa == 'PBXProject')
        if (list.firstMatch(project.body)?[1] case final listId?)
          ..._configurationsIn(listId, objects),
  };
}

/// The ids of the build configurations in the configuration list [listId]
/// of the Xcode project of [objects], in their order.
List<String> _configurationsIn(String listId, List<_ProjectObject> objects) {
  final ids = RegExp(r'buildConfigurations\s*=\s*\(([^)]*)\)');
  return [
    for (final configurations in objects)
      if (configurations.id == listId)
        if (ids.firstMatch(configurations.body)?[1] case final items?)
          ...RegExp(r'\w+').allMatches(items).map((id) => id[0]!),
  ];
}

/// The build settings of the build configuration whose object has [body],
/// and its name, if any.
({String settings, String? name}) _buildConfiguration(String body) {
  final open = RegExp(r'buildSettings\s*=\s*\{').firstMatch(body);
  if (open == null) return (settings: '', name: _nameSetting(body));
  final close = _closingBrace(body, open.end - 1);
  return (
    settings: body.substring(open.end, close),
    name: _nameSetting(body.replaceRange(open.start, close, '')),
  );
}

/// The value of the setting `name` in [text], if any.
String? _nameSetting(String text) =>
    RegExp(r'\bname\s*=\s*"?([^";]*)"?\s*;').firstMatch(text)?[1]!.trim();

/// The setting `INFOPLIST_FILE` of build settings, with its value.
final _infoPlistSetting = RegExp(
  r'(?:^|(?<=;))\s*"?INFOPLIST_FILE"?\s*=\s*"?([^";]*)"?\s*;',
  multiLine: true,
);

/// A setting `CODE_SIGN_ENTITLEMENTS` of build settings, with its
/// condition, such as `[sdk=iphoneos*]`, if any, and its value.
final _entitlementsSetting = RegExp(
  r'(?:^|(?<=;))\s*"?CODE_SIGN_ENTITLEMENTS(\[[^\]]*\])?"?\s*=\s*"?([^";]*)"?'
  r'\s*;',
  multiLine: true,
);

/// [path], a path of the app in its iOS project, as the build settings of
/// [AppEntryRole.xcodeProjectFile] name it: from the directory of that
/// project, such as `Runner/Info.plist`.
String _inIosProject(String path) => path.substring(path.indexOf('/') + 1);

List<SmfIssue> _checkIosEntitlementsSigned(StructuralRuleInput<NoDsl> input) {
  const path = AppEntryRole.xcodeProjectFile;
  const file = AppEntryRole.iosEntitlementsFile;
  final text = input.texts[path];
  if (text == null) return const [];
  final origin = input.owners[path];
  final infoPlist = _inIosProject(AppEntryRole.infoPlistFile);
  final configurations = _signingConfigurationsOf(text);
  final issues = [
    for (final configuration in configurations)
      if (_signingProblemOf(configuration) case (:final message, :final hint))
        SmfIssue(message, hint: hint, origin: origin, path: path),
  ];
  if (!configurations.any((configuration) => configuration.ofApp)) {
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

/// A build configuration of the Xcode project of the app, as the check of
/// the entitlements of the app sees it: how a problem names it, `named`,
/// whether it is one of the project itself, whose settings every target
/// inherits, `ofProject`, or one of the app target, which reads the
/// Info.plist of the app, `ofApp`, and its settings of
/// CODE_SIGN_ENTITLEMENTS, `signing`, each with its condition, if any, and
/// its value.
typedef _SigningConfiguration = ({
  String named,
  bool ofProject,
  bool ofApp,
  List<({String? condition, String value})> signing,
});

/// The build configurations of the Xcode project [text], in their order.
List<_SigningConfiguration> _signingConfigurationsOf(String text) {
  final objects = _projectObjects(_withoutProjectComments(text));
  final ofProject = _projectConfigurations(objects);
  return [
    for (final object in objects)
      if (object.isa == 'XCBuildConfiguration')
        _signingConfigurationOf(
          object,
          ofProject: ofProject.contains(object.id),
        ),
  ];
}

/// The build configuration whose object in the Xcode project is [object],
/// one of the project itself if [ofProject].
_SigningConfiguration _signingConfigurationOf(
  _ProjectObject object, {
  required bool ofProject,
}) {
  final infoPlist = _inIosProject(AppEntryRole.infoPlistFile);
  final (:settings, :name) = _buildConfiguration(object.body);
  return (
    named: 'The build configuration '
        '${name == null ? object.id : '$name (${object.id})'}',
    ofProject: ofProject,
    ofApp: !ofProject &&
        _infoPlistSetting
            .allMatches(settings)
            .any((setting) => setting[1]!.trim() == infoPlist),
    signing: [
      for (final setting in _entitlementsSetting.allMatches(settings))
        (condition: setting[1], value: setting[2]!.trim()),
    ],
  );
}

/// The problem of [configuration] with the entitlements of the app, its
/// message and its hint, or `null`: a build configuration of the project
/// names no entitlements, which every target would inherit, one of the app
/// target signs the app with its entitlements and with nothing else, and
/// one of another target does not sign with them.
({String message, String hint})? _signingProblemOf(
  _SigningConfiguration configuration,
) {
  const path = AppEntryRole.xcodeProjectFile;
  const file = AppEntryRole.iosEntitlementsFile;
  final infoPlist = _inIosProject(AppEntryRole.infoPlistFile);
  final entitlements = _inIosProject(file);
  final (:named, :ofProject, :ofApp, :signing) = configuration;
  if (ofProject) {
    if (signing.isEmpty) return null;
    return (
      message: '$named of the project in $path names entitlements in '
          'CODE_SIGN_ENTITLEMENTS, which every target without a setting of '
          'its own inherits, such as the tests.',
      hint: 'Set CODE_SIGN_ENTITLEMENTS in the build configurations of each '
          'target that signs with entitlements: $entitlements in those of '
          'the app target, which read $infoPlist.',
    );
  }
  if (ofApp) {
    if (signing case [(condition: null, :final value)]
        when value == entitlements) {
      return null;
    }
    return (
      message: '$named of the app target in $path does not sign the app '
          'with $file.',
      hint: 'Each build configuration with INFOPLIST_FILE = $infoPlist has '
          'CODE_SIGN_ENTITLEMENTS = $entitlements; and no other '
          'CODE_SIGN_ENTITLEMENTS. Without it the app builds and signs, but '
          'has none of the entitlements that the modules add.',
    );
  }
  if (signing.any((setting) => setting.value == entitlements)) {
    return (
      message: '$named in $path, which is not one of the app target, signs '
          'with the entitlements of the app, $file.',
      hint: 'Only the app target signs with $file. Another target, such as '
          'an app extension, signs with entitlements of its own.',
    );
  }
  return null;
}

/// The problem of an app whose entitlements have a key of
/// [AppEntryRole.paidTeamEntitlements] without [AppEntryRole.iosAppIdStep]
/// among its steps by hand, as the owner of the entitlements; nothing in
/// an app without the file, such as one that the harness did not render.
List<SmfIssue> _checkIosAppIdStep(StructuralRuleInput<NoDsl> input) {
  const path = AppEntryRole.iosEntitlementsFile;
  final text = input.texts[path];
  if (text == null) return const [];
  final keys = {
    for (final key in _plistKeys(text))
      if (AppEntryRole.paidTeamEntitlements.contains(key)) key,
  };
  const step = AppEntryRole.iosAppIdStep;
  final steps = input.roleInput.manualSetup.steps;
  if (keys.isEmpty || steps.any((listed) => listed.id == step.id)) {
    return const [];
  }
  return [
    SmfIssue(
      '$path has the ${keys.length == 1 ? 'entitlement' : 'entitlements'} '
      '${keys.join(', ')}, which only a team of the paid Apple Developer '
      'Program signs, but the app does not list the step by hand ${step.id}: '
      '"${step.title}".',
      hint: 'The module or the template of a role that adds such an '
          'entitlement lists AppEntryRole.iosAppIdStep with it, under the '
          'same roles: AppEntryRole.paidTeamEntitlement gives both.',
      origin: input.owners[path],
      path: path,
    ),
  ];
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
  final name = RegExp(r'''android:name\s*=\s*(?:"([^"]*)"|'([^']*)')''');
  // The tags after the one that opens the parent, if any.
  final inParent = _xmlTags
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
        names.add(_unescapeXml(attribute[1] ?? attribute[2]!));
      }
    }
    if (match[4] != '/') depth++;
  }
  return names;
}

/// The start tags, end tags and empty-element tags of XML: whether it is an
/// end tag, the name of the element, its attributes, whose values in
/// either quotes may hold a `>`, and whether it is an empty-element tag.
final _xmlTags =
    RegExp(r'''<(/?)([A-Za-z][\w:.-]*)((?:[^>"']|"[^"]*"|'[^']*')*?)(/?)>''');

/// Whether [tag], a match of [_xmlTags], is the start tag of
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
