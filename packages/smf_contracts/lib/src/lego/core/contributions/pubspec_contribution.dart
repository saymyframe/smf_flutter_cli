part of '../contributions.dart';

/// A part of the generated app's `pubspec.yaml`: a dependency, an SDK
/// constraint, or settings of the `flutter:` section.
///
/// The pipeline merges the contributions of all modules before rendering
/// and writes the result into the [PipelineSockets] of the `pubspec.yaml`
/// template:
/// - constraints of the same hosted package, and SDK constraints, are
///   intersected; an empty intersection is an error;
/// - a package that is both a dependency and a dev dependency becomes a
///   dependency;
/// - assets are united, fonts merged by family, and flags such as `generate`
///   are set if any contribution sets them.
sealed class PubspecContribution extends Contribution {
  const PubspecContribution({super.when});

  /// Depends on [package] from pub.dev with a version [constraint], such as
  /// `^16.3.0`, or `any` for a package whose constraint another module
  /// owns.
  ///
  /// Set [dev] for a dev dependency.
  const factory PubspecContribution.hosted(
    String package,
    String constraint, {
    bool dev,
    Set<Role> when,
  }) = PubspecDependency.hosted;

  /// Depends on [package] from an SDK, such as `flutter_localizations`
  /// from the `flutter` SDK.
  ///
  /// Set [dev] for a dev dependency.
  const factory PubspecContribution.sdk(
    String package, {
    String sdk,
    bool dev,
    Set<Role> when,
  }) = PubspecDependency.sdk;

  /// Depends on [package] from the git repository [url], at [ref] and in
  /// the directory [path] of the repository, if they are set.
  ///
  /// Set [dev] for a dev dependency.
  const factory PubspecContribution.git(
    String package, {
    required String url,
    String? ref,
    String? path,
    bool dev,
    Set<Role> when,
  }) = PubspecDependency.git;

  /// Depends on [package] in the local directory [path].
  ///
  /// Set [dev] for a dev dependency.
  const factory PubspecContribution.path(
    String package,
    String path, {
    bool dev,
    Set<Role> when,
  }) = PubspecDependency.path;

  /// Constrains the Dart [sdk] and [flutter] versions of the app.
  const factory PubspecContribution.environment({
    String? sdk,
    String? flutter,
    Set<Role> when,
  }) = PubspecEnvironment;

  /// Adds [assets], [fonts] and flags to the `flutter:` section.
  const factory PubspecContribution.flutter({
    List<String> assets,
    List<PubspecFont> fonts,
    bool generate,
    bool usesMaterialDesign,
    Set<Role> when,
  }) = PubspecFlutter;
}

/// Where a [PubspecDependency] comes from.
enum PubspecSource {
  /// pub.dev, with a version constraint.
  hosted,

  /// An SDK, such as `flutter`.
  sdk,

  /// A git repository.
  git,

  /// A local directory.
  path,
}

/// A dependency or dev dependency of the app.
final class PubspecDependency extends PubspecContribution {
  /// See [PubspecContribution.hosted].
  const PubspecDependency.hosted(
    this.package,
    String this.constraint, {
    this.dev = false,
    super.when,
  })  : source = PubspecSource.hosted,
        sdk = null,
        gitUrl = null,
        gitRef = null,
        gitPath = null,
        localPath = null;

  /// See [PubspecContribution.sdk].
  const PubspecDependency.sdk(
    this.package, {
    String this.sdk = 'flutter',
    this.dev = false,
    super.when,
  })  : source = PubspecSource.sdk,
        constraint = null,
        gitUrl = null,
        gitRef = null,
        gitPath = null,
        localPath = null;

  /// See [PubspecContribution.git].
  const PubspecDependency.git(
    this.package, {
    required String url,
    String? ref,
    String? path,
    this.dev = false,
    super.when,
  })  : source = PubspecSource.git,
        gitUrl = url,
        gitRef = ref,
        gitPath = path,
        constraint = null,
        sdk = null,
        localPath = null;

  /// See [PubspecContribution.path].
  const PubspecDependency.path(
    this.package,
    String path, {
    this.dev = false,
    super.when,
  })  : source = PubspecSource.path,
        localPath = path,
        constraint = null,
        sdk = null,
        gitUrl = null,
        gitRef = null,
        gitPath = null;

  /// The name of the package.
  final String package;

  /// Where the package comes from.
  final PubspecSource source;

  /// Whether this is a dev dependency.
  final bool dev;

  /// The version constraint of a [PubspecSource.hosted] package.
  final String? constraint;

  /// The SDK of a [PubspecSource.sdk] package.
  final String? sdk;

  /// The repository URL of a [PubspecSource.git] package.
  final String? gitUrl;

  /// The git ref of a [PubspecSource.git] package, if set.
  final String? gitRef;

  /// The directory in the repository of a [PubspecSource.git] package, if
  /// set.
  final String? gitPath;

  /// The directory of a [PubspecSource.path] package.
  final String? localPath;
}

/// SDK constraints of the app, the `environment:` section.
final class PubspecEnvironment extends PubspecContribution {
  /// See [PubspecContribution.environment].
  const PubspecEnvironment({this.sdk, this.flutter, super.when});

  /// The Dart SDK constraint, such as `^3.8.1`.
  final String? sdk;

  /// The Flutter SDK constraint, such as `>=3.32.0`.
  final String? flutter;
}

/// Settings of the `flutter:` section of the app.
final class PubspecFlutter extends PubspecContribution {
  /// See [PubspecContribution.flutter].
  const PubspecFlutter({
    this.assets = const [],
    this.fonts = const [],
    this.generate = false,
    this.usesMaterialDesign = false,
    super.when,
  });

  /// Asset files or directories, such as `assets/images/`.
  final List<String> assets;

  /// Font families.
  final List<PubspecFont> fonts;

  /// Whether the app generates code from its `l10n.yaml`.
  final bool generate;

  /// Whether the app uses the Material icons font.
  final bool usesMaterialDesign;
}

/// A font family of a [PubspecFlutter].
@immutable
final class PubspecFont {
  /// Creates the font family [family] from [assets].
  const PubspecFont(this.family, this.assets);

  /// The name of the family, as used in `TextStyle.fontFamily`.
  final String family;

  /// The font files of the family.
  final List<PubspecFontAsset> assets;
}

/// A font file of a [PubspecFont].
@immutable
final class PubspecFontAsset {
  /// Creates a font file at [asset], optionally for a [weight] and [style].
  const PubspecFontAsset(this.asset, {this.weight, this.style});

  /// The path of the file in the app, such as `fonts/Inter-Bold.ttf`.
  final String asset;

  /// The weight of the font, such as 700.
  final int? weight;

  /// The style of the font, `italic` if set.
  final String? style;
}
