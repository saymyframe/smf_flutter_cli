// A test that continuous integration runs in the apps with the in_app_review
// module: what each call of the service of the module sends to the platform
// side of in_app_review and of url_launcher. It asks the store for its review
// dialog and lets a refusal of the platform through, as the review role
// asks. It opens exactly the page of the store that it gets with
// url_launcher, outside the app, and never through openStoreListing() of
// in_app_review, which on Android opens the page of the id of the build that
// runs, such as that of a flavor that has no page in Google Play. And it
// gives the version of the app without its build number.
//
// It uses the service of the module, and leaves what every provider of the
// review role does to the test of the role. The platform side is that of
// in_app_review_mocks.dart, a device with the store of its platform, which
// each test takes anew. Each expectation gives its reason.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/review/in_app_review_service.dart';

import '../in_app_review_mocks.dart';

/// The Google Play page of an app.
final Uri _play = Uri.parse(
  'https://play.google.com/store/apps/details?id=com.example.my_app',
);

/// The App Store page of an app on which the user writes a review.
final Uri _appStore = Uri.parse(
  'https://apps.apple.com/app/id1234567890?action=write-review',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockInAppReview device;

  setUp(() => device = mockInAppReview());

  test(
    'isAvailable() asks the platform whether the store can show its dialog, '
    'and is false when the platform fails to tell',
    () async {
      final service = createInAppReviewService();
      final answers = [await service.isAvailable()];
      device.available = false;
      answers.add(await service.isAvailable());
      device.failNext(
        'isAvailable',
        PlatformException(code: 'error', message: 'No review service.'),
      );
      answers.add(await service.isAvailable());

      expect(
        answers,
        [true, false, false],
        reason: 'isAvailable() gives what the platform answers, and false '
            'when the platform fails to tell.',
      );
      expect(
        device.methods,
        ['isAvailable', 'isAvailable', 'isAvailable'],
        reason: 'Each call asks the platform once.',
      );
    },
  );

  test(
    'requestReview() asks the platform for the dialog once, and throws what '
    'the platform throws when it refuses the request',
    () async {
      final service = createInAppReviewService();
      await service.requestReview();
      device.failNext(
        'requestReview',
        PlatformException(
          code: 'error',
          message: 'In-App Review API unavailable',
        ),
      );
      Object? refused;
      try {
        await service.requestReview();
      } on Object catch (error) {
        refused = error;
      }

      expect(
        device.methods,
        ['requestReview', 'requestReview'],
        reason: 'Each request asks the platform for the dialog once, and asks '
            'nothing else.',
      );
      expect(
        refused,
        isA<PlatformException>().having(
          (error) => error.message,
          'message',
          'In-App Review API unavailable',
        ),
        reason: 'A request that the platform refuses, as Android without the '
            'review service of Google Play does, throws what the platform '
            'throws: the review role then records no request, and the next '
            'call asks again.',
      );
    },
  );

  test(
    'openStorePage() gives url_launcher exactly the page, to open outside the '
    'app, on Android and on iOS, and never asks in_app_review for the page '
    'of the app in its store',
    () async {
      final service = createInAppReviewService();
      final opened = <bool>[];
      for (final (platform, page) in [
        (TargetPlatform.android, _play),
        (TargetPlatform.iOS, _appStore),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          opened.add(await service.openStorePage(page));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }

      expect(
        device.opened,
        ['$_play externalApplication', '$_appStore externalApplication'],
        reason: 'openStorePage() gives url_launcher exactly the page that the '
            'review role gives it, to open outside the app.',
      );
      expect(
        opened,
        [true, true],
        reason: 'openStorePage() returns whether an app of the device opened '
            'the page.',
      );
      expect(
        device.methods,
        isNot(contains('openStoreListing')),
        reason: 'openStorePage() never calls openStoreListing() of '
            'in_app_review, which on Android opens the page of the id of the '
            'build that runs, such as that of a flavor that has no page in '
            'Google Play.',
      );
    },
  );

  test(
    'openStorePage() returns false when no app opens the page, and when '
    'url_launcher fails, and never throws',
    () async {
      final service = createInAppReviewService();
      device.opens = false;
      final notOpened = await service.openStorePage(_play);
      device
        ..opens = true
        ..failNextPage(
          PlatformException(code: 'ACTIVITY_NOT_FOUND', message: 'No app.'),
        );
      final failed = await service.openStorePage(_play);

      expect(
        (notOpened, failed),
        (false, false),
        reason: 'openStorePage() returns false when no app of the device '
            'opens the page, and when url_launcher fails, and never throws.',
      );
      expect(
        device.methods,
        isNot(contains('openStoreListing')),
        reason: 'openStorePage() never calls openStoreListing() of '
            'in_app_review, also when the page does not open.',
      );
    },
  );

  test(
    'appVersion() is the version of the app, without its build number',
    () async {
      expect(
        await createInAppReviewService().appVersion(),
        '1.0.0',
        reason: 'The mocks give the app the version 1.0.0 and the build '
            'number 1, and the app asks for a review at most once a version, '
            'whatever its build.',
      );
    },
  );
}
