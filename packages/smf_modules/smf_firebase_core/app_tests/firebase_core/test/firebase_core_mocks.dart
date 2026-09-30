// The platform side of Firebase Core for the tests that continuous
// integration runs in the apps with Firebase, which run the Firebase
// packages without a Firebase project, and without a device. The matrix
// sets it up before the tests of every module of such an app
// (MatrixAppTest.mocks), so that any of them may run the start-up of the
// app, which initializes Firebase. The mocks of the modules that depend on
// firebase_core add the constants of their plugins.
import 'package:firebase_core_platform_interface/test.dart';

/// The constants of the plugins of Firebase by their channel, such as those
/// that a plugin reads when it starts, which an app gets when it
/// initializes Firebase: the mocks of the Firebase modules add theirs.
final Map<String, Map<String, Object?>> firebasePluginConstants = {};

/// Answers the platform side of Firebase Core: an app initializes with the
/// options it gives, and gets the [firebasePluginConstants] of that moment.
///
/// The binding of the tests must be initialized first.
void mockFirebaseCore() {
  TestFirebaseCoreHostApi.setUp(_FirebaseCore());
}

final class _FirebaseCore implements TestFirebaseCoreHostApi {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async =>
      CoreInitializeResponse(
        name: appName,
        options: initializeAppRequest,
        pluginConstants: {...firebasePluginConstants},
      );

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreFirebaseOptions> optionsFromResource() =>
      throw UnsupportedError('The app gives the options of Firebase.');

  // A method that a later version of the package adds fails only if the
  // app calls it.
  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
