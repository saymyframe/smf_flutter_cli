@TestOn('vm')
library;

import 'dart:convert';

import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_remote_config/smf_firebase_remote_config.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_in_app_review/smf_in_app_review.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:smf_update_required/smf_update_required.dart';
import 'package:test/test.dart';

/// The file of the app with the comparison of versions, which needs only
/// Dart.
const _compareFile = 'lib/features/update_required/version_compare.dart';

/// Pairs of a version of the app and a lowest version, each with whether
/// the version is below the lowest one.
const _below = <(String, String, bool)>[
  // Number by number, and not as texts: 1.10.0 is above 1.9.x.
  ('1.9.2', '1.10.0', true),
  ('1.10.0', '1.9.2', false),
  ('1.10.0', '1.9.0', false),
  ('2.0.0', '10.0.0', true),
  ('1.0.0', '1.0.1', true),
  ('1.0.1', '1.0.0', false),
  ('1.0.0', '1.0.0', false),
  // A missing number is 0.
  ('1.2', '1.2.0', false),
  ('1.2.0', '1.2', false),
  ('1.2', '1.2.1', true),
  ('2', '1.9.9', false),
  ('1.0.0', '1.0.0.1', true),
  ('1.0.0.1', '1.0.0', false),
  // A build number does not count.
  ('1.0.0+7', '1.0.0', false),
  ('1.0.0', '1.0.0+7', false),
  ('1.0.0+12', '1.0.1+1', true),
  // Spaces around a version do not count.
  ('1.0.0', ' 1.0.1 ', true),
  // An empty lowest version, or one of spaces, is none.
  ('1.0.0', '', false),
  ('1.0.0', '   ', false),
  // A version or a lowest version that is no version is below nothing.
  ('1.0.0', '1.0.0-beta', false),
  ('1.0.0', '2.0.0-beta', false),
  ('1.0.0', 'abc', false),
  ('1.0.0', '1..2', false),
  ('1.0.0', '1.2.3.4.5', false),
  ('1.0.0', 'v2', false),
  ('1.0.0', '-1', false),
  ('1.0.0-dev', '2.0.0', false),
  ('', '2.0.0', false),
];

/// Versions with their numbers, or `null` for no version.
const _numbers = <(String, List<int>?)>[
  ('1.4.0', [1, 4, 0]),
  ('2', [2]),
  ('1.4.0.2', [1, 4, 0, 2]),
  ('1.4.0+12', [1, 4, 0]),
  (' 1.4 ', [1, 4]),
  ('010.2', [10, 2]),
  ('1.2.3.4.5', null),
  ('2.0.0-beta', null),
  ('1.0.0 beta', null),
  ('', null),
  ('.', null),
  ('1.', null),
  ('a.b', null),
  ('99999999999999999999', null),
];

void main() {
  late DartOnlyApp app;

  setUpAll(() async {
    final result = await ContractHarness(
      ModuleRegistry(const [
        FlutterCoreModule(),
        GoRouterModule(),
        SharedPreferencesModule(),
        DartDefineModule(),
        FirebaseCoreModule(),
        FirebaseRemoteConfigModule(),
        InAppReviewModule(),
        UpdateRequiredModule(),
      ]),
    ).check(
      const ContractCase(
        'update_required',
        requested: [UpdateRequiredModule.id],
      ),
    );
    app = DartOnlyApp.write(result.app!, const [_compareFile]);
  });

  tearDownAll(() => app.delete());

  test(
      'needs nothing but Dart, and compares a version with the lowest '
      'version number by number, with 0 for a missing number, a build number '
      'that does not count, and no lowest version for an empty one or one '
      'that is no version', () async {
    final output = await app.run('''
import 'dart:convert';

import 'package:contract_app/features/update_required/version_compare.dart';

void main() {
  print(jsonEncode({
    'below': [
      for (final pair in ${jsonEncode([
          for (final (version, minimum, _) in _below) [version, minimum],
        ])})
        versionBelow(pair[0], pair[1]),
    ],
    'numbers': [
      for (final version in ${jsonEncode([
          for (final (version, _) in _numbers) version,
        ])})
        versionNumbers(version),
    ],
  }));
}
''');
    final result = jsonDecode(output) as Map<String, Object?>;

    final below = result['below']! as List<Object?>;
    for (final (index, (version, minimum, expected)) in _below.indexed) {
      expect(
        below[index],
        expected,
        reason: '$version is ${expected ? '' : 'not '}below "$minimum".',
      );
    }
    final numbers = result['numbers']! as List<Object?>;
    for (final (index, (version, expected)) in _numbers.indexed) {
      expect(numbers[index], expected, reason: '"$version"');
    }
  });
}
