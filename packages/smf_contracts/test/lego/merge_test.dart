import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

void main() {
  group('compareLooseVersions', () {
    test('orders by numeric components', () {
      expect(compareLooseVersions('13.0', '15.0'), isNegative);
      expect(compareLooseVersions('15.0', '13.0'), isPositive);
      expect(compareLooseVersions('8.10', '8.9'), isPositive);
      expect(compareLooseVersions('8.7.3', '8.7.10'), isNegative);
    });

    test('treats missing components as zero', () {
      expect(compareLooseVersions('15', '15.0'), 0);
      expect(compareLooseVersions('15.0', '15.0.0'), 0);
      expect(compareLooseVersions('15.1', '15.0.9'), isPositive);
    });

    test('compares versions with the same suffix by their numbers', () {
      expect(compareLooseVersions('33.3.1-jre', '33.2.0-jre'), isPositive);
      expect(compareLooseVersions('1.0-jre', '1.0-jre'), 0);
    });

    test('cannot order versions that differ only after their numbers', () {
      expect(
        () => compareLooseVersions('33.3.1-jre', '33.3.1-android'),
        throwsFormatException,
      );
      expect(
        () => compareLooseVersions('1.0', '1.0-beta'),
        throwsFormatException,
      );
    });

    test('rejects values that do not start with a number', () {
      expect(
        () => compareLooseVersions('latest', '1.0'),
        throwsFormatException,
      );
      expect(() => compareLooseVersions('1.0', ''), throwsFormatException);
    });
  });

  group('ConflictPolicy', () {
    test('keeps equal values and rejects different ones', () {
      const policy = ConflictPolicy<String>();

      expect(policy.name, 'conflict');
      expect(policy.problemWith('k', 'anything'), isNull);
      expect(policy.merge('k', 'a', 'a'), 'a');
      expect(
        () => policy.merge('k', 'a', 'b'),
        throwsA(
          isA<MergeConflict>()
              .having((c) => c.key, 'key', 'k')
              .having((c) => c.existing, 'existing', 'a')
              .having((c) => c.incoming, 'incoming', 'b'),
        ),
      );
    });
  });

  group('MaxPolicy', () {
    test('accepts only values its comparator can order', () {
      const policy = MaxPolicy();

      expect(policy.problemWith('ios', '15.0'), isNull);
      expect(
        policy.problemWith('ios', 'latest'),
        startsWith('The value "latest" of "ios" cannot be compared'),
      );
    });

    test('keeps the higher version and the earlier of equal ones', () {
      const policy = MaxPolicy();

      expect(policy.name, 'max');
      expect(policy.merge('ios', '13.0', '15.0'), '15.0');
      expect(policy.merge('ios', '15.0', '13.0'), '15.0');
      expect(policy.merge('ios', '15', '15.0'), '15');
    });

    test('turns versions it cannot order into a conflict', () {
      expect(
        () => const MaxPolicy().merge('guava', '33.3.1-jre', '33.3.1-android'),
        throwsA(isA<MergeConflict>()),
      );
    });

    test('uses a custom comparator', () {
      final policy = MaxPolicy((a, b) => a.length.compareTo(b.length));
      expect(policy.merge('k', 'aa', 'b'), 'aa');
    });
  });

  group('UnionPolicy', () {
    test('unites lists in order of first appearance', () {
      const policy = UnionPolicy<String>();

      expect(policy.name, 'union');
      expect(policy.merge('k', ['a', 'a'], ['b', 'a', 'b']), ['a', 'b']);
      expect(
        policy.merge('modes', [
          'fetch',
          'remote-notification',
        ], [
          'remote-notification',
          'audio',
        ]),
        ['fetch', 'remote-notification', 'audio'],
      );
    });
  });

  test('MergeConflict describes both values and the reason', () {
    expect(
      '${const MergeConflict('theme', 'a', 'b', 'one value only')}',
      'MergeConflict: "theme" has conflicting values "a" and "b": '
          'one value only',
    );
  });

  test('MergeConflict names the contributors when they are known', () {
    const conflict = MergeConflict('theme', 'a', 'b', 'one value only');
    const home = ModuleOrigin(ModuleId('home'));
    final attributed = conflict.withOrigins(existing: home, incoming: null);

    expect(conflict.existingOrigin, isNull);
    expect(attributed.existingOrigin, home);
    expect(attributed.incomingOrigin, isNull);
    expect(attributed.key, 'theme');
    expect(attributed.existing, 'a');
    expect(attributed.incoming, 'b');
    expect(attributed.reason, 'one value only');
    expect(
      '$attributed',
      'MergeConflict: "theme" has conflicting values "a" and "b" '
          '(from home and unknown): one value only',
    );
  });
}
