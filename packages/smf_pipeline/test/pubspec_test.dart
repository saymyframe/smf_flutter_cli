import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

Collected _by(
  String module,
  PubspecContribution contribution, {
  bool applies = true,
}) =>
    Collected(
      contribution,
      ModuleOrigin(ModuleId(module)),
      applies: applies,
    );

void main() {
  test('intersects constraints and keeps the first order', () {
    final result = mergePubspec([
      _by('a', const PubspecContribution.hosted('go_router', '^16.0.0')),
      _by('a', const PubspecContribution.sdk('flutter')),
      _by('b', const PubspecContribution.hosted('go_router', '>=16.2.0')),
      _by('c', const PubspecContribution.hosted('go_router', 'any')),
    ]);

    expect(result.issues, isEmpty);
    final dependencies = result.pubspec.dependencies;
    expect(dependencies.keys, ['go_router', 'flutter']);
    final goRouter = dependencies['go_router']!;
    expect(goRouter.constraint, VersionConstraint.parse('>=16.2.0 <17.0.0'));
    expect(goRouter.source, PubspecSource.hosted);
    expect(goRouter.origins.map((o) => '$o'), ['a', 'b', 'c']);
    expect(dependencies['flutter']!.sdk, 'flutter');
    expect(dependencies['flutter']!.constraint, isNull);
  });

  test('a dependency that is also a dev dependency is a dependency', () {
    final result = mergePubspec([
      _by('a', const PubspecContribution.hosted('lints', '^6.0.0', dev: true)),
      _by(
        'a',
        const PubspecContribution.hosted('mocktail', '^1.0.0', dev: true),
      ),
      _by('b', const PubspecContribution.hosted('lints', '^6.1.0')),
      _by('c', const PubspecContribution.sdk('flutter_test', dev: true)),
    ]);

    expect(result.pubspec.dependencies.keys, ['lints']);
    expect(
      result.pubspec.dependencies['lints']!.constraint,
      VersionConstraint.parse('^6.1.0'),
    );
    expect(result.pubspec.devDependencies.keys, ['mocktail', 'flutter_test']);
  });

  test('skips contributions that do not apply', () {
    final result = mergePubspec([
      _by(
        'a',
        const PubspecContribution.hosted('x', '^1.0.0'),
        applies: false,
      ),
      const Collected(
        CodegenRequest(),
        ModuleOrigin(ModuleId('a')),
        applies: true,
      ),
    ]);

    expect(result.pubspec.dependencies, isEmpty);
  });

  test('reports conflicts with both contributors', () {
    final result = mergePubspec([
      _by('a', const PubspecContribution.hosted('x', '^1.0.0')),
      _by('b', const PubspecContribution.hosted('x', '^2.0.0')),
      _by('c', const PubspecContribution.hosted('bad name', '^1.0.0')),
      _by('d', const PubspecContribution.hosted('y', 'not a version')),
      _by('e', const PubspecContribution.hosted('x', 'nope')),
      _by('f', const PubspecContribution.sdk('x')),
      _by('g', const PubspecContribution.sdk('z')),
      _by('h', const PubspecContribution.sdk('z', sdk: 'other')),
    ]);

    expect(
      result.issues.map((issue) => '${issue.origin}: ${issue.message}'),
      [
        equals(
            'b: The constraints "^1.0.0" (from a) and "^2.0.0" (from b) of x '
            'have no version in common.'),
        'c: "bad name" is not a package name.',
        'd: The constraint "not a version" of y is invalid.',
        'e: The constraint "nope" of x is invalid.',
        'f: x comes from pub.dev (from a) and from the flutter SDK (from f).',
        equals(
            'h: z comes from the flutter SDK (from g) and from the other SDK '
            '(from h).'),
      ],
    );
    expect(result.pubspec.dependencies.keys, ['x', 'z']);
  });

  test('intersects the SDK constraints', () {
    final result = mergePubspec([
      _by(
        'a',
        const PubspecContribution.environment(
          sdk: '^3.8.0',
          flutter: '>=3.32.0',
        ),
      ),
      _by('b', const PubspecContribution.environment(sdk: '>=3.9.0 <4.0.0')),
      _by('c', const PubspecContribution.environment(flutter: '<3.0.0')),
      _by('d', const PubspecContribution.environment(sdk: 'bad')),
    ]);

    expect(result.pubspec.sdk, VersionConstraint.parse('>=3.9.0 <4.0.0'));
    expect(result.pubspec.flutter, VersionConstraint.parse('>=3.32.0'));
    expect(result.issues.map((issue) => '${issue.origin}'), ['c', 'd']);
    expect(result.issues.first.message, contains('from a'));
  });

  test('merges the flutter section', () {
    final result = mergePubspec([
      _by(
        'a',
        const PubspecContribution.flutter(
          assets: ['assets/a/', 'assets/shared/'],
          fonts: [
            PubspecFont('Inter', [
              PubspecFontAsset('fonts/Inter.ttf'),
              PubspecFontAsset('fonts/Inter-Bold.ttf', weight: 700),
            ]),
          ],
          usesMaterialDesign: true,
        ),
      ),
      _by(
        'b',
        const PubspecContribution.flutter(
          assets: ['assets/shared/', 'assets/b/'],
          fonts: [
            PubspecFont('Inter', [
              PubspecFontAsset('fonts/Inter-Bold.ttf', weight: 700),
              PubspecFontAsset('fonts/Inter-Italic.ttf', style: 'italic'),
            ]),
            PubspecFont('Mono', [PubspecFontAsset('fonts/Mono.ttf')]),
          ],
          generate: true,
        ),
      ),
      _by(
        'c',
        const PubspecContribution.flutter(
          fonts: [
            PubspecFont('Inter', [
              PubspecFontAsset('fonts/Inter.ttf', weight: 400),
            ]),
          ],
        ),
      ),
    ]);

    final pubspec = result.pubspec;
    expect(pubspec.assets, ['assets/a/', 'assets/shared/', 'assets/b/']);
    expect(pubspec.generate, isTrue);
    expect(pubspec.usesMaterialDesign, isTrue);
    expect(pubspec.fonts.map((f) => f.family), ['Inter', 'Mono']);
    expect(
      pubspec.fonts.first.assets.map((a) => a.asset),
      ['fonts/Inter.ttf', 'fonts/Inter-Bold.ttf', 'fonts/Inter-Italic.ttf'],
    );
    expect(result.issues.single.origin, const ModuleOrigin(ModuleId('c')));
    expect(result.issues.single.message, contains('another weight or style'));
  });
}
