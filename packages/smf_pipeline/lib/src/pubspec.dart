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
    this.sdk,
  });

  /// The name of the package.
  final String package;

  /// Where the package comes from.
  final PubspecSource source;

  /// The intersection of the constraints of a hosted package.
  final VersionConstraint? constraint;

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
  VersionConstraint? sdk;
  VersionConstraint? flutter;
  final sdkOrigins = <String, ContributionOrigin>{};
  final assets = <String>{};
  final fonts = <String, Map<String, (PubspecFontAsset, ContributionOrigin)>>{};
  var generate = false;
  var usesMaterialDesign = false;

  VersionConstraint? parse(
    String text,
    String what,
    ContributionOrigin origin,
  ) {
    try {
      return VersionConstraint.parse(text);
    } on FormatException {
      issues.add(
        SmfIssue('The constraint "$text" of $what is invalid.', origin: origin),
      );
      return null;
    }
  }

  VersionConstraint? intersect(
    VersionConstraint? existing,
    VersionConstraint incoming,
    String what,
    ContributionOrigin? existingOrigin,
    ContributionOrigin origin,
  ) {
    if (existing == null) return incoming;
    final result = existing.intersect(incoming);
    if (result.isEmpty) {
      issues.add(
        SmfIssue(
          'The constraints "$existing" (from ${existingOrigin ?? 'unknown'}) '
          'and "$incoming" (from $origin) of $what have no version in '
          'common.',
          origin: origin,
        ),
      );
      return existing;
    }
    return result;
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
          final constraint = switch (contribution.constraint) {
            final text? => parse(text, package, origin),
            null => null,
          };
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
        if (!contribution.dev) devOnly.remove(package);
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
        if (contribution.constraint case final text?) {
          final constraint = parse(text, package, origin);
          if (constraint != null) {
            existing.constraint = intersect(
              existing.constraint,
              constraint,
              package,
              existing.origins.last,
              origin,
            );
          }
        }
        existing.origins.add(origin);
      case PubspecEnvironment(sdk: final dart, flutter: final flutterText):
        if (dart != null) {
          final constraint = parse(dart, 'the Dart SDK', origin);
          if (constraint != null) {
            sdk = intersect(
              sdk,
              constraint,
              'the Dart SDK',
              sdkOrigins['sdk'],
              origin,
            );
            sdkOrigins['sdk'] = origin;
          }
        }
        if (flutterText != null) {
          final constraint = parse(flutterText, 'the Flutter SDK', origin);
          if (constraint != null) {
            flutter = intersect(
              flutter,
              constraint,
              'the Flutter SDK',
              sdkOrigins['flutter'],
              origin,
            );
            sdkOrigins['flutter'] = origin;
          }
        }
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
        constraint: dependency.constraint,
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
      sdk: sdk,
      flutter: flutter,
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
  VersionConstraint? constraint;
  final String? sdk;
  final List<ContributionOrigin> origins;
}
