import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';

/// The versions of Flutter and of Dart that every app of the matrix of
/// [modules] allows, as `matrixOf` finds its apps: the intersection of the
/// SDK constraints of their `pubspec.yaml`s, which the pipeline merges from
/// the `PubspecContribution.environment`s of the modules of each app, and
/// which `smf create` checks the Flutter SDK against before it generates
/// anything. A case of the contract harness with errors has no app in the
/// matrix, and an app whose pubspec has no constraint allows every version.
Future<({VersionConstraint flutter, VersionConstraint dart})>
    matrixSdkConstraints(List<SmfModule> modules) async {
  final harness = ContractHarness(ModuleRegistry(modules), render: false);
  final results = [
    ...await harness.checkAll(),
    for (final contractCase in harness.casesOfAll())
      await harness.check(contractCase),
  ];
  final pubspecs = [
    for (final result in results)
      if (result.validation case ValidationResult(:final pubspec)
          when result.errors.isEmpty)
        pubspec,
  ];
  return (
    flutter: VersionConstraint.intersection(
      pubspecs.map((pubspec) => pubspec.flutter).nonNulls,
    ),
    dart: VersionConstraint.intersection(
      pubspecs.map((pubspec) => pubspec.sdk).nonNulls,
    ),
  );
}

/// A system that the jobs of CI with Flutter run on, with the architecture
/// of its runners.
enum FlutterSystem {
  /// Linux on x64.
  linux('x64'),

  /// macOS on Apple silicon.
  macos('arm64'),

  /// Windows on x64.
  windows('x64');

  const FlutterSystem(this.arch);

  /// The architecture of the archives of Flutter that CI installs, as the
  /// list of releases names it in `dart_sdk_arch`.
  final String arch;

  /// The list of the releases of Flutter for the system, which Flutter
  /// publishes; see [stableReleasesOf].
  Uri get releases => Uri.https(
        'storage.googleapis.com',
        '/flutter_infra_release/releases/releases_$name.json',
      );
}

/// A stable release of Flutter for a [FlutterSystem].
final class FlutterRelease {
  /// Creates the release of the Flutter [version].
  const FlutterRelease(
    this.version, {
    required this.dart,
    required this.sha256,
  });

  /// The version of Flutter, such as `3.44.2`.
  final Version version;

  /// The version of the Dart that comes with it, such as `3.12.2`.
  final Version dart;

  /// The SHA-256 of its archive.
  final String sha256;
}

/// The stable releases of Flutter for [system] in [json], its list of
/// releases ([FlutterSystem.releases]), by version: those for the
/// architecture of [system] whose version is plain, such as `3.44.2`, and
/// not `v1.12.13+hotfix.9`. The Dart of a release is the version that
/// starts its `dart_sdk_version`, such as `3.10.0` of
/// `3.10.0 (build 3.10.0-290.4.beta)`.
///
/// The list has the newest release first. A version that was released
/// twice keeps its first entry, of the newest archive, which replaced the
/// other.
///
/// Throws a [FormatException] if [json] is not a list of releases.
Map<Version, FlutterRelease> stableReleasesOf(
  Object? json,
  FlutterSystem system,
) {
  if (json case {'releases': final List<Object?> releases}) {
    final byVersion = <Version, FlutterRelease>{};
    for (final release in releases) {
      if (release
          case {
            'channel': 'stable',
            'version': final String flutterText,
            'dart_sdk_version': final String dartText,
            'dart_sdk_arch': final String arch,
            'sha256': final String sha256,
          } when arch == system.arch) {
        if ((_version(flutterText), _version(dartText.split(' ').first))
            case (final Version version, final Version dart)
            when version.preRelease.isEmpty && version.build.isEmpty) {
          byVersion.putIfAbsent(
            version,
            () => FlutterRelease(version, dart: dart, sha256: sha256),
          );
        }
      }
    }
    return byVersion;
  }
  throw FormatException(
    'The list of releases of Flutter for ${system.name} has no releases.',
  );
}

/// [text] as a version, or `null` if it is not one.
Version? _version(String text) {
  try {
    return Version.parse(text);
  } on FormatException {
    return null;
  }
}

/// A version of Flutter that the nightly run of CI checks the apps with.
final class FlutterVersion {
  /// Creates the version from its [release] for Linux.
  const FlutterVersion(
    this.release, {
    required this.macos,
    required this.windows,
  });

  /// The release for Linux, which every version runs on.
  final FlutterRelease release;

  /// The release for macOS, if the jobs on macOS and Windows run with the
  /// version too.
  final FlutterRelease? macos;

  /// The release for Windows, if the jobs on macOS and Windows run with the
  /// version too.
  final FlutterRelease? windows;

  /// The entry of the version in the matrix of the nightly workflow, with
  /// the inputs of the workflow of the jobs with Flutter, `apps.yml`: the
  /// versions of Flutter and Dart, the SHA-256 of the archive for each
  /// system, empty for macOS and Windows unless the jobs there run too,
  /// and whether they do.
  Map<String, Object> toJson() => {
        'flutter': '${release.version}',
        'dart': '${release.dart}',
        'linux_sha256': release.sha256,
        'macos_sha256': macos?.sha256 ?? '',
        'windows_sha256': windows?.sha256 ?? '',
        'macos_and_windows': macos != null,
      };

  @override
  String toString() => '${release.version}'
      '${macos != null ? ' (also on macOS and Windows)' : ''}';
}

/// The versions of Flutter that the nightly run of CI checks the apps
/// with, the oldest first: every stable release for Linux among
/// [releases] (see [stableReleasesOf]) whose Flutter [flutter] allows and
/// whose Dart [dart] allows, such as those of [matrixSdkConstraints].
///
/// The jobs on macOS and Windows run with the oldest, and with the latest
/// patch of each minor version, such as 3.44.0, 3.44.9 and 3.47.5 of
/// `>=3.44.0`, of which the last is the latest stable release.
///
/// Throws a [FlutterVersionsException] if no release is allowed, or if one
/// that the jobs on macOS and Windows run with has no release for either.
List<FlutterVersion> flutterVersionsOf(
  Map<FlutterSystem, Map<Version, FlutterRelease>> releases, {
  required VersionConstraint flutter,
  required VersionConstraint dart,
}) {
  final allowed = [
    for (final release
        in releases[FlutterSystem.linux]?.values ?? const <FlutterRelease>[])
      if (flutter.allows(release.version) && dart.allows(release.dart)) release,
  ]..sort((a, b) => a.version.compareTo(b.version));
  if (allowed.isEmpty) {
    throw FlutterVersionsException(
      'No stable release of Flutter for Linux has a Flutter $flutter with a '
      'Dart $dart.',
    );
  }
  FlutterRelease releaseFor(FlutterSystem system, Version version) =>
      releases[system]?[version] ??
      (throw FlutterVersionsException(
        'Flutter $version has no stable release for ${system.name} on '
        '${system.arch}.',
      ));

  return [
    for (final (index, release) in allowed.indexed)
      if (index == 0 ||
          index == allowed.length - 1 ||
          !_sameMinor(release.version, allowed[index + 1].version))
        FlutterVersion(
          release,
          macos: releaseFor(FlutterSystem.macos, release.version),
          windows: releaseFor(FlutterSystem.windows, release.version),
        )
      else
        FlutterVersion(release, macos: null, windows: null),
  ];
}

bool _sameMinor(Version a, Version b) =>
    a.major == b.major && a.minor == b.minor;

/// The matrix of the nightly workflow for [versions]: the
/// [FlutterVersion.toJson] of each.
Map<String, Object> flutterVersionsMatrix(List<FlutterVersion> versions) => {
      'include': [for (final version in versions) version.toJson()],
    };

/// A problem of the versions of Flutter that [flutterVersionsOf] finds.
final class FlutterVersionsException implements Exception {
  /// Creates the exception with [message].
  const FlutterVersionsException(this.message);

  /// What is wrong.
  final String message;

  @override
  String toString() => message;
}
