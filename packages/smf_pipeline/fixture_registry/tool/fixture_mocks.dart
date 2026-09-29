import 'dart:io';
import 'dart:isolate';

import 'package:fake_infra/fake_infra.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// The mocks of the platform side of the fixture providers of crash
/// reporting and analytics, which their start-up and services reach, in the
/// directory `app_tests` of their package: the matrix sets them up for the
/// tests of every module of the apps with them.
Future<List<MatrixAppTest>> fixtureMocks() async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:fake_infra/'),
  );
  final appTests =
      Directory.fromUri(library!).parent.uri.resolve('app_tests').toFilePath();
  return [
    MatrixAppTest(
      '$appTests/fake_crash',
      appliesTo: (app) => app.modules.contains(FakeCrashModule.id),
      mocks: const MatrixMocks(
        'test/fake_crash_mocks.dart',
        'mockFixtureCrash',
      ),
    ),
    MatrixAppTest(
      '$appTests/fake_analytics',
      appliesTo: (app) => app.modules.contains(FakeAnalyticsModule.id),
      mocks: const MatrixMocks(
        'test/fake_analytics_mocks.dart',
        'mockFixtureAnalytics',
      ),
    ),
  ];
}
