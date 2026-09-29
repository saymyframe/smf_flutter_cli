// A test that continuous integration runs in the apps with Firebase: the
// start-up of the app initializes Firebase with the options of the app.
// The matrix sets up the mocks of the platform side of every module of the
// app before the tests, those of Firebase Core among them
// (firebase_core_mocks.dart), so the start-up runs whatever other modules
// the app has.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the start-up initializes Firebase with the options of the app',
      () async {
    expect(Firebase.apps, isEmpty);

    await bootstrap();

    final app = Firebase.app();
    expect(app.name, defaultFirebaseAppName);
    expect(app.options, DefaultFirebaseOptions.currentPlatform);
    expect(app.options.projectId, 'smf-test');
  });
}
