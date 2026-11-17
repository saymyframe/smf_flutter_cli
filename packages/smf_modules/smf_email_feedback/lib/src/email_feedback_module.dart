import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_email_feedback/bundles/email_feedback_bundle.dart';
import 'package:smf_email_feedback/src/agents.dart';
import 'package:smf_email_feedback/src/readme.dart';

/// The module of feedback by email: "Write to us" opens a new mail to the
/// developer of the app in the mail app of the device, with url_launcher,
/// and so provides the feedback role.
///
/// The template of the role generates `FeedbackService`, the interface of
/// the service of a provider, and `appFeedback`, which the code of the app
/// calls from a button, and in an app with a settings screen the entry
/// "Write to us". This module adds `url_launcher`, `package_info_plus` and
/// `device_info_plus` to the dependencies of the app, and implements the
/// service in [serviceFile]:
/// - the mail goes to the address in [addressKey] of `.env`, a key of the
///   module, which the developer fills in by hand ([addressStep]). Without
///   an address the service is not available, so the entry hides;
/// - its subject is "Feedback: " and the name of the app, in the language of
///   the app, and its body leaves room for the message, then tells the
///   name, the version, the build number and the flavor of the app, from
///   package_info_plus and the flavor of the build, and the system and the
///   model of the device, from device_info_plus. The mail of the flavor for
///   a release names no flavor;
/// - the link encodes each part as RFC 6068 asks, so a space is `%20` and
///   never `+`, in [mailFile], which needs only Dart;
/// - it never asks the device first whether a mail app is there, which
///   Android 11 and later answer no to an app whose manifest names no other
///   app, and where no mail app opens the mail, it shows a sheet with the
///   address to copy, in [sheetFile].
///
/// The texts of the mail and of the sheet, [texts], are texts of the module,
/// in English and in Ukrainian, which it gives the localization role, a role
/// that the feedback role uses. The module adds the section [readmeHeading]
/// to the README of the app, and a note to the section of the role in the
/// guide for coding agents.
final class EmailFeedbackModule extends SmfModule {
  /// Creates the module.
  const EmailFeedbackModule();

  /// The id of the module.
  static const id = ModuleId('email_feedback');

  /// The key of the address that the mails go to.
  static const addressKey = EnvKey(
    'EMAIL_FEEDBACK_ADDRESS',
    description: 'The email address that "Write to us" mails go to, such as '
        'support@example.com',
  );

  /// The step by hand in which the developer puts the address into `.env`.
  static const addressStep = ManualStep(
    ManualStepId(id, 'address'),
    'Put the email address for "Write to us" into .env',
  );

  /// The texts of the module: the word of the subject of the mail, the
  /// header of what the mail tells about the app and the device, and the
  /// title, the text and the two labels of the button of the sheet with the
  /// address.
  static const texts = TextsData([
    LocalizedText(
      'subject',
      en: 'Feedback',
      translations: {'uk': 'Відгук'},
    ),
    LocalizedText(
      'details',
      en: 'About the app and the device:',
      translations: {'uk': 'Про застосунок і пристрій:'},
    ),
    LocalizedText(
      'noMailTitle',
      en: 'Write to us by email',
      translations: {'uk': 'Напишіть нам листом'},
    ),
    LocalizedText(
      'noMailText',
      en: "Couldn't open a mail app. Copy the address and write to us from "
          'your email.',
      translations: {
        'uk': 'Не вдалося відкрити поштовий застосунок. Скопіюйте адресу й '
            'напишіть нам зі своєї пошти.',
      },
    ),
    LocalizedText(
      'copy',
      en: 'Copy the address',
      translations: {'uk': 'Скопіювати адресу'},
    ),
    LocalizedText(
      'copied',
      en: 'Address copied',
      translations: {'uk': 'Адресу скопійовано'},
    ),
  ]);

  static const _file = ImportRef.app('core/feedback/$serviceFileName');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'An email to you from the mail app of the device, with '
            'url_launcher',
        kind: ModuleKinds.infrastructure,
        requires: {envRole},
        providers: [RoleProvider.plain(feedbackRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          emailFeedbackBundle,
          vars: {
            ...envRole.varsOf(id, const [addressKey]),
            ...localizationRole.varsOf(id, texts),
            'address_key': addressKey.name,
            'values_heading': EnvRole.readmeHeading,
            'release_flavor': AppEntryRole.releaseFlavor.name,
          },
        ),
        // The version of each is the one that the other modules of the app
        // take, such as those that open links with url_launcher.
        const PubspecContribution.hosted('url_launcher', 'any'),
        const PubspecContribution.hosted('package_info_plus', 'any'),
        const PubspecContribution.hosted('device_info_plus', 'any'),
        feedbackRole.data(
          const RoleImplementation(
            type: TypeRef('EmailFeedbackService', import: _file),
            create: FactoryRef('createEmailFeedbackService', import: _file),
          ),
        ),
        envRole.data(addressKey),
        localizationRole.data(texts),
        addressStep,
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          feedbackRole.description,
          AgentNote(agentNote),
        ),
      ];
}
