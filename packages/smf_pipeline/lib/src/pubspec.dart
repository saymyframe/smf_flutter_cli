import 'dart:convert';

import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/collector.dart';

/// A dependency of the merged pubspec.
final class MergedDependency {
  /// Creates the dependency on [package].
  const MergedDependency(
    this.package, {
    required this.source,
    required this.origins,
    this.constraint,
    this.constraintText,
    this.sdk,
  });

  /// The name of the package.
  final String package;

  /// Where the package comes from.
  final PubspecSource source;

  /// The intersection of the constraints of a hosted package.
  final VersionConstraint? constraint;

  /// [constraint] as a contribution wrote it, such as `^9.1.0`, when the
  /// intersection is one of the contributed constraints; otherwise as
  /// `pub_semver` prints it, such as `>=9.2.0 <10.0.0`.
  final String? constraintText;

  /// The SDK of an SDK package.
  final String? sdk;

  /// Who contributed it.
  final List<ContributionOrigin> origins;
}

/// The `pubspec.yaml` of the app, merged from every [PubspecContribution].
final class MergedPubspec {
  /// Creates the merged pubspec.
  const MergedPubspec({
    this.dependencies = const {},
    this.devDependencies = const {},
    this.sdk,
    this.flutter,
    this.sdkText,
    this.flutterText,
    this.sdkOrigins = const [],
    this.flutterOrigins = const [],
    this.assets = const [],
    this.fonts = const [],
    this.generate = false,
    this.usesMaterialDesign = false,
  });

  /// The dependencies, by package, in the order first contributed.
  final Map<String, MergedDependency> dependencies;

  /// The dev dependencies that are not also [dependencies].
  final Map<String, MergedDependency> devDependencies;

  /// The Dart SDK constraint, if any contribution sets one.
  final VersionConstraint? sdk;

  /// The Flutter SDK constraint, if any contribution sets one.
  final VersionConstraint? flutter;

  /// [sdk] as written; see [MergedDependency.constraintText].
  final String? sdkText;

  /// [flutter] as written; see [MergedDependency.constraintText].
  final String? flutterText;

  /// The contributors whose constraints make [sdk] what it is.
  final List<ContributionOrigin> sdkOrigins;

  /// The contributors whose constraints make [flutter] what it is.
  final List<ContributionOrigin> flutterOrigins;

  /// The assets, in the order first contributed.
  final List<String> assets;

  /// The font families, with the files of every contribution.
  final List<PubspecFont> fonts;

  /// Whether the app generates code from its `l10n.yaml`.
  final bool generate;

  /// Whether the app uses the Material icons font.
  final bool usesMaterialDesign;
}

/// The result of merging the pubspec: the [pubspec] and the problems found.
final class PubspecMergeResult {
  /// Creates the result.
  const PubspecMergeResult(this.pubspec, this.issues);

  /// The merged pubspec; entries with problems are left out.
  final MergedPubspec pubspec;

  /// The problems, each with the origin of the contribution at fault.
  final List<SmfIssue> issues;
}

final RegExp _packageName = RegExp(r'^[a-z][a-z0-9_]*$');

/// Merges the [PubspecContribution]s among [contributions] that apply:
/// - constraints of the same hosted package, and SDK constraints, are
///   intersected, and an empty intersection is an error that names both
///   contributors;
/// - a package from two sources, or from two SDKs, is an error;
/// - a package that is both a dependency and a dev dependency becomes a
///   dependency with both constraints;
/// - assets are united, fonts merged by family, and flags set if any
///   contribution sets them; one font file with two weights or styles is an
///   error.
PubspecMergeResult mergePubspec(Iterable<Collected> contributions) {
  final merger = _PubspecMerger();
  for (final collected in contributions) {
    if (!collected.applies) continue;
    if (collected.contribution case final PubspecContribution contribution) {
      merger.add(contribution, collected.origin);
    }
  }
  return merger.result;
}

/// Merges the pubspec contributions of [mergePubspec], one after another.
final class _PubspecMerger {
  final List<SmfIssue> _issues = [];
  final Map<String, _Dependency> _all = {};
  final Set<String> _devOnly = {};
  _Constraint? _sdk;
  _Constraint? _flutter;
  final Set<String> _assets = {};
  final Map<String, Map<String, (PubspecFontAsset, ContributionOrigin)>>
      _fonts = {};
  bool _generate = false;
  bool _usesMaterialDesign = false;

  _Constraint? _parse(String text, String what, ContributionOrigin origin) {
    try {
      return _Constraint(VersionConstraint.parse(text), text, [origin]);
    } on FormatException {
      _issues.add(
        SmfIssue('The constraint "$text" of $what is invalid.', origin: origin),
      );
      return null;
    }
  }

  _Constraint? _merge(
    _Constraint? existing,
    String? text,
    String what,
    ContributionOrigin origin,
  ) {
    if (text == null) return existing;
    final incoming = _parse(text, what, origin);
    if (incoming == null) return existing;
    if (existing == null) return incoming;
    final merged = existing.merge(incoming);
    if (merged == null) {
      _issues.add(
        SmfIssue(
          'The constraints "${existing.text}" (from '
          '${existing.origins.join(', ')}) and "$text" (from $origin) of '
          '$what have no version in common.',
          origin: origin,
        ),
      );
      return existing;
    }
    return merged;
  }

  /// Merges [contribution] of [origin] into the pubspec.
  void add(PubspecContribution contribution, ContributionOrigin origin) {
    switch (contribution) {
      case PubspecDependency():
        _addDependency(contribution, origin);
      case PubspecEnvironment(sdk: final dart, flutter: final flutterText):
        _sdk = _merge(_sdk, dart, 'the Dart SDK', origin);
        _flutter = _merge(_flutter, flutterText, 'the Flutter SDK', origin);
      case PubspecFlutter():
        _addFlutter(contribution, origin);
    }
  }

  /// Merges [contribution] of [origin], a dependency or dev dependency,
  /// into the dependencies of the same package.
  void _addDependency(
    PubspecDependency contribution,
    ContributionOrigin origin,
  ) {
    final package = contribution.package;
    if (!_packageName.hasMatch(package)) {
      _issues.add(
        SmfIssue('"$package" is not a package name.', origin: origin),
      );
      return;
    }
    final existing = _all[package];
    if (existing == null) {
      final constraint = _merge(null, contribution.constraint, package, origin);
      if (contribution.source == PubspecSource.hosted && constraint == null) {
        return;
      }
      _all[package] = _Dependency(
        package,
        contribution.source,
        constraint,
        contribution.sdk,
        [origin],
      );
      if (contribution.dev) _devOnly.add(package);
      return;
    }
    if (existing.source != contribution.source ||
        existing.sdk != contribution.sdk) {
      _issues.add(
        SmfIssue(
          '$package comes from ${_sourceOf(existing.source, existing.sdk)} '
          '(from ${existing.origins.first}) and from '
          '${_sourceOf(contribution.source, contribution.sdk)} '
          '(from $origin).',
          origin: origin,
        ),
      );
      return;
    }
    if (!contribution.dev) _devOnly.remove(package);
    existing
      ..constraint = _merge(
        existing.constraint,
        contribution.constraint,
        package,
        origin,
      )
      ..origins.add(origin);
  }

  /// Merges the assets, fonts and flags of [contribution] of [origin].
  void _addFlutter(PubspecFlutter contribution, ContributionOrigin origin) {
    _assets.addAll(contribution.assets);
    _generate |= contribution.generate;
    _usesMaterialDesign |= contribution.usesMaterialDesign;
    for (final font in contribution.fonts) {
      final files = _fonts.putIfAbsent(font.family, () => {});
      for (final asset in font.assets) {
        final existing = files[asset.asset];
        if (existing == null) {
          files[asset.asset] = (asset, origin);
        } else if (existing.$1.weight != asset.weight ||
            existing.$1.style != asset.style) {
          _issues.add(
            SmfIssue(
              'The font file ${asset.asset} of ${font.family} has '
              'another weight or style in ${existing.$2}.',
              origin: origin,
            ),
          );
        }
      }
    }
  }

  /// The merged pubspec and the problems found.
  PubspecMergeResult get result => PubspecMergeResult(
        MergedPubspec(
          dependencies: {
            for (final MapEntry(key: package, value: dependency)
                in _all.entries)
              if (!_devOnly.contains(package)) package: _merged(dependency),
          },
          devDependencies: {
            for (final MapEntry(key: package, value: dependency)
                in _all.entries)
              if (_devOnly.contains(package)) package: _merged(dependency),
          },
          sdk: _sdk?.value,
          flutter: _flutter?.value,
          sdkText: _sdk?.text,
          flutterText: _flutter?.text,
          sdkOrigins: List.unmodifiable(_sdk?.origins ?? const []),
          flutterOrigins: List.unmodifiable(_flutter?.origins ?? const []),
          assets: List.unmodifiable(_assets),
          fonts: [
            for (final MapEntry(key: family, value: files) in _fonts.entries)
              PubspecFont(
                family,
                [for (final (asset, _) in files.values) asset],
              ),
          ],
          generate: _generate,
          usesMaterialDesign: _usesMaterialDesign,
        ),
        _issues,
      );

  static MergedDependency _merged(_Dependency dependency) => MergedDependency(
        dependency.package,
        source: dependency.source,
        constraint: dependency.constraint?.value,
        constraintText: dependency.constraint?.text,
        sdk: dependency.sdk,
        origins: List.unmodifiable(dependency.origins),
      );
}

/// A constraint merged from contributions: its value, its text, and the
/// contributors whose constraints make it what it is.
final class _Constraint {
  _Constraint(this.value, this.text, this.origins);

  final VersionConstraint value;
  final String text;
  final List<ContributionOrigin> origins;

  /// The intersection with [incoming], or `null` if it is empty.
  ///
  /// When the intersection is one of the two constraints, it keeps that
  /// one's text and contributors; a constraint that allows every version,
  /// such as `any`, narrows nothing and adds no contributor.
  _Constraint? merge(_Constraint incoming) {
    final result = value.intersect(incoming.value);
    if (result.isEmpty) return null;
    if (incoming.value.isAny || result == value) {
      return result == incoming.value && !incoming.value.isAny
          ? _Constraint(value, text, [...origins, ...incoming.origins])
          : this;
    }
    if (value.isAny || result == incoming.value) return incoming;
    return _Constraint(
      result,
      '$result',
      [...origins, ...incoming.origins],
    );
  }
}

String _sourceOf(PubspecSource source, String? sdk) => switch (source) {
      PubspecSource.hosted => 'pub.dev',
      PubspecSource.sdk => 'the $sdk SDK',
    };

final class _Dependency {
  _Dependency(
    this.package,
    this.source,
    this.constraint,
    this.sdk,
    this.origins,
  );

  final String package;
  final PubspecSource source;
  _Constraint? constraint;
  final String? sdk;
  final List<ContributionOrigin> origins;
}

/// The text of every socket of the pipeline in `pubspec.yaml`, by tag: each
/// section of [pubspec] headed by its key, or nothing if the section has no
/// entries.
///
/// SDK dependencies come first, then the others, each by name, so the
/// pubspec does not depend on the order of the modules. Every string is
/// quoted, since a constraint such as `>=1.0.0 <2.0.0` cannot stand bare in
/// YAML.
Map<String, String> pubspecSocketTexts(MergedPubspec pubspec) {
  String section(String key, List<String> lines) =>
      lines.isEmpty ? '' : ['$key:', ...lines].join('\n');

  return {
    PipelineSockets.pubspecEnvironment.tag: section('environment', [
      if (pubspec.sdkText case final sdk?) '  sdk: ${_quoted(sdk)}',
      if (pubspec.flutterText case final flutter?)
        '  flutter: ${_quoted(flutter)}',
    ]),
    PipelineSockets.pubspecDependencies.tag:
        section('dependencies', _dependencyLines(pubspec.dependencies)),
    PipelineSockets.pubspecDevDependencies.tag:
        section('dev_dependencies', _dependencyLines(pubspec.devDependencies)),
    PipelineSockets.pubspecFlutter.tag: section('flutter', [
      if (pubspec.usesMaterialDesign) '  uses-material-design: true',
      if (pubspec.generate) '  generate: true',
      if (pubspec.assets.isNotEmpty) '  assets:',
      for (final asset in pubspec.assets) '    - ${_quoted(asset)}',
      ..._fontLines(pubspec.fonts),
    ]),
  };
}

/// [text] as a YAML string.
String _quoted(String text) => jsonEncode(text);

/// The lines of [dependencies] in a section of `pubspec.yaml`: those of an
/// SDK first, then the others, each by name.
List<String> _dependencyLines(Map<String, MergedDependency> dependencies) {
  int byName(MergedDependency a, MergedDependency b) =>
      a.package.compareTo(b.package);
  final sdk = [
    for (final dependency in dependencies.values)
      if (dependency.source == PubspecSource.sdk) dependency,
  ]..sort(byName);
  final hosted = [
    for (final dependency in dependencies.values)
      if (dependency.source != PubspecSource.sdk) dependency,
  ]..sort(byName);
  return [
    for (final dependency in sdk) ...[
      '  ${dependency.package}:',
      '    sdk: ${dependency.sdk}',
    ],
    for (final dependency in hosted)
      '  ${dependency.package}: ${_quoted(dependency.constraintText!)}',
  ];
}

/// The lines of [fonts] in the section `flutter` of `pubspec.yaml`.
List<String> _fontLines(List<PubspecFont> fonts) => [
      if (fonts.isNotEmpty) '  fonts:',
      for (final font in fonts) ...[
        '    - family: ${_quoted(font.family)}',
        '      fonts:',
        for (final asset in font.assets) ...[
          '        - asset: ${_quoted(asset.asset)}',
          if (asset.weight case final weight?) '          weight: $weight',
          if (asset.style case final style?)
            '          style: ${_quoted(style)}',
        ],
      ],
    ];
