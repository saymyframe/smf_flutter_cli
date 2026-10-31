// What the REST role gives an app, which the package of the role cannot render
// itself, since it has no app entry: the permission in the manifest of the
// Android app. And the module of the fixtures that makes requests, which shows
// the form of the role: the module knows the role and nothing else.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// The path of the main manifest of the Android app.
const _manifest = 'android/app/src/main/AndroidManifest.xml';

void main() {
  final harness = ContractHarness(ModuleRegistry(fixtureModules()));

  Future<RenderedApp> appOf(List<ModuleId> modules) async {
    final result = await harness.check(
      ContractCase('app of the test', requested: modules),
    );
    expect(result.errors.map((issue) => '$issue'), isEmpty);
    return result.app!;
  }

  /// The permissions in the main manifest of [app].
  List<String> permissionsOf(RenderedApp app) => [
        for (final element in XmlDocument.parse(app.files[_manifest]!.text)
            .findAllElements('uses-permission'))
          element.getAttribute('android:name')!,
      ];

  test(
      'an app with the role has the permission of the network in its main '
      'manifest, which a release build needs, and an app without it has none',
      () async {
    expect(
      permissionsOf(await appOf(const [FakeRestModule.id])),
      contains(RestRole.internetPermission),
    );
    expect(
      permissionsOf(await appOf(const [FakeEnvModule.id])),
      isNot(contains(RestRole.internetPermission)),
    );
  });

  test(
      'the module that makes requests imports the client of the role and '
      'Flutter, and so names no provider of the role, no router and no DI '
      'container', () async {
    final app = await appOf(const [FakeRestUserModule.id]);
    final file = app.files['lib/core/fixture_notes/fixture_notes.dart']!;

    expect(
      [
        for (final directive in parseString(content: file.text).unit.directives)
          if (directive is ImportDirective) directive.uri.stringValue,
      ],
      ['package:flutter/foundation.dart', '../rest/app_rest.dart'],
    );
  });

  test('the module brings the role into an app, with its key', () async {
    final app = await appOf(const [FakeRestUserModule.id]);

    expect(app.files.keys, contains(RestRole.clientFile));
    expect(
      app.owners[RestRole.clientFile],
      const RoleTemplateOrigin(restRole),
    );
    expect(
      app.files[EnvRole.dotEnvFile]!.text,
      contains('${RestRole.baseAddressKey.name}=\n'),
    );
  });
}
