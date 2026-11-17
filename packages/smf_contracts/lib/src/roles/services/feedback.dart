part of '../services.dart';

/// The feedback role; see [FeedbackRole].
const feedbackRole = FeedbackRole._();

/// The role of feedback: the way through which the users of the app write to
/// its developer, such as a new mail in the mail app of the device, a form or
/// a survey.
///
/// The role's template generates these files, whichever module provides the
/// role:
/// - [serviceFile] with `FeedbackService`, the interface that the provider
///   implements;
/// - [controllerFile] with `appFeedback`, the `AppFeedbackController` of the
///   app, through which the code of the app opens the way to write, and
///   `createFeedbackService()`, which only `appFeedback` and a test of the
///   provider call;
/// - in an app with the [SettingsScreenRole], [settingFile] with
///   `FeedbackSetting`, the entry "Write to us" of the settings screen, and
///   `feedbackSettingShows()`, which says whether the screen shows it.
///
/// The provider contributes its implementation of `FeedbackService` as a
/// [RoleImplementation] that is created with the app: the role has no
/// start-up phase, and its template refuses an implementation that is
/// created asynchronously. So the role adds nothing to `bootstrap()`. The
/// role registers nothing in a DI container: the code of an app uses
/// `appFeedback`, a top-level variable.
///
/// The role uses the [SettingsScreenRole], to which its template gives the
/// entry, and the [LocalizationRole], in which the entry shows its title,
/// [settingTitle]. The entry reads `appFeedback.available` and nothing else,
/// so the screen shows it whatever the user did with the review dialog of a
/// store. The template writes the section [readmeHeading] of the README of
/// the app from its render hook, since the section tells where the app lets
/// the user write, which depends on the settings screen, and the note of the
/// role in the guide for coding agents, with a note of the entry in an app
/// with a settings screen.
///
/// ## What the template guarantees
///
/// `appFeedback` is the same code in every app, so a second provider keeps
/// all of this by construction:
/// - `open(context)` completes with `false` without asking the provider while
///   `available` is `false` or the context is no longer mounted;
/// - the calls go one at a time: a call while another is on its way
///   completes with `false` at once;
/// - `open(context)` never throws. An error of the provider goes to
///   `FlutterError.reportError` once and counts as `false`. An `available` of
///   the provider that throws counts as `false`, and a debug build prints its
///   error once;
/// - `open(context)` gives the provider the context that it got, and
///   completes with the answer of the provider.
///
/// ## What a provider keeps to
///
/// The contract of `FeedbackService` is in [serviceFile]:
/// - `available` reads at once, never throws and does not change while the
///   app runs;
/// - `open(context)` shows its way over the screen of the context and
///   completes with `true` once that way opened, without waiting for the user
///   to send anything;
/// - when its way cannot open, the provider shows a way of its own to reach
///   the developer, if it has one, such as the address to copy, and completes
///   with `false`;
/// - it asks the platform nothing before it opens, and learns from the answer
///   of the open itself: a platform may answer no while the way is there, as
///   Android 11 and later answer an app whose manifest names no other app;
/// - what reaches the developer has the name, the version, the build number
///   and the flavor of the app, and its platform.
///
/// Only a running app shows whether a provider keeps to this. The test of the
/// role sees what the app sees: what `available` says and whether the way
/// opened. What reaches the developer goes through the tool of the provider,
/// such as the mail app, which no test of the role sees, so it is no
/// guarantee of the role but a duty of each provider, which the test of the
/// module of the provider checks.
///
/// ## Rules
///
/// The structural rules of the role read the index of each Dart file of an
/// app, so they see what a file itself imports and calls:
/// - `feedback.factory_calls`: no file of a module, and none of the template
///   of another role, calls `createFeedbackService()`, and of such files only
///   those of the provider's implementation, the files of its class and of
///   its function, import or export [serviceFile];
/// - `feedback.use_calls`: no file of a module, and none of the template of
///   another role, calls `appFeedback.use()`, which is for tests;
/// - `feedback.implementation_factories`: the function of the implementation
///   is in its file and takes no arguments.
///
/// They do not see a `part` file of a library that imports [controllerFile],
/// a file that reaches it through an export of another file, or
/// `appFeedback` under another name.
///
/// ## Tests
///
/// A test gives `appFeedback.use()` a service of its own to script what a
/// provider answers, and puts back the service of the provider,
/// `createFeedbackService()`, when it ends.
///
/// The mocks of the platform side of every provider, with which the tests of
/// the apps run, keep to one convention, so that the tests of the role and of
/// the modules hold with each:
/// - the test of the module of the provider gives it what it needs, such as
///   its keys in `.env`, so `available` is `true` in the tests of every app;
/// - the device of the mocks has what the provider opens, such as a mail app;
/// - asked whether it has it, the device says no, as Android 11 and later say
///   to an app whose manifest names no other app.
final class FeedbackRole extends Role<RoleImplementation> {
  const FeedbackRole._();

  /// The path of the file with `FeedbackService`, which the provider
  /// implements.
  static const serviceFile = 'lib/core/feedback/feedback_service.dart';

  /// The path of the file with `appFeedback`, which the code of the app uses.
  static const controllerFile = 'lib/core/feedback/app_feedback.dart';

  /// The path of the file with `FeedbackSetting`, the entry of the settings
  /// screen, which only an app with the [SettingsScreenRole] has. So it is no
  /// file of the [interface] of the role: the provider of the settings screen
  /// creates the entry, and no other code names it.
  static const settingFile = 'lib/core/feedback/feedback_setting.dart';

  /// The heading of the section of the README of the app in which the
  /// template tells how the users of the app write to its developer. The
  /// section of a provider can refer to it.
  static const readmeHeading = 'Feedback';

  /// The title of the entry of the settings screen, a text of the template of
  /// the role in an app with a settings screen.
  static const settingTitle = LocalizedText(
    'settingTitle',
    en: 'Write to us',
    translations: {'uk': 'Написати нам'},
  );

  /// The implementation of `FeedbackService`, which the template renders from
  /// the provider's [RoleImplementation]; modules do not contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    feedbackRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'feedback';

  @override
  String get description => 'Feedback';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  /// The settings screen, to which the template gives the entry through which
  /// the user writes, and the languages of the app, in which that entry shows
  /// its title. The role needs no router: a provider shows its way over the
  /// screen of the context that it gets.
  @override
  Set<Role> get uses => {settingsScreenRole, localizationRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [serviceFile, controllerFile],
      );

  @override
  RoleTemplate<RoleImplementation> get template => const _FeedbackTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'feedback.factory_calls',
          description: 'No module calls createFeedbackService(), and only the '
              'files of the implementation of the provider import the file of '
              'FeedbackService: the code of the app lets the user write '
              'through appFeedback.',
          check: _checkFeedbackService,
        ),
        StructuralRule(
          id: 'feedback.use_calls',
          description: 'No module calls appFeedback.use(), which is for tests.',
          check: _checkFeedbackUse,
        ),
        StructuralRule(
          id: 'feedback.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
      ];
}

/// What the rules of the role tell the owner of a file to do instead.
const _feedbackHint =
    'Let the user write through appFeedback of ${FeedbackRole.controllerFile}.';

/// The problems with the service of the provider in [input]; see
/// [_checkServiceReach].
///
/// Code that reached the service would open the way to write around
/// `appFeedback`, which is what keeps the guarantees of the role.
List<SmfIssue> _checkFeedbackService(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkServiceReach(
      input,
      factory: 'createFeedbackService',
      service: 'FeedbackService',
      serviceFile: FeedbackRole.serviceFile,
      controllerFile: FeedbackRole.controllerFile,
      hint: _feedbackHint,
    );

/// The problems with `appFeedback.use()` in [input]: a call in a file of a
/// module or of the template of another role would change the service of
/// every other way to write of the app.
List<SmfIssue> _checkFeedbackUse(
  StructuralRuleInput<RoleImplementation> input,
) =>
    [
      for (final MapEntry(key: path, value: index) in input.files.entries)
        if (_usesController(input.owners[path], input.roleInput.role) &&
            invokesOn(index, 'appFeedback', 'use', FeedbackRole.controllerFile))
          SmfIssue(
            '$path calls appFeedback.use(), which only a test calls.',
            hint: _feedbackHint,
            origin: input.owners[path],
            path: path,
          ),
    ];

/// The section of the role in the README of an app: how the code of the app
/// lets a user write, what the answers of `appFeedback` mean, where the app
/// offers it, which depends on [settings], what each provider sends, the
/// review dialog of the stores, the Support URL of App Store Connect and the
/// privacy of what a user writes. It holds with every provider and names
/// none.
String _feedbackReadme({required bool settings}) => '''
`appFeedback` in `${FeedbackRole.controllerFile}` lets the users of the app write to you. Call `appFeedback.open(context)` from a button, with a `BuildContext` below the root of the app:

```dart
TextButton(
  onPressed: () => appFeedback.open(context),
  child: const Text('Write to us'),
)
```

It opens the way to write of the provider of feedback, such as a new mail in the mail app, a form or a survey, and completes with `true` once that way opened, without waiting for the user to send anything. It completes with `false` when the way could not open, after the provider showed the user another way to reach you if it has one, such as the address to copy. It never throws: an error of the provider goes to the handler of the errors of Flutter, such as that of a crash reporter, and counts as `false`. A call while another is on its way does nothing and completes with `false`.

`appFeedback.available` tells whether the provider has what it needs, such as your address, and does not change while the app runs. While it is `false`, `open` does nothing, so hide a button of your own then.

${settings ? 'The row "Write to us" of the settings screen, `FeedbackSetting` in `${FeedbackRole.settingFile}`, calls it, and the screen shows the row only while `appFeedback.available` holds.' : 'This app has no settings screen, so call it from a button of your own, such as on a screen of help.'}

Each provider adds to what reaches you the name, the version, the build number and the flavor of the app and its platform, so that you know what the user ran. The section of the provider tells what it sends and how.

The way to write is there whatever the user did with the review dialog of a store. Google Play forbids any question before or around that dialog, so never send the happy users to the store and the unhappy ones here.

A way to write inside the app does not replace the Support URL that App Store Connect asks of every app, a page where its users reach you (App Store Review Guideline 1.5).

What a user writes leaves the device through the provider. A provider that sends it through a service of its own, such as a form, collects data: declare it in App Privacy and in Data safety, as the section of the provider says what it sends. Both stores also require a link to a privacy policy in the listing of the app and inside the app.
''';

/// What the role adds to its note in an app with a settings screen: the
/// entry through which the user writes, which only such an app has.
const String _feedbackSettingNote = '''
- `FeedbackSetting` in `${FeedbackRole.settingFile}` is the row "Write to us" of the settings screen. It shows only while `appFeedback.available` holds, through `feedbackSettingShows()`, and reads nothing else.
''';

/// The template of the [FeedbackRole]: the files of the role, the
/// implementation of the provider, the entry of the settings screen with its
/// text, the section of the role in the README of the app and its notes for
/// coding agents.
final class _FeedbackTemplate extends _ServiceTemplate<RoleImplementation> {
  const _FeedbackTemplate();

  @override
  Role<RoleImplementation> get role => feedbackRole;

  @override
  MasonBundle get bundle => feedbackRoleBundle;

  @override
  String get file => FeedbackRole.controllerFile;

  @override
  String get service => 'FeedbackService';

  @override
  String get factory => 'createFeedbackService';

  /// No app has this function: [validate] refuses an implementation that is
  /// created asynchronously.
  @override
  String get initFunction => 'initFeedback';

  @override
  String get variable => '_feedbackService';

  @override
  SocketRef<CodeSocket> get implementations => FeedbackRole.implementations;

  /// The note of the role in the guide for coding agents: how code lets a
  /// user write and what the answers mean, how a button follows whether the
  /// provider can open its way, the review dialog of the stores, and what a
  /// provider implements.
  @override
  String get agentNote => '''
- `appFeedback` in `$file` lets a user write to the developer: call `appFeedback.open(context)` from a button, with a `BuildContext` below the root of the app. It opens the way of the provider, such as the mail app with a new mail, a form or a survey. It completes with `true` once that opened, without waiting for the user, or with `false`. It never throws, and a call while another is on its way does nothing.
- `appFeedback.available` tells whether the provider has what it needs, and does not change while the app runs: hide your own button while it is `false`.
- Never ask anything before or around the review dialog of a store, and never make a way to write depend on whether the user rated the app.
- A new provider implements `$service` of `${FeedbackRole.serviceFile}`, and only the files of its implementation import it. The code of the app calls neither `$factory()` nor `appFeedback.use()`, which is for tests.
''';

  /// The bricks, the entry with its text and the notes of the role. The role
  /// registers nothing in a DI container: the code of an app uses
  /// `appFeedback`, not the service of the provider.
  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(agentNote),
        ),
        // Only an app with a settings screen gets the entry and its text.
        BrickContribution(
          feedbackRoleSettingBundle,
          when: const {settingsScreenRole},
        ),
        settingsScreenRole.data(
          const SettingsEntry(
            widget: TypeRef('FeedbackSetting', import: _settingImport),
            showIf: FunctionRef('feedbackSettingShows', import: _settingImport),
          ),
        ),
        localizationRole.data(
          const TextsData([FeedbackRole.settingTitle]),
          when: const {settingsScreenRole},
        ),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(_feedbackSettingNote),
          when: const {settingsScreenRole},
        ),
      ];

  /// Also refuses an implementation that is created asynchronously: the role
  /// has no start-up phase, and `appFeedback` works from the first call.
  @override
  List<SmfIssue> validate(RoleHookInput<RoleImplementation> input) => [
        ...super.validate(input),
        for (final (:implementation, :origin) in _implementationsIn(input))
          if (implementation.isAsync)
            SmfIssue(
              'The ${implementation.factory.name} of the $role starts '
              'asynchronously, but the role has no start-up phase.',
              hint: 'Create the service with the app, and let it open what it '
                  'needs at its first open.',
              origin: origin,
            ),
      ];

  /// The implementation, the section of the role in the README of the app,
  /// and the code that reads the title of the entry of the settings screen.
  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) => RoleOutput(
        fragments: [
          ...super.render(input).fragments,
          AppEntryRole.readmeSections.entry(
            FeedbackRole.readmeHeading,
            _feedbackReadme(settings: input.has(settingsScreenRole)),
          ),
        ],
        vars: {
          'text_title': localizationRole.expressionOf(
            input,
            const RoleTemplateOrigin(feedbackRole),
            FeedbackRole.settingTitle,
          ),
        },
      );

  /// The role adds nothing to `bootstrap()`.
  @override
  String? bootstrap({required bool hasAsync}) => null;
}

/// The file of the entry of the settings screen, as code imports it.
const _settingImport = ImportRef.app('core/feedback/feedback_setting.dart');
