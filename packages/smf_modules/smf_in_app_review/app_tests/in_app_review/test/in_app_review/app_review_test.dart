// A test that continuous integration runs in the apps with the in_app_review
// module: appReview of the review role over the service of the module and
// the platform side of in_app_review. The app starts with main() of
// lib/main.dart, as on a device, on a launch on which a review is due, and
// asks the platform for nothing on its own. A call of
// appReview.requestIfDue() asks the platform for the dialog once, and the
// app saves the request. A request that the platform refuses, as Android
// without the review service of Google Play does, saves nothing, reaches no
// handler of the errors of the app, and the next call asks again.
//
// The platform side is that of in_app_review_mocks.dart, a device with the
// store of its platform, which the test takes anew before the app starts.
// The device keeps the state of a review that is due under the keys of the
// role, which the matrix fills in, through the preferences of the app. The
// next launch is initPreferences() of the preferences role again, whose
// restorer of the role reads what the test saved, and initReview() of the
// role again. A start-up runs once in a test file, so the test starts the
// app once. Each expectation gives its reason.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/review/app_review.dart';
import 'package:{{app_name}}/main.dart' as app;

import '../in_app_review_mocks.dart';

/// The key under which the app counts its launches.
const String _launchesKey = '{{launches_key}}';

/// The key under which the app keeps the time of its first launch.
const String _firstLaunchKey = '{{first_launch_key}}';

/// The key under which the app keeps the time of its last request.
const String _askedAtKey = '{{asked_at_key}}';

/// The key under which the app keeps the version of its last request.
const String _askedVersionKey = '{{asked_version_key}}';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of a module, does not wait
/// for the fake time of the test. An error of [action] fails the test.
Future<void> _inRealTime(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  Object? error;
  StackTrace? stackTrace;
  await tester.runAsync(() async {
    try {
      await action();
    } on Object catch (thrown, stack) {
      error = thrown;
      stackTrace = stack;
    }
  });
  if (error != null) fail('$what threw $error\n$stackTrace');
}

/// Saves under the keys of the role the state of an app on which a review
/// is due at [now]: nine launches, the first a month before [now], and, if
/// [askedVersion] is given, a request a month before [now] in that version.
Future<void> _saveDueState(DateTime now, {String? askedVersion}) async {
  final preferences = createAppPreferences();
  final monthAgo = now.subtract(const Duration(days: 30));
  await preferences.setInt(_launchesKey, 9);
  await preferences.setInt(_firstLaunchKey, monthAgo.millisecondsSinceEpoch);
  if (askedVersion == null) {
    await preferences.remove(_askedAtKey);
    await preferences.remove(_askedVersionKey);
  } else {
    await preferences.setInt(_askedAtKey, monthAgo.millisecondsSinceEpoch);
    await preferences.setString(_askedVersionKey, askedVersion);
  }
}

/// What the preferences saved of the last request: its time, in
/// milliseconds since the epoch, and its version.
(int?, String?) get _savedRequest {
  final preferences = createAppPreferences();
  return (
    preferences.getInt(_askedAtKey),
    preferences.getString(_askedVersionKey),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the app asks the platform for the dialog only where its code calls '
    'appReview.requestIfDue(), once, and saves the request; a request that '
    'the platform refuses saves nothing, reaches no handler of the errors '
    'of the app, and the next call asks again',
    (tester) async {
      final device = mockInAppReview();
      final now = DateTime.now().toUtc();
      await _inRealTime(tester, 'what the device kept', () async {
        await initPreferences();
        await _saveDueState(now);
      });
      final onError = FlutterError.onError;
      final onPlatformError = PlatformDispatcher.instance.onError;
      final errorWidgetBuilder = ErrorWidget.builder;
      try {
        await _inRealTime(tester, 'main()', app.main);
      } finally {
        FlutterError.onError = onError;
        PlatformDispatcher.instance.onError = onPlatformError;
        ErrorWidget.builder = errorWidgetBuilder;
      }
      await tester.pumpAndSettle();
      int requests() =>
          device.methods.where((method) => method == 'requestReview').length;

      expect(
        (requests(), _savedRequest),
        (0, (null, null)),
        reason: 'A launch on which a review is due asks the platform for no '
            'dialog on its own: the app asks only where its code calls '
            'appReview.requestIfDue().',
      );

      await _inRealTime(tester, 'requestIfDue()', appReview.requestIfDue);
      final (askedAt, version) = _savedRequest;

      expect(
        (requests(), version),
        (1, '1.0.0'),
        reason: 'appReview.requestIfDue() on a launch on which a review is '
            'due asks the platform for the dialog once, and the app saves the '
            'request in the version of the app.',
      );
      expect(
        askedAt,
        greaterThanOrEqualTo(now.millisecondsSinceEpoch - 1000),
        reason: 'The app saves the time of the request.',
      );
      expect(
        device.methods,
        isNot(contains('openStoreListing')),
        reason: 'The reviews of the app never call openStoreListing() of '
            'in_app_review.',
      );

      // The next launch, on which a review is due again: the app asked a
      // month ago, in an earlier version. The platform refuses the request.
      final reported = <Object>[];
      await _inRealTime(tester, 'the next launch', () async {
        await _saveDueState(now, askedVersion: '0.9.0');
        await initPreferences();
        await initReview();
      });
      final before = _savedRequest;
      device.failNext(
        'requestReview',
        PlatformException(
          code: 'error',
          message: 'In-App Review API unavailable',
        ),
      );
      FlutterError.onError = (details) => reported.add(details.exception);
      PlatformDispatcher.instance.onError = (error, stack) {
        reported.add(error);
        return true;
      };
      try {
        await _inRealTime(tester, 'a refused request', appReview.requestIfDue);
      } finally {
        FlutterError.onError = onError;
        PlatformDispatcher.instance.onError = onPlatformError;
      }

      expect(
        (requests(), _savedRequest),
        (2, before),
        reason: 'A request that the platform refuses asks it once, and saves '
            'nothing: the time and the version of the last request stay.',
      );
      expect(
        reported,
        isEmpty,
        reason: 'A request that the platform refuses reaches no handler of '
            'the errors of the app: it counts as no dialog.',
      );

      await _inRealTime(tester, 'the next call', appReview.requestIfDue);

      expect(
        (requests(), _savedRequest.$2),
        (3, '1.0.0'),
        reason: 'After a request that the platform refused, the next call '
            'asks again, and the app saves that request.',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'Nothing that the reviews did reached flutter_test.',
      );
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
