// A test that continuous integration runs in the apps with the
// firebase_auth module, on the real Firebase packages, whose platform side
// is a backend in memory (firebase_auth_mocks.dart): an anonymous user whom
// Firebase kept on the device has no email address for the sign-in service
// of the module, which createFirebaseAuthService() creates. Android hands
// such a user over with an empty text for the address, not with none as
// iOS does, until the user is reloaded, and the backend does as Android.
//
// The backend starts with nobody signed in, as on a first launch, so the
// test puts the user on the device itself, before Firebase is initialized,
// which is when the plugin gets that user. It has a file of its own, since
// Firebase is initialized once in a test file. It uses the service of the
// module and runs none of the start-up of the app but the start of
// Firebase (service.dart).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/firebase_auth_service.dart';

import '../firebase_auth_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = 'restored-anonymous-user';

  setUpAll(() async {
    mockFirebaseAuth().restoreUser(uid);
    await initializeFirebase();
  });

  test(
      'an anonymous user whom Android kept on the device has no email '
      'address for the service, though Firebase has an empty one', () {
    final ofFirebase = FirebaseAuth.instance.currentUser;
    final service = createFirebaseAuthService();

    expect(
      (ofFirebase?.isAnonymous, ofFirebase?.email),
      (true, ''),
      reason: 'As on Android, the plugin has an empty text for the address '
          'of an anonymous user whom Firebase kept on the device.',
    );
    expect(
      (userOf(service.currentUser), service.currentUser?.email),
      ('the anonymous user $uid', null),
      reason: 'An anonymous user has no email address: the service takes '
          'an empty address of Firebase for none.',
    );
  });
}
