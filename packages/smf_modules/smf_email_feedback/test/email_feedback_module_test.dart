@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_email_feedback/bundles/email_feedback_bundle.dart';
import 'package:smf_email_feedback/smf_email_feedback.dart';
import 'package:smf_email_feedback/src/agents.dart';
import 'package:smf_email_feedback/src/readme.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, dart_define, the provider of the env role, which the module
/// requires, and settings and gen_l10n, providers of the settings screen
/// role and of the localization role, which the feedback role uses, with
/// go_router, the router that the settings screen requires, and
/// shared_preferences, the preferences that the localization role requires.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  SettingsModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
  DartDefineModule(),
  EmailFeedbackModule(),
];

/// The owner of the files of the module.
const _module = ModuleOrigin(EmailFeedbackModule.id);

/// The names of the cases of the module that the contract harness builds:
/// with each subset of the roles that the feedback role uses. The settings
/// screen brings the router that it requires.
const List<String> _cases = [
  'email_feedback with settings_screen, localization',
  'email_feedback with settings_screen',
  'email_feedback with localization',
  'email_feedback',
];

/// The files of the module, in the app.
const List<String> _files = [mailFile, serviceFile, sheetFile];

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

/// The links of [markdown], each as its text and its address.
List<(String, String)> _linksOf(String markdown) => [
      for (final match
          in RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)').allMatches(markdown))
        (match[1]!, match[2]!),
    ];

/// The text of [file] of [app] without its comments, so that a check of its
/// code does not find a word of a doc comment.
String _codeIn(RenderedApp app, String file) => app.files[file]!.text
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  const module = EmailFeedbackModule();

  group('EmailFeedbackModule', () {
    test(
        'is infrastructure that provides the feedback role and requires the '
        'env role, for its address', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('email_feedback'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {feedbackRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, {envRole});
      expect(descriptor.uses, isEmpty);
      // The settings screen and the localization, which the role uses.
      expect(descriptor.effectiveUses, feedbackRole.uses);
      expect(descriptor.variants, isNull);
      expect(descriptor.selectedByDefault, isFalse);
      expect(
        descriptor.description,
        'An email to you from the mail app of the device, with url_launcher',
      );
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick with the variables of its key and of its '
        'texts, url_launcher, package_info_plus and device_info_plus in the '
        'versions that the app takes, its implementation of the service, '
        'created with the app, its key, its texts, its step by hand, its '
        'section of the README and its note for coding agents, and nothing '
        'else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(10));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(emailFeedbackBundle));
      expect(brick.bundle.name, 'email_feedback');
      expect(
        [for (final file in brick.bundle.files) file.path]..sort(),
        [..._files]..sort(),
      );
      expect(brick.vars.keys.toSet(), {
        'env_email_feedback_address',
        'text_subject',
        'text_details',
        'text_no_mail_title',
        'text_no_mail_text',
        'text_copy',
        'text_copied',
        'address_key',
        'values_heading',
        'release_flavor',
      });
      expect(brick.vars['address_key'], 'EMAIL_FEEDBACK_ADDRESS');
      expect(brick.vars['values_heading'], EnvRole.readmeHeading);
      // The mail of the flavor for a release names no flavor.
      expect(brick.vars['release_flavor'], AppEntryRole.releaseFlavor.name);
      expect(
        [
          for (final dependency
              in contributions.sublist(1, 4).cast<PubspecDependency>())
            (dependency.package, dependency.constraint, dependency.dev),
        ],
        [
          // The versions that the other modules of the app take, such as
          // those that open links with url_launcher.
          ('url_launcher', 'any', false),
          ('package_info_plus', 'any', false),
          ('device_info_plus', 'any', false),
        ],
      );
      final data = contributions[4] as RoleData<Object>;
      expect(data.role, feedbackRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isFalse);
      expect(implementation.type.name, 'EmailFeedbackService');
      expect(implementation.create!.name, 'createEmailFeedbackService');
      expect(
        implementation.type.import,
        const ImportRef.app('core/feedback/email_feedback_service.dart'),
      );
      expect(implementation.create!.import, implementation.type.import);
      expect('lib/${implementation.type.import!.uri}', serviceFile);
      final key = contributions[5] as RoleData<Object>;
      expect((key.role, key.value), (envRole, EmailFeedbackModule.addressKey));
      final texts = contributions[6] as RoleData<Object>;
      expect(
        (texts.role, texts.value),
        (localizationRole, EmailFeedbackModule.texts),
      );
      expect(contributions[7], same(EmailFeedbackModule.addressStep));
      final readme = contributions[8] as SocketContribution;
      expect(readme.socket, AppEntryRole.readmeSections);
      expect(readme.entryKey, readmeHeading);
      expect(readme.entryValue, readmeSection);
      final note = contributions[9] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, feedbackRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      for (final contribution in contributions) {
        expect(contribution.when, isEmpty, reason: '$contribution');
      }
    });

    test(
        'has the key of the address that the mails go to, which the env role '
        'takes, and its step by hand under an id of its own', () {
      const key = EmailFeedbackModule.addressKey;
      expect(
        '${key.name} ${key.getter}: ${key.description}',
        'EMAIL_FEEDBACK_ADDRESS emailFeedbackAddress: The email address that '
            '"Write to us" mails go to, such as support@example.com',
      );
      expect(key.problems(), isEmpty);
      const step = EmailFeedbackModule.addressStep;
      expect(
        (step.id.wire, step.title),
        (
          'email_feedback.address',
          'Put the email address for "Write to us" into .env',
        ),
      );
    });

    test(
        'has the texts of the mail and of the sheet with the address in '
        'English and in Ukrainian', () {
      expect(
        {
          for (final text in EmailFeedbackModule.texts.texts)
            text.name: (text.en, text.textIn('uk')),
        },
        {
          'subject': ('Feedback', 'Відгук'),
          'details': (
            'About the app and the device:',
            'Про застосунок і пристрій:',
          ),
          'noMailTitle': ('Write to us by email', 'Напишіть нам листом'),
          'noMailText': (
            "Couldn't open a mail app. Copy the address and write to us from "
                'your email.',
            'Не вдалося відкрити поштовий застосунок. Скопіюйте адресу й '
                'напишіть нам зі своєї пошти.',
          ),
          'copy': ('Copy the address', 'Скопіювати адресу'),
          'copied': ('Address copied', 'Адресу скопійовано'),
        },
      );
      for (final text in EmailFeedbackModule.texts.texts) {
        expect(text.problems(), isEmpty, reason: text.name);
      }
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test(
        'builds the apps of the module with the settings screen and the '
        'localization, which the feedback role uses, and without each',
        () async {
      expect(
        [
          for (final result in results)
            if (result.contractCase.requested.contains(EmailFeedbackModule.id))
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
        'renders the three files of the module in every app, each Dart that '
        'parses, and lists its step by hand in each', () {
      for (final result in results) {
        if (!result.contractCase.requested.contains(EmailFeedbackModule.id)) {
          continue;
        }
        final app = result.app!;
        expect(
          [
            for (final file in app.files.values)
              if (file.owner == _module) file.path,
          ]..sort(),
          [..._files]..sort(),
          reason: '${result.contractCase}',
        );
        for (final path in _files) {
          expect(
            parseString(
              content: app.files[path]!.text,
              throwIfDiagnostics: false,
            ).errors,
            isEmpty,
            reason: '$path in ${result.contractCase}',
          );
        }
        expect(
          [for (final planned in result.manualSteps) planned.step.id.wire],
          contains('email_feedback.address'),
          reason: '${result.contractCase}',
        );
      }
    });
  });

  group('an app with the module', () {
    late RenderedApp app;
    late RenderedApp localized;
    late RenderedApp without;

    setUpAll(() async {
      app = (await _resultOf(const [EmailFeedbackModule.id])).app!;
      localized = (await _resultOf(const [
        EmailFeedbackModule.id,
        GenL10nModule.id,
      ]))
          .app!;
      without = (await _resultOf(const [DartDefineModule.id])).app!;
    });

    test(
        'adds url_launcher, package_info_plus and device_info_plus to the '
        'dependencies of the app, and nothing to its environment', () {
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['dependencies'],
        {
          ...(_yamlOf(without.files['pubspec.yaml']!.text)['dependencies']!
              as Map<String, Object?>),
          'url_launcher': 'any',
          'package_info_plus': 'any',
          'device_info_plus': 'any',
        },
      );
      expect(
        _yamlOf(app.files['pubspec.yaml']!.text)['environment'],
        _yamlOf(without.files['pubspec.yaml']!.text)['environment'],
      );
    });

    test(
        'has the key of the address in .env and in .env.example, without a '
        'value, under its description', () {
      for (final file in [EnvRole.dotEnvFile, EnvRole.exampleFile]) {
        expect(
          app.files[file]!.text,
          contains(
            '# The email address that "Write to us" mails go to, such as '
            'support@example.com\nEMAIL_FEEDBACK_ADDRESS=\n',
          ),
          reason: file,
        );
      }
    });

    test(
        'creates the service with the address of .env through the getter of '
        'AppEnv, and the implementation of the role with the function of the '
        'module', () {
      expect(
        app.files[serviceFile]!.text,
        contains(
          'FeedbackService createEmailFeedbackService() =>\n'
          '    EmailFeedbackService(address: AppEnv.emailFeedbackAddress);',
        ),
      );
      expect(
        app.files[FeedbackRole.controllerFile]!.text,
        contains('impl0.createEmailFeedbackService()'),
      );
    });

    test(
        'names the app in the subject in the case of its title, and the '
        'flavor for a release, which the mail leaves out', () {
      final mail = app.files[mailFile]!.text;

      expect(
        mail,
        contains("const String emailFeedbackAppName = 'Contract App';"),
      );
      expect(
        mail,
        contains(
          "const String _releaseFlavor = '${AppEntryRole.releaseFlavor.name}';",
        ),
      );
    });

    test(
        'reads the texts of the mail from the texts of the app in an app with '
        'the localization role, and as English literals without it, before '
        'it waits for anything', () {
      for (final (rendered, subject, details) in [
        (
          localized,
          'context.l10n.emailFeedbackSubject',
          'context.l10n.emailFeedbackDetails',
        ),
        (app, "'Feedback'", "'About the app and the device:'"),
      ]) {
        final code = _codeIn(rendered, serviceFile);
        final open = code.indexOf('Future<bool> open(BuildContext context)');
        final firstWait = code.indexOf('await ', open);
        expect(
          [code.indexOf(subject, open), code.indexOf(details, open)],
          everyElement(allOf(greaterThan(open), lessThan(firstWait))),
          reason: 'The texts are read from the context before the open waits '
              'for the details, while the context is surely mounted.',
        );
      }
      expect(
        _codeIn(localized, sheetFile),
        allOf(
          contains('context.l10n.emailFeedbackNoMailTitle'),
          contains('context.l10n.emailFeedbackNoMailText'),
          contains('context.l10n.emailFeedbackCopy'),
          contains('context.l10n.emailFeedbackCopied'),
        ),
      );
      expect(_codeIn(app, sheetFile), contains("'Copy the address'"));
    });

    test(
        'opens the mail with launchUrl outside the app, never asks the device '
        'first whether it can, and never builds the link with '
        'queryParameters, which would write a space as a plus', () {
      final code = _codeIn(app, serviceFile);
      final mail = _codeIn(app, mailFile);

      expect(
        code,
        allOf(
          contains(
            'await launchUrl(link, mode: LaunchMode.externalApplication)',
          ),
          isNot(contains('canLaunch')),
          contains('on PlatformException'),
          contains('on MissingPluginException'),
          contains('if (context.mounted) unawaited(showEmailFeedbackSheet('),
        ),
      );
      expect(
        mail,
        allOf(
          contains('Uri.encodeComponent(subject)'),
          contains('Uri.encodeComponent(body)'),
          isNot(contains('queryParameters')),
        ),
      );
    });

    test(
        'reads the version of the app and the device at once, each for a '
        'time at most, and leaves out what fails', () {
      final code = _codeIn(app, serviceFile);

      expect(
        code,
        allOf(
          contains('await (_appLine(), _deviceLine()).wait'),
          contains('PackageInfo.fromPlatform().timeout(_readTime)'),
          contains('DeviceInfoPlugin().androidInfo.timeout(_readTime)'),
          contains('DeviceInfoPlugin().iosInfo.timeout(_readTime)'),
          contains('Duration(milliseconds: 1500)'),
          contains('flavor: appFlavor'),
        ),
      );
    });

    test(
        'shows the sheet with the address on the navigator at the root of the '
        'app, at once with less motion, with a header, a button that copies '
        'the address and says so to a screen reader', () {
      final code = _codeIn(app, sheetFile);

      expect(
        code,
        allOf([
          contains('useRootNavigator: true'),
          contains('showDragHandle: true'),
          contains('MediaQuery.disableAnimationsOf(context)'),
          contains('AnimationStyle.noAnimation'),
          contains('header: true'),
          contains('liveRegion: true'),
          contains('FilledButton('),
          contains('Clipboard.setData(ClipboardData(text: widget.address))'),
          contains('SelectionArea('),
        ]),
      );
    });

    test('has url_launcher only in the file of the service', () {
      expect(
        [
          for (final file in app.files.values)
            if (file.path.endsWith('.dart') &&
                (file.text.contains('package:url_launcher/') ||
                    file.text.contains('package:package_info_plus/') ||
                    file.text.contains('package:device_info_plus/')))
              file.path,
        ],
        [serviceFile],
      );
    });

    group('the section of the module in the README of the app', () {
      test('refers to the sections of the feedback role and of .env', () {
        final readme = app.files[AppEntryRole.readmeFile]!.text;

        expect(readme, contains('\n## $readmeHeading\n\n$readmeSection'));
        expect(readme, contains('\n## ${FeedbackRole.readmeHeading}\n'));
        expect(
          readmeSection,
          allOf(
            contains('as the section "${FeedbackRole.readmeHeading}" tells'),
            contains('as the section "${EnvRole.readmeHeading}" says'),
          ),
        );
        expect(
          _codeOf(readmeSection),
          containsAll([
            serviceFile,
            mailFile,
            sheetFile,
            'EMAIL_FEEDBACK_ADDRESS',
            EnvRole.dotEnvFile,
            'EMAIL_FEEDBACK_ADDRESS=support@example.com',
            'emailFeedbackAppName',
            'emailFeedbackLink()',
          ]),
        );
        for (final path in [serviceFile, mailFile, sheetFile]) {
          expect(app.files, contains(path));
        }
      });

      test(
          'tells that the address is public, what the mail holds, that the '
          'app needs nothing of the platform to open it, what shows where no '
          'mail app opens it, and how to see it', () {
        expect(
          readmeSection,
          allOf([
            contains('The address goes into the app, where anyone can read '
                'it, so use an address for support with a filter of spam'),
            contains('Until it has one, the app does not offer the way to '
                'write'),
            contains('which the flavor for a release leaves out'),
            contains('so a space is `%20` and never `+`'),
            contains('no `<queries>` in the manifest of Android and no '
                '`LSApplicationQueriesSchemes` in `Info.plist`'),
            contains('such as on the iOS simulator, which has no Mail'),
            contains('a sheet shows the address with a button that copies '
                'it'),
            contains('run the app on an iPhone, or on an Android device or '
                'emulator with a mail app'),
          ]),
        );
        expect(
          _linksOf(readmeSection),
          [
            ('url_launcher', 'https://pub.dev/packages/url_launcher'),
            ('package_info_plus', 'https://pub.dev/packages/package_info_plus'),
            ('device_info_plus', 'https://pub.dev/packages/device_info_plus'),
          ],
        );
      });

      test(
          'tells what leaves the device: what the mail tells is read on the '
          'device and leaves it only in a mail that the user sends', () {
        expect(
          readmeSection,
          contains('What the mail tells about the app and the device is read '
              'on the device, and leaves it only in a mail that the user '
              'sends from their own mail app: the app itself sends nothing.'),
        );
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the feedback role of the guide, after what '
          'the role says', () {
        final notes = app.entriesOf(AppEntryRole.agentSections);

        expect(
          {
            for (final (origin, heading, note) in notes)
              if (origin == _module ||
                  origin == const RoleTemplateOrigin(feedbackRole))
                (origin, heading, note.isOfRole),
          },
          {
            (_module, feedbackRole.description, false),
            (
              const RoleTemplateOrigin(feedbackRole),
              feedbackRole.description,
              true,
            ),
          },
        );
        expect(agentNote, startsWith('With `url_launcher`:\n'));
        final guide = app.files[AppEntryRole.agentsFile]!.text;
        expect(guide, contains('\n${agentNote.trim()}\n'));
        expect(
          guide.indexOf(agentNote.trim()),
          greaterThan(guide.indexOf('\n## ${feedbackRole.description}\n')),
        );
      });

      test(
          'names the files of the module and what they declare and call, how '
          'to build a link of a mail, and the call that the app never makes',
          () {
        final service = DartFileIndexer.index(
          serviceFile,
          app.files[serviceFile]!.text,
        );
        final mail = DartFileIndexer.index(mailFile, app.files[mailFile]!.text);
        final sheet = DartFileIndexer.index(
          sheetFile,
          app.files[sheetFile]!.text,
        );

        expect(_codeOf(agentNote), {
          'url_launcher',
          'EmailFeedbackService',
          serviceFile,
          'FeedbackService',
          FeedbackRole.serviceFile,
          'EMAIL_FEEDBACK_ADDRESS',
          EnvRole.dotEnvFile,
          'launchUrl',
          'mailto:',
          'emailFeedbackLink()',
          mailFile,
          'PackageInfo.fromPlatform()',
          'DeviceInfoPlugin()',
          'Uri.encodeComponent',
          'Uri(queryParameters: ...)',
          '+',
          'canLaunchUrl',
          '<queries>',
          'showEmailFeedbackSheet()',
          sheetFile,
        });
        expect(service.declaration('EmailFeedbackService'), isNotNull);
        expect(mail.declaration('emailFeedbackLink'), isNotNull);
        expect(sheet.declaration('showEmailFeedbackSheet'), isNotNull);
        expect(
          app.files[serviceFile]!.text,
          allOf(
            contains('launchUrl('),
            contains('PackageInfo.fromPlatform()'),
            contains('DeviceInfoPlugin()'),
          ),
        );
        expect(app.files[mailFile]!.text, contains('Uri.encodeComponent('));
        expect(
          app.files[FeedbackRole.serviceFile]!.text,
          contains('abstract interface class FeedbackService'),
        );
      });
    });

    test('has a README that leads to the page of the module', () {
      final readme = File('README.md').readAsStringSync();

      expect(
        readme,
        contains('(https://doc.saymyframe.com/modules/email-feedback)'),
      );
    });
  });
}
