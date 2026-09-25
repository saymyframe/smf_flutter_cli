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

/// A value of an `Info.plist` key in [AppEntryRole.infoPlist].
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

/// Merges `Info.plist` values: string arrays are united, other values must
/// be equal.
final class PlistMergePolicy extends MergePolicy<PlistValue> {
  /// Creates the policy.
  const PlistMergePolicy();

  @override
  String get name => 'plist';

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

String _renderString(String value) => value;

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

String _renderInfoPlist(List<MapEntry<String, PlistValue>> entries) => entries
    .map(
      (entry) =>
          '\t<key>${_escapeXml(entry.key)}</key>\n${entry.value.toXml('\t')}',
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
