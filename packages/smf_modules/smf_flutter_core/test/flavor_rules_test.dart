import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/bundles/flutter_core_bundle.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The Gradle build script of the app module.
const String _gradle = AppEntryRole.gradleAppFile;

/// The Xcode project of the app.
const String _project = AppEntryRole.xcodeProjectFile;

/// The ids that the brick gives the build configurations of the flavor `dev`,
/// of the project itself and of the app target.
const _projectDebugDev = 'F1A500000000000000000000';
const _appDebugDev = 'F1A500000000000000000010';

void main() {
  /// The messages of the problems of the harness in the app of flutter_core
  /// with the [changes] of its brick: a change of the text of a file, by its
  /// path, or `null` to leave the file out.
  Future<List<String>> problemsWith(
    Map<String, String Function(String)?> changes,
  ) async {
    final result = await ContractHarness(
      ModuleRegistry([_PlantedBugModule(changes)]),
    ).check(
      const ContractCase('planted', requested: [FlutterCoreModule.id]),
    );
    return [for (final issue in result.issues) issue.message];
  }

  /// [text] with the first [from] after the start of the object [id] replaced
  /// by [to].
  String inObject(String text, String id, String from, String to) {
    final at = text.indexOf('$id /* Debug-dev */ = {');
    expect(at, isNonNegative, reason: 'The brick has no such object.');
    return text.replaceRange(
      at,
      null,
      text.substring(at).replaceFirst(from, to),
    );
  }

  test('the flavors of the brick keep the rules of the role', () async {
    expect(await problemsWith(const {}), isEmpty);
  });

  test('a flavor without its suffix breaks the rule of the flavors', () async {
    expect(
      await problemsWith({
        _gradle: (text) => text.replaceFirst(
              '            applicationIdSuffix = ".dev"\n',
              '',
            ),
      }),
      [
        equals(
          'The flavor dev in $_gradle builds the application id '
          'com.example.contract_app, but the id of the flavor is '
          'com.example.contract_app.dev.',
        ),
      ],
    );
  });

  test('a suffix on prod breaks the rule of the flavors', () async {
    expect(
      await problemsWith({
        _gradle: (text) => text.replaceFirst(
              'create("prod") {',
              'create("prod") {\n            applicationIdSuffix = ".prod"',
            ),
      }),
      [
        equals(
          'The flavor prod in $_gradle builds the application id '
          'com.example.contract_app.prod, but the id of the flavor is '
          'com.example.contract_app.',
        ),
      ],
    );
  });

  test('a configuration missing from one list breaks the rule of the flavors',
      () async {
    final problems = await problemsWith({
      _project: (text) => text.replaceFirst(
            '\t\t\t\t$_appDebugDev /* Debug-dev */,\n',
            '',
          ),
    });

    expect(problems, hasLength(1));
    expect(
      problems.single,
      matches(
        RegExp(
          r'^The build configuration list \w+ in '
          '${RegExp.escape(_project)} lacks Debug-dev\\.\$',
        ),
      ),
    );
  });

  test('a bundle id of another flavor breaks the rule of the flavors',
      () async {
    expect(
      await problemsWith({
        _project: (text) => inObject(
              text,
              _appDebugDev,
              '{{ios_bundle_id}}.dev',
              '{{ios_bundle_id}}.staging',
            ),
      }),
      [
        equals(
          'The build configuration Debug-dev of the app target in $_project '
          'has the bundle id "com.example.contract-app.staging", but the id '
          'of the flavor is com.example.contract-app.dev.',
        ),
      ],
    );
  });

  test('a missing scheme breaks the rule of the flavors', () async {
    final file = AppEntryRole.flavors[1].xcodeSchemeFile;

    expect(
      await problemsWith({file: null}),
      [
        equals(
          '$file is missing: a build of the flavor staging selects the scheme '
          'of the flavor by its name.',
        ),
      ],
    );
  });

  test('a scheme of another flavor breaks the rule of the flavors', () async {
    final file = AppEntryRole.flavors.first.xcodeSchemeFile;

    expect(
      await problemsWith({
        file: (text) => text.replaceFirst('Release-dev', 'Release-prod'),
      }),
      [
        equals(
          'ArchiveAction of $file takes the build configuration '
          '"Release-prod", but this flavor builds Release-dev there.',
        ),
      ],
    );
  });

  test('a literal minimum iOS version breaks the rule of its tag', () async {
    const tag = '{{{smf_app_entry__ios_deployment_target}}}';

    expect(
      await problemsWith({
        _project: (text) => inObject(text, _projectDebugDev, tag, '15.0'),
      }),
      [
        equals(
          'The build configuration Debug-dev ($_projectDebugDev) in $_project '
          'has IPHONEOS_DEPLOYMENT_TARGET = 15.0 instead of the tag $tag, so '
          'the version that a module raises does not reach it.',
        ),
      ],
    );
  });

  test('a flavor that signs without the entitlements breaks their rule',
      () async {
    expect(
      await problemsWith({
        _project: (text) => inObject(
              text,
              _appDebugDev,
              'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
              '',
            ),
      }),
      [
        equals(
          'The build configuration Debug-dev ($_appDebugDev) of the app target '
          'in $_project does not sign the app with '
          '${AppEntryRole.iosEntitlementsFile}.',
        ),
      ],
    );
  });
}

/// flutter_core with a bug in its brick: the [changes] of its files, each a
/// change of the text of a file, by its path, or `null` to leave it out.
final class _PlantedBugModule extends SmfModule {
  const _PlantedBugModule(this.changes);

  final Map<String, String Function(String)?> changes;

  @override
  ModuleDescriptor get descriptor => const FlutterCoreModule().descriptor;

  @override
  List<Contribution> contribute(ModuleContext context) => [
        for (final contribution
            in const FlutterCoreModule().contribute(context))
          if (contribution case BrickContribution(:final bundle)
              when identical(bundle, flutterCoreBundle))
            BrickContribution(
              _changed(bundle),
              vars: contribution.vars,
              when: contribution.when,
              whenChosen: contribution.whenChosen,
            )
          else
            contribution,
      ];

  MasonBundle _changed(MasonBundle bundle) => MasonBundle(
        name: bundle.name,
        description: bundle.description,
        version: bundle.version,
        files: [
          for (final file in bundle.files)
            if (!changes.containsKey(file.path))
              file
            else if (changes[file.path] case final change?)
              MasonBundledFile(
                file.path,
                base64.encode(
                  utf8.encode(change(utf8.decode(base64.decode(file.data)))),
                ),
                file.type,
              ),
        ],
      );
}
