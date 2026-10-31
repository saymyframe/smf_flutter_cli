import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
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

  group('flavorIdIn', () {
    const script = '''
const Map<String, _Flavor> _flavors = {
  'dev': (
    android: 'com.example.my_app.dev',
    ios: 'com.example.my-app.dev',
    configurations: ['Debug-dev', 'Profile-dev', 'Release-dev'],
  ),
  'prod': (
    android: null,
    ios: 'com.example.my-app',
    configurations: ['Debug-prod', 'Profile-prod', 'Release-prod'],
  ),
};
''';

    test('reads the id of a flavor on a platform from the script of the app',
        () {
      expect(
        flavorIdIn(script, 'dev', 'android'),
        'com.example.my_app.dev',
      );
      expect(flavorIdIn(script, 'dev', 'ios'), 'com.example.my-app.dev');
      expect(flavorIdIn(script, 'prod', 'ios'), 'com.example.my-app');
    });

    test('finds none for a platform that the app lacks, or another flavor', () {
      expect(flavorIdIn(script, 'prod', 'android'), isNull);
      expect(flavorIdIn(script, 'staging', 'ios'), isNull);
    });
  });

  group('registeredAppsProblem', () {
    String? problem(List<String> appIds) => registeredAppsProblem(
          appIds: appIds,
          appId: '1:1:ios:b',
          project: 'p',
          platform: 'ios',
          id: 'com.example.my-app.dev',
        );

    test('takes the one app that the options have', () {
      expect(problem(['1:1:ios:b']), isNull);
    });

    test(
        'names the two apps that a run of flutterfire leaves when it does not '
        'see the app that the run before it registered', () {
      expect(
        problem(['1:1:ios:a', '1:1:ios:b']),
        allOf(
          contains('should have one ios app with the id '
              'com.example.my-app.dev once flutterfire ran, but has 2: '
              '1:1:ios:a, 1:1:ios:b'),
          contains('the options have 1:1:ios:b'),
          contains('the script has to wait between its runs'),
        ),
      );
    });

    test('names another app, or none, as a mismatch with the options', () {
      expect(
        problem(['1:1:ios:a']),
        'flutterfire configured the app with the Firebase app 1:1:ios:b, but '
        'the project p lists 1:1:ios:a with the id com.example.my-app.dev.',
      );
      expect(problem([]), contains('lists no app with the id'));
    });
  });

  group('firebaseJsonProblems', () {
    /// What flutterfire writes for the flavor dev of the project `p`, with the
    /// Android app under [androidKey], which depends on the path of the app
    /// and the system, and each build configuration of iOS with its app.
    String firebaseJson({
      String androidKey = 'src/dev',
      String project = 'p',
      String debugApp = '1:2:ios:i',
      String profileApp = '1:2:ios:i',
      String releaseApp = '1:2:ios:i',
    }) {
      Map<String, Object> ios(String appId) => {
            'projectId': project,
            'appId': appId,
            'uploadDebugSymbols': true,
            'fileOutput': 'ios/flavors/dev/GoogleService-Info.plist',
          };
      return jsonEncode({
        'flutter': {
          'platforms': {
            'android': {
              'buildConfigurations': {
                androidKey: {
                  'projectId': project,
                  'appId': '1:1:android:a',
                  'fileOutput': 'android/app/src/dev/google-services.json',
                },
              },
            },
            'ios': {
              'buildConfigurations': {
                'Debug-dev': ios(debugApp),
                'Profile-dev': ios(profileApp),
                'Release-dev': ios(releaseApp),
              },
            },
            'dart': {
              'lib/firebase_options_dev.dart': {
                'projectId': project,
                'configurations': {
                  'android': '1:1:android:a',
                  'ios': '1:2:ios:i',
                },
              },
            },
          },
        },
      });
    }

    List<String> problems(
      String json, {
      String platform = 'android',
      AppFlavor flavor = AppEntryRole.defaultFlavor,
    }) =>
        firebaseJsonProblems(
          firebaseJson: json,
          flavor: flavor,
          platform: platform,
          appId: platform == 'android' ? '1:1:android:a' : '1:2:ios:i',
          project: 'p',
        );

    test('takes each form of the key of an Android app', () {
      for (final key in [
        'src/dev',
        'android/app/src/dev',
        r'src\dev',
      ]) {
        expect(problems(firebaseJson(androidKey: key)), isEmpty, reason: key);
      }
    });

    test('takes the three build configurations of a flavor with one app', () {
      expect(problems(firebaseJson(), platform: 'ios'), isEmpty);
    });

    test(
        'reports a build configuration that a later run of flutterfire gave '
        'another Firebase app', () {
      expect(
        problems(firebaseJson(releaseApp: '1:2:ios:second'), platform: 'ios'),
        [
          contains('names 1:2:ios:second as the Firebase app of the build '
              'configuration Release-dev, and not 1:2:ios:i'),
        ],
      );
    });

    test('reports a build configuration that no run of flutterfire wrote', () {
      final json = jsonDecode(firebaseJson()) as Map<String, dynamic>;
      // ignore: avoid_dynamic_calls, the form of the file above
      (json['flutter']['platforms']['ios']['buildConfigurations'] as Map)
          .remove('Profile-dev');
      const problem = 'firebase.json has nothing for the build configuration '
          'Profile-dev: no run wrote it.';
      expect(problems(jsonEncode(json), platform: 'ios'), [problem]);
    });

    test('reports a flavor that the file does not have', () {
      final found = problems(
        firebaseJson(),
        flavor: AppEntryRole.releaseFlavor,
      );
      expect(
        found,
        containsAll([
          contains('lib/firebase_options_prod.dart'),
          contains('one Android app with the file '
              'android/app/src/prod/google-services.json, but has 0'),
        ]),
      );
    });

    test('reports options of another project', () {
      expect(
        problems(firebaseJson(project: 'other')),
        contains(
          contains('other as the project of lib/firebase_options_dev.dart'),
        ),
      );
    });
  });

  group('googleServicesProblem', () {
    String services(Map<String, String> packagesOfApps) => jsonEncode({
          'client': [
            for (final MapEntry(key: appId, value: name)
                in packagesOfApps.entries)
              {
                'client_info': {
                  'mobilesdk_app_id': appId,
                  'android_client_info': {'package_name': name},
                },
              },
          ],
        });

    test('finds the client of the app among those of the project', () {
      expect(
        googleServicesProblem(
          services({'1:1:android:x': 'com.other', '1:1:android:a': 'com.app'}),
          '1:1:android:a',
          'com.app',
        ),
        isNull,
      );
    });

    test('reports a client of another package, and none', () {
      expect(
        googleServicesProblem(
          services({'1:1:android:a': 'com.app'}),
          '1:1:android:a',
          'com.app.dev',
        ),
        contains('the package name com.app, and not com.app.dev'),
      );
      expect(
        googleServicesProblem(
          services({'1:1:android:x': 'com.other'}),
          '1:1:android:a',
          'com.app',
        ),
        contains('no client of 1:1:android:a'),
      );
    });
  });

  group('servicePlistProblems', () {
    const plist = '''
<dict>
	<key>BUNDLE_ID</key>
	<string>com.app.dev</string>
	<key>PROJECT_ID</key>
	<string>p</string>
	<key>GOOGLE_APP_ID</key>
	<string>1:2:ios:i</string>
</dict>
''';

    test('takes the file of the app', () {
      expect(
        servicePlistProblems(plist, '1:2:ios:i', 'com.app.dev', 'p'),
        isEmpty,
      );
    });

    test('reports the file of another app, by the value of its key', () {
      expect(
        servicePlistProblems(plist, '1:2:ios:other', 'com.app', 'q'),
        [
          contains('1:2:ios:other as its GOOGLE_APP_ID'),
          contains('com.app as its BUNDLE_ID'),
          contains('q as its PROJECT_ID'),
        ],
      );
    });
  });
}
