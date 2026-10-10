// A test that continuous integration runs in the apps with the
// firebase_auth module, on the real Firebase packages, whose platform side
// is a backend in memory (firebase_auth_mocks.dart): the sign-in service of
// the module, which createFirebaseAuthService() creates, has the user whom
// Firebase kept on the device from the moment it is created, without a
// call of Firebase. Firebase deletes the account of such a user only once
// the user has signed in again: until then the deletion fails with
// recentSignInRequired and leaves the user.
//
// The backend starts with nobody signed in, as on a first launch, so the
// test puts a user on the device itself, before Firebase is initialized,
// which is when the plugin gets that user. It has a file of its own, since
// Firebase is initialized once in a test file. It uses the service of the
// module and runs none of the start-up of the app but the start of
// Firebase (service.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/auth/auth_service.dart';
import 'package:{{app_name}}/core/auth/firebase_auth_service.dart';

import '../firebase_auth_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = 'restored-user';
  final email = addressOf('restored');
  late MockFirebaseAuth firebase;

  setUpAll(() async {
    firebase = mockFirebaseAuth()
      ..restoreUser(uid, email: email, password: password);
    await initializeFirebase();
  });

  test(
      'the service has the user of the device from the moment it is '
      'created, without a call of Firebase', () {
    final service = createFirebaseAuthService();

    expect(
      [userOf(service.currentUser), firebase.calls],
      ['the account $uid of $email', isEmpty],
      reason: 'Firebase keeps the user on the device and hands that user '
          'over when it is initialized, so the service has the user as soon '
          'as it is created, and asks Firebase for nothing.',
    );
  });

  test(
      'the deletion of the account of a user who did not sign in since the '
      'app started fails with recentSignInRequired, and succeeds once the '
      'user has signed in again', () async {
    final service = createFirebaseAuthService();

    final first = outcomeOf(await errorOf(service.deleteAccount));
    final kept = userOf(service.currentUser);
    await service.signOut();
    await service.signIn(email: email, password: password);
    final signedIn = userOf(service.currentUser);
    final second = outcomeOf(await errorOf(service.deleteAccount));
    final after = userOf(service.currentUser);
    final gone = outcomeOf(
      await errorOf(() => service.signIn(email: email, password: password)),
    );

    expect(
      (first, kept),
      (
        AuthFailureReason.recentSignInRequired.name,
        'the account $uid of $email'
      ),
      reason: 'Firebase deletes an account only for a user who signed in a '
          'short while ago. For a user whom the service found on the '
          'device it answers requires-recent-login: the deletion fails with '
          'recentSignInRequired, and the user stays signed in.',
    );
    expect(
      (signedIn, second, after, gone),
      (
        'the account $uid of $email',
        'completed',
        'nobody',
        AuthFailureReason.invalidCredentials.name
      ),
      reason: 'Once the user has signed in again, the deletion succeeds: '
          'nobody is signed in, and the account is gone.',
    );
  });
}
