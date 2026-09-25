import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('packageName', () {
    test('converts names to snake_case', () {
      expect(AppNames.packageName('my_app'), 'my_app');
      expect(AppNames.packageName('My App'), 'my_app');
      expect(AppNames.packageName('myApp'), 'my_app');
      expect(AppNames.packageName('my-app2'), 'my_app2');
      expect(AppNames.packageName('HTTPClient'), 'http_client');
    });

    test('rejects names that cannot be package names', () {
      for (final name in ['2048', '', '---', 'class']) {
        expect(
          () => AppNames.packageName(name),
          throwsA(isA<SmfUsageException>()),
          reason: name,
        );
      }
    });
  });

  group('orgSegments', () {
    test('converts each part to snake_case', () {
      expect(AppNames.orgSegments('com.example'), ['com', 'example']);
      expect(AppNames.orgSegments('Com.MyCompany.'), ['com', 'my_company']);
    });

    test('rejects parts that do not start with a letter', () {
      expect(
        () => AppNames.orgSegments('com.1up'),
        throwsA(isA<SmfUsageException>()),
      );
      expect(
        () => AppNames.orgSegments('...'),
        throwsA(isA<SmfUsageException>()),
      );
    });
  });

  test('contextOf derives the platform identifiers', () {
    final context = AppNames.contextOf(name: 'My App', org: 'Com.Acme Corp');

    expect(context.appName, 'my_app');
    expect(context.orgName, 'com.acme_corp');
    expect(context.appIdentity.androidApplicationId, 'com.acme_corp.my_app');
    expect(context.appIdentity.androidNamespace, 'com.acme_corp.my_app');
    expect(context.appIdentity.iosBundleId, 'com.acme-corp.my-app');
  });
}
