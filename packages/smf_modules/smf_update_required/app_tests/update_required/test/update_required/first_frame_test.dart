// A test that continuous integration runs in the apps with the
// update_required module: when the lowest version that may run is above the
// version of the app before the status of the module starts, as when the
// device kept it from the last fetch of remote config, the version may not
// run as soon as updateStatus.start() returns, which bootstrap() awaits. So
// the screen "Update required" is the first screen that the app shows, before
// its first frame, and not a screen that comes once the app runs.
//
// The test gives remote config and the reviews services of its own, which
// script what their providers answer, and shows no frame before it looks.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';
import 'package:{{app_name}}/core/review/app_review.dart';
import 'package:{{app_name}}/features/update_required/update_status.dart';

import 'of_app.dart';
import 'update_required.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the version may not run as soon as updateStatus.start() returns, when '
    'remote config has a lowest version above it already, before a frame',
    (tester) async {
      final service = ScriptedRemoteConfig({minimumParameter: '1.0.1'});
      final review = ScriptedReview();
      var supported = true;
      await inRealTime(tester, 'the start of the status', () async {
        await appRemoteConfig.start(service);
        await appReview.start(review);
        expect(
          appRemoteConfig.value.updateRequiredMinimumVersion,
          '1.0.1',
          reason: 'Remote config has the lowest version that the device '
              'kept.',
        );
        await updateStatus.start();
        supported = updateStatus.supported.value;
      });

      expect(
        supported,
        isFalse,
        reason: 'As soon as updateStatus.start() returns, the version 1.0.0 '
            'may not run below 1.0.1, so the first frame of the app shows '
            'the screen "Update required".',
      );
      expect(
        updateStatus.storeVisit.value,
        StoreVisit.none,
        reason: 'The screen is hard on the first frame.',
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
