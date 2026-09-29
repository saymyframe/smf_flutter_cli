import 'dart:convert';

import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// A module without a role that constrains the SDKs of the apps it is in,
/// and that the pipeline rejects if [broken].
final class _Environment extends SmfModule {
  const _Environment(this.id, {this.flutter, this.sdk, this.broken = false});

  final String id;
  final String? flutter;
  final String? sdk;
  final bool broken;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: ModuleId(id),
        description: 'Environment',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        PubspecContribution.environment(flutter: flutter, sdk: sdk),
        if (broken) const PubspecContribution.hosted('Not a package', 'any'),
      ];
}

/// The SDK constraints that flutter_core contributes to every app.
({VersionConstraint flutter, VersionConstraint dart}) _flutterCore() {
  final environment = const FlutterCoreModule()
      .contribute(ContractHarness.defaultContext)
      .whereType<PubspecEnvironment>()
      .single;
  return (
    flutter: VersionConstraint.parse(environment.flutter!),
    dart: VersionConstraint.parse(environment.sdk!),
  );
}

/// An entry of a list of releases of Flutter.
Map<String, Object?> _entry(
  String version, {
  String dart = '3.12.2',
  String arch = 'x64',
  String channel = 'stable',
  String? sha256,
}) =>
    {
      'hash': 'hash of $version',
      'channel': channel,
      'version': version,
      'dart_sdk_version': dart,
      'dart_sdk_arch': arch,
      'release_date': '2026-09-18T20:20:24.224309Z',
      'archive': '$channel/linux/flutter_linux_$version-$channel.tar.xz',
      'sha256': sha256 ?? '$version $arch',
    };

/// The releases of [system] with the versions of Flutter and Dart of
/// [versions], each with the SHA-256 `<version> <system>`.
Map<Version, FlutterRelease> _releases(
  FlutterSystem system,
  List<(String, String)> versions,
) =>
    {
      for (final (flutter, dart) in versions)
        Version.parse(flutter): FlutterRelease(
          Version.parse(flutter),
          dart: Version.parse(dart),
          sha256: '$flutter ${system.name}',
        ),
    };

/// Releases for every system, of [versions] and, for macOS and Windows,
/// of those of them not in [linuxOnly].
Map<FlutterSystem, Map<Version, FlutterRelease>> _everySystem(
  List<(String, String)> versions, {
  Set<String> linuxOnly = const {},
}) =>
    {
      for (final system in FlutterSystem.values)
        system: _releases(system, [
          for (final version in versions)
            if (system == FlutterSystem.linux ||
                !linuxOnly.contains(version.$1))
              version,
        ]),
    };

const _versions = [
  ('3.44.0', '3.12.0'),
  ('3.44.1', '3.12.1'),
  ('3.44.2', '3.12.2'),
  ('3.47.0', '3.13.0'),
  ('3.47.1', '3.13.1'),
  ('3.41.9', '3.11.5'),
];

void main() {
  group('matrixSdkConstraints', () {
    test(
        'is what flutter_core and every other module of an app of the matrix '
        'allow, in the apps without the module too', () async {
      final core = _flutterCore();

      final constraints = await matrixSdkConstraints(const [
        FlutterCoreModule(),
        _Environment('narrow', flutter: '<4.0.0'),
        _Environment('narrow_dart', sdk: '<3.99.0'),
      ]);

      expect(
        constraints.flutter,
        core.flutter.intersect(VersionConstraint.parse('<4.0.0')),
      );
      expect(
        constraints.dart,
        core.dart.intersect(VersionConstraint.parse('<3.99.0')),
      );
    });

    test('leaves out the apps that the pipeline rejects', () async {
      final core = _flutterCore();

      final constraints = await matrixSdkConstraints(const [
        FlutterCoreModule(),
        _Environment('broken', flutter: '<4.0.0', broken: true),
      ]);

      expect(constraints.flutter, core.flutter);
      expect(constraints.dart, core.dart);
    });
  });

  group('stableReleasesOf', () {
    test(
        'reads the stable releases of the architecture of the system with a '
        'plain version, and the Dart that starts dart_sdk_version', () {
      final json = {
        'current_release': {'stable': 'hash of 3.47.1'},
        'releases': [
          _entry('3.48.0-0.1.pre', channel: 'beta'),
          _entry('3.47.1', dart: '3.13.1', arch: 'arm64'),
          _entry('3.47.1', dart: '3.13.1'),
          _entry('3.38.0', dart: '3.10.0 (build 3.10.0-290.4.beta)'),
          _entry('3.13.3', sha256: 'newest'),
          _entry('3.13.3', sha256: 'replaced'),
          _entry('v1.12.13+hotfix.9'),
          _entry('1.12.13+hotfix.9'),
          _entry('3.0.0-1.0.pre'),
          _entry('3.1.0', dart: 'unknown'),
          {'channel': 'stable', 'version': '1.0.0', 'sha256': 'no Dart'},
        ],
      };

      final releases = stableReleasesOf(json, FlutterSystem.linux);

      expect(
        {
          for (final MapEntry(key: version, value: release) in releases.entries)
            '$version': '${release.version} ${release.dart} ${release.sha256}',
        },
        {
          '3.47.1': '3.47.1 3.13.1 3.47.1 x64',
          '3.38.0': '3.38.0 3.10.0 3.38.0 x64',
          '3.13.3': '3.13.3 3.12.2 newest',
        },
      );
    });

    test('takes the archives of macOS for Apple silicon', () {
      final json = {
        'releases': [
          _entry('3.47.1'),
          _entry('3.47.1', arch: 'arm64'),
        ],
      };

      final releases = stableReleasesOf(json, FlutterSystem.macos);

      expect(releases.values.single.sha256, '3.47.1 arm64');
    });

    test('fails on what is not a list of releases', () {
      for (final json in [
        null,
        <Object?>[],
        <String, Object?>{},
        {'releases': 'none'},
      ]) {
        expect(
          () => stableReleasesOf(json, FlutterSystem.windows),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'The list of releases of Flutter for windows has no releases.',
            ),
          ),
          reason: '$json',
        );
      }
    });

    test('are published by Flutter for each system', () {
      expect(
        [for (final system in FlutterSystem.values) '${system.releases}'],
        [
          'https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json',
          'https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json',
          'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json',
        ],
      );
    });
  });

  group('flutterVersionsOf', () {
    test(
        'is every release for Linux that the constraints allow, the oldest '
        'first, and the oldest and the latest patch of each minor version '
        'run on macOS and Windows too', () {
      final versions = flutterVersionsOf(
        _everySystem(_versions),
        flutter: VersionConstraint.parse('>=3.44.0'),
        dart: VersionConstraint.parse('^3.12.0'),
      );

      expect(versions.map((version) => '$version'), [
        '3.44.0 (also on macOS and Windows)',
        '3.44.1',
        '3.44.2 (also on macOS and Windows)',
        '3.47.0',
        '3.47.1 (also on macOS and Windows)',
      ]);
      expect(versions.first.macos?.sha256, '3.44.0 macos');
      expect(versions.first.windows?.sha256, '3.44.0 windows');
    });

    test('the latest patch of a minor version is the latest one allowed', () {
      final versions = flutterVersionsOf(
        _everySystem(_versions),
        flutter: VersionConstraint.parse('>=3.44.1 <3.47.1'),
        dart: VersionConstraint.any,
      );

      expect(versions.map((version) => '$version'), [
        '3.44.1 (also on macOS and Windows)',
        '3.44.2 (also on macOS and Windows)',
        '3.47.0 (also on macOS and Windows)',
      ]);
    });

    test(
        'leaves out a release whose Dart the constraint of Dart does not allow',
        () {
      final versions = flutterVersionsOf(
        _everySystem(_versions),
        flutter: VersionConstraint.parse('>=3.44.0 <3.47.0'),
        dart: VersionConstraint.parse('>=3.12.1'),
      );

      expect(versions.map((version) => '${version.release.version}'), [
        '3.44.1',
        '3.44.2',
      ]);
    });

    test('needs no release for macOS and Windows of a version only for Linux',
        () {
      final versions = flutterVersionsOf(
        _everySystem(_versions, linuxOnly: {'3.44.1', '3.47.0'}),
        flutter: VersionConstraint.parse('>=3.44.0'),
        dart: VersionConstraint.any,
      );

      expect(versions, hasLength(5));
      expect(versions[1].macos, isNull);
      expect(versions[1].windows, isNull);
    });

    test('a single release runs on every system', () {
      final versions = flutterVersionsOf(
        _everySystem(_versions),
        flutter: VersionConstraint.parse('3.44.2'),
        dart: VersionConstraint.any,
      );

      expect(versions.map((version) => '$version'), [
        '3.44.2 (also on macOS and Windows)',
      ]);
    });

    test('fails when no release is allowed', () {
      for (final releases in [
        _everySystem(_versions),
        <FlutterSystem, Map<Version, FlutterRelease>>{},
      ]) {
        expect(
          () => flutterVersionsOf(
            releases,
            flutter: VersionConstraint.parse('>=3.48.0'),
            dart: VersionConstraint.parse('^3.12.0'),
          ),
          throwsA(
            isA<FlutterVersionsException>().having(
              (error) => '$error',
              'message',
              'No stable release of Flutter for Linux has a Flutter >=3.48.0 '
                  'with a Dart ^3.12.0.',
            ),
          ),
        );
      }
    });

    test(
        'fails when a version that runs on macOS and Windows has no release '
        'for either', () {
      final withoutMacos = _everySystem(_versions, linuxOnly: {'3.47.1'});
      final withoutWindows = _everySystem(_versions)
        ..remove(FlutterSystem.windows);

      expect(
        () => flutterVersionsOf(
          withoutMacos,
          flutter: VersionConstraint.any,
          dart: VersionConstraint.any,
        ),
        throwsA(
          isA<FlutterVersionsException>().having(
            (error) => error.message,
            'message',
            'Flutter 3.47.1 has no stable release for macos on arm64.',
          ),
        ),
      );
      expect(
        () => flutterVersionsOf(
          withoutWindows,
          flutter: VersionConstraint.any,
          dart: VersionConstraint.any,
        ),
        throwsA(
          isA<FlutterVersionsException>().having(
            (error) => error.message,
            'message',
            'Flutter 3.41.9 has no stable release for windows on x64.',
          ),
        ),
      );
    });
  });

  test(
      'the matrix of the nightly workflow has the inputs of apps.yml for each '
      'version, with the archives of macOS and Windows only for the versions '
      'that run there', () {
    final versions = flutterVersionsOf(
      _everySystem(_versions),
      flutter: VersionConstraint.parse('>=3.44.0 <3.47.0'),
      dart: VersionConstraint.any,
    );

    expect(jsonDecode(jsonEncode(flutterVersionsMatrix(versions))), {
      'include': [
        {
          'flutter': '3.44.0',
          'dart': '3.12.0',
          'linux_sha256': '3.44.0 linux',
          'macos_sha256': '3.44.0 macos',
          'windows_sha256': '3.44.0 windows',
          'macos_and_windows': true,
        },
        {
          'flutter': '3.44.1',
          'dart': '3.12.1',
          'linux_sha256': '3.44.1 linux',
          'macos_sha256': '',
          'windows_sha256': '',
          'macos_and_windows': false,
        },
        {
          'flutter': '3.44.2',
          'dart': '3.12.2',
          'linux_sha256': '3.44.2 linux',
          'macos_sha256': '3.44.2 macos',
          'windows_sha256': '3.44.2 windows',
          'macos_and_windows': true,
        },
      ],
    });
  });
}
