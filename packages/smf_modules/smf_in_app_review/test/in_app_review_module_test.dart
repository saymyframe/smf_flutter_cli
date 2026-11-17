@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_in_app_review/bundles/in_app_review_bundle.dart';
import 'package:smf_in_app_review/smf_in_app_review.dart';
import 'package:smf_in_app_review/src/agents.dart';
import 'package:smf_in_app_review/src/readme.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, shared_preferences and dart_define, the providers of the
/// preferences role and of the env role, which the review role requires,
/// and settings and gen_l10n, providers of the settings screen role and of
/// the localization role, which the review role uses, with go_router, the
/// router that the review role uses too and that the settings screen
/// requires.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  SettingsModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
  DartDefineModule(),
  InAppReviewModule(),
];

/// The owner of the service of the module.
const _module = ModuleOrigin(InAppReviewModule.id);

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _resultOf(List<ModuleId> modules) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The pubspec [text] as plain maps and lists.
Map<String, Object?> _yamlOf(String text) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(text))! as Map<String, Object?>;
}

/// The inline code of [markdown]: what stands between two backticks,
/// outside its blocks of code.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(
        markdown.replaceAll(RegExp(r'```[\s\S]*?```'), ''),
      ))
        match[1]!,
    };

/// The doc comment of the class [name] in [dart], the text of a Dart file,
/// with its lines joined by spaces.
String _docOf(String dart, String name) {
  final type = parseString(content: dart)
      .unit
      .declarations
      .whereType<ClassDeclaration>()
      .singleWhere((type) => type.namePart.typeName.lexeme == name);
  return [
    for (final token in type.documentationComment!.tokens)
      token.lexeme.replaceFirst(RegExp('^/// ?'), ''),
  ].join(' ');
}

/// The links of [markdown], each as its text and its address.
List<(String, String)> _linksOf(String markdown) => [
      for (final match
          in RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)').allMatches(markdown))
        (match[1]!, match[2]!),
    ];

/// Runs the service of the module on the stand-ins for in_app_review,
/// url_launcher and package_info_plus, and sends back what each call ended
/// with and what reached the stand-ins.
///
/// It imports the file of the module and the stand-ins, which need nothing
/// but Dart.
const _script = r'''
import 'dart:isolate';

import 'package:contract_app/core/review/in_app_review_service.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// What [action] ended with: what it returned, or what it threw.
Future<String> outcome(Future<Object?> Function() action) async {
  try {
    return 'returned ${await action()}';
  } on Object catch (error) {
    return 'threw $error';
  }
}

Future<void> main(List<String> arguments, SendPort port) async {
  final service = createInAppReviewService();
  final play = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.example.my_app',
  );
  final appStore = Uri.parse(
    'https://apps.apple.com/app/id1234567890?action=write-review',
  );
  final result = <String, Object?>{};
  result['available'] = await outcome(service.isAvailable);
  storeAvailable = false;
  result['available without the dialog'] = await outcome(service.isAvailable);
  failNextReview = StateError('No store.');
  result['available failing'] = await outcome(service.isAvailable);
  result['request'] = await outcome(service.requestReview);
  failNextReview = StateError('In-App Review API unavailable');
  result['request refused'] = await outcome(service.requestReview);
  result['calls before the pages'] = [...reviewCalls];
  result['page'] = await outcome(() => service.openStorePage(play));
  result['page for a review'] =
      await outcome(() => service.openStorePage(appStore));
  linkOpens = false;
  result['page not opened'] = await outcome(() => service.openStorePage(play));
  failNextLaunch = StateError('No app opens it.');
  result['page failing'] = await outcome(() => service.openStorePage(play));
  result['version'] = await outcome(service.appVersion);
  appVersionOfPlatform = ' 2.1.0 ';
  result['version with spaces'] = await outcome(service.appVersion);
  appVersionOfPlatform = '';
  result['version empty'] = await outcome(service.appVersion);
  failPackageInfo = StateError('No platform.');
  result['version failing'] = await outcome(service.appVersion);
  result['calls'] = reviewCalls;
  result['launched'] = launched;
  port.send(result);
}
''';

void main() {
  const module = InAppReviewModule();

  group('InAppReviewModule', () {
    test('is infrastructure that provides the review role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('in_app_review'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {reviewRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.effectiveUses, reviewRole.uses);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, in_app_review, url_launcher and '
        'package_info_plus, its implementation of the service, created with '
        'the app, its section of the README and its note for coding agents, '
        'and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(7));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(inAppReviewBundle));
      expect(brick.bundle.name, 'in_app_review');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [serviceFile],
      );
      expect(brick.vars, isEmpty);
      expect(
        [
          for (final dependency
              in contributions.sublist(1, 4).cast<PubspecDependency>())
            (dependency.package, dependency.constraint, dependency.dev),
        ],
        [
          ('in_app_review', '^2.0.12', false),
          // The versions that the other modules of the app take, such as the
          // paywall, which opens its links with url_launcher.
          ('url_launcher', 'any', false),
          ('package_info_plus', 'any', false),
        ],
      );
      final data = contributions[4] as RoleData<Object>;
      expect(data.role, reviewRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'InAppReviewService');
      expect(implementation.create!.name, 'createInAppReviewService');
      expect(
        implementation.type.import,
        const ImportRef.app('core/review/in_app_review_service.dart'),
      );
      expect(implementation.create!.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', serviceFile);
      final readme = contributions[5] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, readmeHeading);
      expect(readme.entryValue, readmeSection);
      final note = contributions[6] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, reviewRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      for (final contribution in contributions) {
        expect(contribution.when, isEmpty, reason: '$contribution');
      }
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the apps of the module with the router, the settings screen '
        'and the localization, which the review role uses, and without each',
        () async {
      expect(
        [
          for (final result in results)
            if (result.contractCase.requested.contains(InAppReviewModule.id))
              result.contractCase.name,
        ],
        _cases,
      );
      expect(
        await ContractHarness(ModuleRegistry(_modules)).uncheckedProviders(),
        isEmpty,
      );
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test(
        'renders the same service in every app, the only file of the module, '
        'which type-checks with in_app_review, url_launcher and '
        'package_info_plus', () async {
      final withService = [
        for (final result in results)
          if (result.app!.files.containsKey(serviceFile)) result,
      ];
      expect(withService, hasLength(_cases.length));
      expect(
        {
          for (final result in withService)
            result.app!.files[serviceFile]!.text,
        },
        hasLength(1),
      );
      for (final result in withService) {
        expect(
          [
            for (final file in result.app!.files.values)
              if (file.owner == _module) file.path,
          ],
          [serviceFile],
          reason: '${result.contractCase}',
        );
        final app = DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems({_module}),
            isEmpty,
            reason: '${result.contractCase}',
          );
        } finally {
          app.delete();
        }
      }
    });
  });

  group('an app with the module', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [InAppReviewModule.id]);
      app = result.app!;
      without = (await _resultOf(const [
        SharedPreferencesModule.id,
        DartDefineModule.id,
      ]))
          .app!;
    });

    test(
        'adds in_app_review, url_launcher and package_info_plus to the '
        'dependencies of the app, and nothing to its environment', () {
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['dependencies'],
        {
          ...(_yamlOf(without.files['pubspec.yaml']!.text)['dependencies']!
              as Map<String, Object?>),
          'in_app_review': '^2.0.12',
          'url_launcher': 'any',
          'package_info_plus': 'any',
        },
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['environment'],
        _yamlOf(without.files['pubspec.yaml']!.text)['environment'],
      );
    });

    test(
        'creates the service with the function of the module when the reviews '
        'start in bootstrap()', () {
      final init = parseString(
        content: app.files[ReviewRole.controllerFile]!.text,
      )
          .unit
          .declarations
          .whereType<FunctionDeclaration>()
          .singleWhere((function) => function.name.lexeme == 'initReview');
      final body = init.functionExpression.body as BlockFunctionBody;

      expect(
        [for (final statement in body.block.statements) '$statement'],
        [
          '_reviewService = impl0.createInAppReviewService();',
          'await appReview.start(_reviewService);',
        ],
      );
    });

    test(
        'asks the store through the package and lets a refusal through, '
        'opens exactly the page that it gets with url_launcher, outside the '
        'app, and never through the package, and gives the version of the '
        'app; the questions and the pages never throw', () async {
      final dartApp = DartApp.write(app);
      late Map<Object?, Object?> outcome;
      try {
        outcome = (await dartApp.run(_script))! as Map<Object?, Object?>;
      } finally {
        dartApp.delete();
      }

      expect(
        [
          outcome['available'],
          outcome['available without the dialog'],
          outcome['available failing'],
        ],
        ['returned true', 'returned false', 'returned false'],
        reason: 'isAvailable() is what the package answers, and false when '
            'the package fails to tell.',
      );
      expect(
        [outcome['request'], outcome['request refused']],
        [
          'returned null',
          'threw Bad state: In-App Review API unavailable',
        ],
        reason: 'requestReview() asks the package, and throws what the '
            'platform throws when it refuses the request: the role catches '
            'it and records no request.',
      );
      expect(
        outcome['calls before the pages'],
        [
          'isAvailable',
          'isAvailable',
          'isAvailable',
          'requestReview',
          'requestReview',
        ],
      );
      expect(
        [
          outcome['page'],
          outcome['page for a review'],
          outcome['page not opened'],
          outcome['page failing'],
        ],
        ['returned true', 'returned true', 'returned false', 'returned false'],
        reason: 'openStorePage() returns whether an app of the device opened '
            'the page, and false when url_launcher fails.',
      );
      const play =
          'https://play.google.com/store/apps/details?id=com.example.my_app';
      const appStore =
          'https://apps.apple.com/app/id1234567890?action=write-review';
      expect(
        outcome['launched'],
        [
          '$play externalApplication',
          '$appStore externalApplication',
          '$play externalApplication',
          '$play externalApplication',
        ],
        reason: 'openStorePage() gives url_launcher exactly the page that it '
            'gets, to open outside the app.',
      );
      expect(
        outcome['calls'],
        outcome['calls before the pages'],
        reason: 'openStorePage() never asks the package, whose '
            'openStoreListing() opens the page of the id of the build that '
            'runs on Android, which has no page for a flavor other than the '
            'one for a release.',
      );
      expect(
        [
          outcome['version'],
          outcome['version with spaces'],
          outcome['version empty'],
          outcome['version failing'],
        ],
        ['returned 1.0.0', 'returned 2.1.0', 'returned null', 'returned null'],
        reason: 'appVersion() is the version of the app, without its build '
            'number, and null when it is empty or package_info_plus fails.',
      );
    });

    test('has the package only in the file of the service', () {
      expect(
        [
          for (final file in app.files.values)
            if (file.path.endsWith('.dart') &&
                (file.text.contains('package:in_app_review/') ||
                    file.text.contains('package:package_info_plus/')))
              file.path,
        ],
        [serviceFile],
      );
    });

    group('the section of the module in the README of the app', () {
      test('refers to the section of the review role', () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;

        expect(readme, contains('\n## $readmeHeading\n\n$readmeSection'));
        expect(readme, contains('\n## ${ReviewRole.readmeHeading}\n'));
        expect(
          readmeSection,
          contains('as the section "${ReviewRole.readmeHeading}" tells'),
        );
        expect(_codeOf(readmeSection), contains(serviceFile));
      });

      test(
          'tells that the app asks only where its code asks, and how to see '
          'the dialog of Google Play before the app is published, with the '
          'page of Google on it', () {
        expect(_codeOf(readmeSection), contains('appReview.requestIfDue()'));
        expect(
          readmeSection,
          allOf(
            contains(
              'The app asks only where its code calls '
              '`appReview.requestIfDue()`, and nothing asks on its own.',
            ),
            contains('Google Play shows the dialog only in an app that it '
                'installed.'),
            contains('internal test track'),
            contains('Gmail account'),
            contains('local builds of the flavor `prod`'),
          ),
        );
        expect(
          readmeSection,
          allOf(
            contains('Google Play does not limit how often it shows the '
                'dialog to an app from the internal test track.'),
            contains('Never send the review of a test, or delete it'),
            contains('its review cannot be sent'),
          ),
        );
        expect(
          _linksOf(readmeSection),
          containsAll([
            ('Test in-app reviews', testPage),
            ('the In-App Review API', reviewPage),
          ]),
        );
      });

      test(
          'tells, as the doc of the service does, the two cases of Android '
          'outside an app that Google Play installed: without the review '
          'service of Google Play the app records nothing and asks again, '
          'and with the Play Store a request that shows nothing counts', () {
        expect(
          readmeSection,
          allOf(
            contains(
              'On a device without the review service of Google Play, such as '
              'an emulator without the Play Store, the store cannot take the '
              'request, the app records nothing, and the next call of '
              '`appReview.requestIfDue()` asks again.',
            ),
            contains(
              'On a device with the Play Store, for a build that Google Play '
              'did not install, such as a local build of the flavor `dev`, '
              'the request completes and shows nothing, and the app counts it '
              'as a request, so it does not ask again in that version of the '
              'app.',
            ),
          ),
        );
        expect(readmeSection, isNot(contains('Anywhere else')));
        expect(
          _docOf(app.files[serviceFile]!.text, 'InAppReviewService'),
          allOf(
            contains(
              'On a device without the review service of Google Play, such as '
              'an emulator without the Play Store, [isAvailable] is `false` '
              'and [requestReview] fails, so the app records no request and '
              'asks again later.',
            ),
            contains(
              'On a device with the Play Store, for an app that Google Play '
              'did not install, such as a local build, [requestReview] '
              'completes and shows nothing, and the app counts the request, '
              'so it does not ask again in that version of the app.',
            ),
            isNot(contains('Elsewhere')),
          ),
        );
      });

      test(
          'tells what Google Play collects through the dialog, and that both '
          'stores require a privacy policy', () {
        expect(
          readmeSection,
          allOf(
            contains('Google Play collects the rating and the text of the '
                'review'),
            contains('which only you see for an app on a closed test track'),
            contains('the section "Data Safety"'),
            contains('Both stores require a link to a privacy policy in the '
                'listing of the app and inside the app.'),
          ),
        );
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the review role of the guide, after what the '
          'role says', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);

        expect(
          {
            for (final (origin, heading, note) in notes)
              if (origin == _module ||
                  origin == const RoleTemplateOrigin(reviewRole))
                (origin, heading, note.isOfRole),
          },
          {
            (_module, reviewRole.description, false),
            (
              const RoleTemplateOrigin(reviewRole),
              reviewRole.description,
              true,
            ),
          },
        );
        expect(agentNote, startsWith('With `in_app_review`:\n'));
        final guide = app.files[AppEntryRole.agentsFile]!.text;
        expect(guide, contains('\n${agentNote.trim()}\n'));
        expect(
          guide.indexOf(agentNote.trim()),
          greaterThan(guide.indexOf('\n## ${reviewRole.description}\n')),
        );
      });

      test(
          'tells that the app asks only where its code asks, how Google Play '
          'shows the dialog, that a test review is never sent, what Google '
          'Play collects, and that both stores require a privacy policy', () {
        expect(
          agentNote,
          allOf(
            contains('The app asks for the dialog only where its code calls '
                '`appReview.requestIfDue()`.'),
            contains('Google Play shows the dialog only in an app that it '
                'installed, such as from an internal test track'),
            contains('A test review is never sent'),
            contains('Google Play collects the rating and the text of a '
                'review.'),
            contains('Both stores require a link to a privacy policy in the '
                'listing of the app and inside the app.'),
          ),
        );
      });

      test(
          'names the file of the module and what it declares and calls, the '
          'call of the app that asks, and the call of the package that it '
          'keeps out', () {
        final service = DartFileIndexer.index(
          serviceFile,
          app.files[serviceFile]!.text,
        );
        final text = app.files[serviceFile]!.text;

        expect(_codeOf(agentNote), {
          'in_app_review',
          'InAppReviewService',
          serviceFile,
          'ReviewService',
          ReviewRole.serviceFile,
          'InAppReview.instance.requestReview()',
          'launchUrl',
          'PackageInfo.fromPlatform()',
          'lib/',
          'openStoreListing()',
          'dev',
          'appReview.openStorePage()',
          'appReview.requestIfDue()',
        });
        expect(service.declaration('InAppReviewService'), isNotNull);
        expect(
          text,
          allOf(
            contains('InAppReview.instance.requestReview()'),
            contains('launchUrl('),
            contains('PackageInfo.fromPlatform()'),
            isNot(contains('.openStoreListing(')),
          ),
        );
        expect(
          app.files[ReviewRole.serviceFile]!.text,
          contains('abstract interface class ReviewService'),
        );
      });
    });

    test('has a README that leads to the page of the module', () {
      final readme = File('README.md').readAsStringSync();

      expect(
        readme,
        contains('(https://doc.saymyframe.com/modules/in-app-review)'),
      );
    });
  });
}

/// The names of the cases of the module that the contract harness builds:
/// with each subset of the roles that the review role uses. The settings
/// screen requires the router, so it comes with the router alone.
const List<String> _cases = [
  'in_app_review with router, settings_screen, localization',
  'in_app_review with router, settings_screen',
  'in_app_review with router, localization',
  'in_app_review with router',
  'in_app_review with localization',
  'in_app_review',
];
