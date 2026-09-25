import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/lego_core.dart';
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
  final issues = <SmfIssue>[];
  final all = <String, _Dependency>{};
  final devOnly = <String>{};
  _Constraint? sdk;
  _Constraint? flutter;
  final assets = <String>{};
  final fonts = <String, Map<String, (PubspecFontAsset, ContributionOrigin)>>{};
  var generate = false;
  var usesMaterialDesign = false;

  _Constraint? parse(String text, String what, ContributionOrigin origin) {
    try {
      return _Constraint(VersionConstraint.parse(text), text, [origin]);
    } on FormatException {
      issues.add(
        SmfIssue('The constraint "$text" of $what is invalid.', origin: origin),
      );
      return null;
    }
  }

  _Constraint? merge(
    _Constraint? existing,
    String? text,
    String what,
    ContributionOrigin origin,
  ) {
    if (text == null) return existing;
    final incoming = parse(text, what, origin);
    if (incoming == null) return existing;
    if (existing == null) return incoming;
    final merged = existing.merge(incoming);
    if (merged == null) {
      issues.add(
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

  for (final collected in contributions) {
    if (!collected.applies) continue;
    final contribution = collected.contribution;
    if (contribution is! PubspecContribution) continue;
    final origin = collected.origin;
    switch (contribution) {
      case PubspecDependency():
        final package = contribution.package;
        if (!_packageName.hasMatch(package)) {
          issues.add(
            SmfIssue('"$package" is not a package name.', origin: origin),
          );
          continue;
        }
        final existing = all[package];
        if (existing == null) {
          final constraint =
              merge(null, contribution.constraint, package, origin);
          if (contribution.source == PubspecSource.hosted &&
              constraint == null) {
            continue;
          }
          all[package] = _Dependency(
            package,
            contribution.source,
            constraint,
            contribution.sdk,
            [origin],
          );
          if (contribution.dev) devOnly.add(package);
          continue;
        }
        if (existing.source != contribution.source ||
            existing.sdk != contribution.sdk) {
          issues.add(
            SmfIssue(
              '$package comes from ${_sourceOf(existing.source, existing.sdk)} '
              '(from ${existing.origins.first}) and from '
              '${_sourceOf(contribution.source, contribution.sdk)} '
              '(from $origin).',
              origin: origin,
            ),
          );
          continue;
        }
        if (!contribution.dev) devOnly.remove(package);
        existing
          ..constraint = merge(
            existing.constraint,
            contribution.constraint,
            package,
            origin,
          )
          ..origins.add(origin);
      case PubspecEnvironment(sdk: final dart, flutter: final flutterText):
        sdk = merge(sdk, dart, 'the Dart SDK', origin);
        flutter = merge(flutter, flutterText, 'the Flutter SDK', origin);
      case PubspecFlutter():
        assets.addAll(contribution.assets);
        generate |= contribution.generate;
        usesMaterialDesign |= contribution.usesMaterialDesign;
        for (final font in contribution.fonts) {
          final files = fonts.putIfAbsent(font.family, () => {});
          for (final asset in font.assets) {
            final existing = files[asset.asset];
            if (existing == null) {
              files[asset.asset] = (asset, origin);
            } else if (existing.$1.weight != asset.weight ||
                existing.$1.style != asset.style) {
              issues.add(
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
  }

  MergedDependency merged(_Dependency dependency) => MergedDependency(
        dependency.package,
        source: dependency.source,
        constraint: dependency.constraint?.value,
        constraintText: dependency.constraint?.text,
        sdk: dependency.sdk,
        origins: List.unmodifiable(dependency.origins),
      );

  return PubspecMergeResult(
    MergedPubspec(
      dependencies: {
        for (final MapEntry(key: package, value: dependency) in all.entries)
          if (!devOnly.contains(package)) package: merged(dependency),
      },
      devDependencies: {
        for (final MapEntry(key: package, value: dependency) in all.entries)
          if (devOnly.contains(package)) package: merged(dependency),
      },
      sdk: sdk?.value,
      flutter: flutter?.value,
      sdkText: sdk?.text,
      flutterText: flutter?.text,
      sdkOrigins: List.unmodifiable(sdk?.origins ?? const []),
      flutterOrigins: List.unmodifiable(flutter?.origins ?? const []),
      assets: List.unmodifiable(assets),
      fonts: [
        for (final MapEntry(key: family, value: files) in fonts.entries)
          PubspecFont(family, [for (final (asset, _) in files.values) asset]),
      ],
      generate: generate,
      usesMaterialDesign: usesMaterialDesign,
    ),
    issues,
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
