import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

import 'support.dart';

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
      for (final name in [
        '2048',
        '',
        '---',
        'class',
        'import',
        'dynamic',
        'flutter',
        'flutter_test',
        'meta',
        'package',
        'fun',
        'Café',
      ]) {
        expect(
          () => AppNames.packageName(name),
          throwsA(isA<SmfUsageException>()),
          reason: name,
        );
      }
    });
  });

  group('orgSegments', () {
    test('lowercases each part as it is written', () {
      expect(AppNames.orgSegments('com.example'), ['com', 'example']);
      expect(AppNames.orgSegments('Com.MyCompany.'), ['com', 'mycompany']);
      expect(AppNames.orgSegments('io.my-org'), ['io', 'my-org']);
    });

    test('rejects parts that cannot be identifiers', () {
      for (final org in [
        'com.1up',
        '...',
        'com.new',
        r'com.my$org',
        'com.-x',
      ]) {
        expect(
          () => AppNames.orgSegments(org),
          throwsA(isA<SmfUsageException>()),
          reason: org,
        );
      }
    });
  });

  test('contextOf derives the platform identifiers', () {
    final context = AppNames.contextOf(name: 'My App', org: 'Com.Acme Corp');

    expect(context.appName, 'my_app');
    expect(context.orgName, 'com.acme_corp');
    expect(context.appIdentity.androidApplicationId, 'com.acme_corp.my_app');
    expect(context.appIdentity.androidNamespace, 'com.acme_corp.my_app');
    expect(context.appIdentity.iosBundleId, 'com.acme-corp.my-app');

    final hyphens = AppNames.contextOf(name: 'app', org: 'io.my-org');
    expect(hyphens.orgName, 'io.my_org');
    expect(hyphens.appIdentity.androidApplicationId, 'io.my_org.app');
    expect(hyphens.appIdentity.iosBundleId, 'io.my-org.app');
  });
}
