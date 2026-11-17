// What the tests that continuous integration runs in an app with the
// update_required module need of the module, whichever module they test: the
// version of the app that package_info_plus gives, 1.0.0 with the build
// number 1, the version that smf create writes into the pubspec of the app.
// The matrix sets it up before the tests of every module of such an app
// (MatrixAppTest.mocks), since the start-up of the app reads the version.
//
// The backend of the mocks of every provider of remote config has no value
// of any parameter of the app, as the remote config role asks of them, so
// the lowest version that may run is the default of the module, none: the
// app runs, and the tests of the other modules see the screens that they
// expect.
import 'package:package_info_plus/package_info_plus.dart';

/// The version of the app in the tests, without its build number.
const String testVersion = '1.0.0';

/// Gives package_info_plus the values of the app in the tests, with the
/// version [version], [testVersion] unless a test gives another one.
void mockUpdateRequired({String version = testVersion}) =>
    PackageInfo.setMockInitialValues(
      appName: '{{app_name}}',
      packageName: 'com.example.{{app_name}}',
      version: version,
      buildNumber: '1',
      buildSignature: '',
    );
