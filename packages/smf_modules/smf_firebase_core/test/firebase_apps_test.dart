import 'dart:convert';

import 'package:test/test.dart';

import 'support/firebase_apps.dart';

void main() {
  group('firebaseAppIdsOf', () {
    /// What `firebase apps:list --json` prints for [apps], after a line of
    /// its own.
    String listed(List<Map<String, String>> apps) =>
        'i  Preparing the list of your Firebase ANDROID apps\n'
        '${jsonEncode({'status': 'success', 'result': apps})}\n';

    test(
        'finds the Firebase apps whose Android package name or iOS bundle id '
        'is the id', () {
      final output = listed([
        {
          'appId': '1:1:android:a',
          'packageName': 'com.saymyframe.ci.start_app',
          'platform': 'ANDROID',
        },
        {
          'appId': '1:1:android:b',
          'packageName': 'com.saymyframe.ci.start_app_riverpod',
          'platform': 'ANDROID',
        },
        {
          'appId': '1:1:ios:c',
          'bundleId': 'com.saymyframe.ci.start-app',
          'platform': 'IOS',
        },
        {
          'appId': '1:1:android:d',
          'packageName': 'com.saymyframe.ci.start_app',
          'platform': 'ANDROID',
        },
      ]);

      expect(firebaseAppIdsOf(output, 'com.saymyframe.ci.start_app'), [
        '1:1:android:a',
        '1:1:android:d',
      ]);
      expect(firebaseAppIdsOf(output, 'com.saymyframe.ci.start-app'), [
        '1:1:ios:c',
      ]);
      expect(firebaseAppIdsOf(output, 'com.saymyframe.ci.other'), isEmpty);
      expect(firebaseAppIdsOf(listed([]), 'com.saymyframe.ci.other'), isEmpty);
    });
  });

  group('configurationProblem', () {
    String? problem(List<String> appIds, {required bool register}) =>
        configurationProblem(
          appIds: appIds,
          project: 'saymyframe-app-cli',
          platform: 'android',
          id: 'com.saymyframe.ci.start_app',
          register: register,
        );

    test('lets flutterfire configure an app that the project has once', () {
      expect(problem(['1:1:android:a'], register: false), isNull);
      expect(problem(['1:1:android:a'], register: true), isNull);
    });

    test(
        'lets only a run that may register the apps of CI configure an app '
        'that the project does not have yet', () {
      expect(problem([], register: true), isNull);
      expect(
        problem([], register: false),
        'The Firebase project saymyframe-app-cli has no android app with '
        'the id com.saymyframe.ci.start_app, and only the runs of the '
        'workflow Build register the apps of CI in it, with '
        'SMF_FIREBASE_REGISTER=1, so that runs at the same time, such as '
        'the jobs of the nightly run, do not register one each. Run Build '
        'first, such as by hand on this branch.',
      );
    });

    test('lets no run configure an app that the project has more than once',
        () {
      const message = 'The Firebase project saymyframe-app-cli should have '
          'one android app with the id com.saymyframe.ci.start_app, but has '
          '2: 1:1:android:a, 1:1:android:b. flutterfire takes the first, so '
          'the options may change from run to run; delete the others in the '
          'Firebase console.';
      for (final register in [true, false]) {
        expect(
          problem(['1:1:android:a', '1:1:android:b'], register: register),
          message,
        );
      }
    });
  });
}
