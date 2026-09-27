// The platform side of Firebase Core for the tests that continuous
// integration runs in the apps with Firebase, which run the Firebase
// packages without a Firebase project, and without a device.
import 'package:firebase_core_platform_interface/test.dart';

/// Answers the platform side of Firebase Core: an app initializes with the
/// options it gives, and gets [pluginConstants], the constants of the
/// plugins of Firebase by their channel, such as those that a plugin reads
/// when it starts.
///
/// The binding of the tests must be initialized first.
void mockFirebaseCore({
  Map<String, Map<String, Object?>> pluginConstants = const {},
}) {
  TestFirebaseCoreHostApi.setUp(_FirebaseCore(pluginConstants));
}

final class _FirebaseCore implements TestFirebaseCoreHostApi {
  _FirebaseCore(this.pluginConstants);

  final Map<String, Map<String, Object?>> pluginConstants;

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async =>
      CoreInitializeResponse(
        name: appName,
        options: initializeAppRequest,
        pluginConstants: pluginConstants,
      );

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreFirebaseOptions> optionsFromResource() =>
      throw UnsupportedError('The app gives the options of Firebase.');
}
