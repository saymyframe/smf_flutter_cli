part of '../services.dart';

/// The notifications role; see [NotificationsRole].
const notificationsRole = NotificationsRole._();

/// The role of the notifications of the app: the permission to show them,
/// the notifications that the app shows now or at a time to come, and the
/// taps of the user on them.
///
/// The role's template generates these files, whichever module provides
/// the role:
/// - [serviceFile] with `NotificationsService`, the interface that the
///   provider implements, `AppNotification` and `NotificationTap`, and the
///   constants `notificationChannelId`, `notificationChannelName` and
///   `notificationIcon`, with which the provider shows a notification;
/// - [controllerFile] with `appNotifications`, the `NotificationsController`
///   of the app, `NotificationPermission` and `notificationOwnerKey`. The
///   file exports `AppNotification` and `NotificationTap`, so the code of
///   the app imports this file alone;
/// - [androidIconFile], the drawable [androidIcon] that a notification
///   shows as its small icon on Android, a bell that the developer of the
///   app replaces, and [androidKeepFile], which keeps that drawable in a
///   release build: the shrinking of the resources of such a build removes
///   a drawable that code names by its name alone, and the provider, as any
///   other code that shows a notification on Android, names it so.
///
/// The provider contributes its implementation of `NotificationsService` as
/// a [RoleImplementation], created with the app or asynchronously. The
/// role registers nothing in a DI container: the code of an app uses
/// `appNotifications`, a top-level variable, and no module or template of
/// another role reaches the service of the provider.
///
/// The template also writes the section [readmeHeading] of the README of
/// the app, from its render hook, since the section tells where the app
/// asks for the permission, which depends on the roles of the app. In the
/// guide for coding agents of the app, the template writes the note of the
/// role under its description, a note of the entry of the settings screen
/// and one of the step of the onboarding in an app with those roles, and in
/// an app with neither a note that nothing asks for the permission yet.
///
/// ## The controller
///
/// `appNotifications.show()` shows a notification now, and
/// `appNotifications.schedule()` at about a time to come. `cancel()` and
/// `cancelAll()` remove notifications, and `scheduled()` lists those that
/// are scheduled and not shown yet. A notification is an `AppNotification`
/// with an id, a title, a body and data. Its id is a 32-bit integer, which
/// the platforms keep, and a notification with the id of one that is shown
/// or scheduled takes its place, a scheduled one when it shows. `show()`
/// and `schedule()` fail with an `ArgumentError` for an id that the app does
/// not take, and `schedule()` for a time that is not in the future, before
/// they reach the provider. `scheduled()` and `cancelAll()` take the
/// notifications of an owner too.
/// What the provider throws reaches the code that called. An error of the
/// provider when the user comes back to the app, or one that its taps send,
/// has no caller, so it reaches the handlers of the uncaught errors of the
/// app, and the controller goes on. A call made before the first start of
/// the controller waits for it, and fails with its error if it fails.
///
/// `appNotifications.permission` is a `ValueListenable` of the
/// `NotificationPermission` of the app:
/// - `granted` while the service says that the app may show notifications;
/// - otherwise `denied` once the app asked, which it remembers in the
///   preferences under [askedKey], and `notAsked` before that. On Android
///   13 and later, an app that may not show notifications looks the same
///   whether it asked or not, so the role keeps the key itself, and requires
///   the [PreferencesRole] for it.
///
/// The controller asks the service again when it starts, after each
/// request, and each time the user comes back to the app, as after a change
/// in the settings of the system. `appNotifications.request()` asks the
/// user, unless the app may show notifications already: it calls the
/// service, which shows the question of the system, or opens its settings
/// where the platform has no question, then asks the service again whether
/// the app may show them, then saves [askedKey]. A request while another is
/// on its way completes with that one, since Android shows one question at
/// a time. After `denied` the system may not ask again: iOS asks only once,
/// and Android stops after a second no. `appNotifications.openSettings()`
/// opens the settings of the system for the notifications of the app, where
/// the user turns them on. The role has no state of a permission that is
/// granted for a while, or of one that the system will not ask for again:
/// the answer to both is the settings of the system.
///
/// `restoreNotifications`, the restorer that the template puts into
/// [PreferencesRole.restorers], takes [askedKey] from the preferences, so
/// `appNotifications.permission` is right whichever of the preferences and
/// the notifications starts first in `bootstrap()`.
///
/// `appNotifications.taps` tells of each tap on a notification of the app
/// while the app runs, with the data of the notification, and
/// `appNotifications.launchTap` is the tap that launched the app, known
/// once `bootstrap()` is over. The code of the app reads both once its first
/// screen is shown, and navigates as the rest of the app does. A
/// notification runs no code of the app when it shows.
///
/// ## Notifications with an owner
///
/// A notification may have an owner, code that shows it and handles its
/// taps itself, such as the template of a role that shows the push messages
/// that come while the app is in the foreground. Such a notification names
/// its owner, such as the id of that role, under [ownerKey] in its data,
/// and has a negative id, so that it never takes the place of a
/// notification of the app. `appNotifications.show()` and `schedule()`
/// refuse a negative id without an owner, and an owner with an id that is
/// not negative.
///
/// `appNotifications.taps` and `launchTap` leave out the taps on a
/// notification with an owner, and those with a negative id, as of a
/// notification of an owner whose data the provider could not read.
/// `appNotifications.tapsOf(owner)` and
/// `launchTapOf(owner)` give them to their owner, so the code of the app
/// sees each tap once, from the owner or from the role.
///
/// ## The settings screen and the onboarding
///
/// In an app with the [SettingsScreenRole], the template generates
/// [settingFile] with `NotificationsSetting`, an entry of the settings
/// screen. It shows whether the app may show notifications, as the texts
/// [settingOn] and [settingOff] after the title [settingTitle]. A tap asks
/// for the permission while it is `notAsked`, and opens the settings of the
/// system after that. The entry does not wait for what a tap starts, so an
/// error of the request, such as preferences that fail to save that the app
/// asked, reaches the handlers of the uncaught errors of the app, as with
/// the entries of the theme mode and of the language.
///
/// In an app with the [OnboardingScreenRole], the template gives the
/// onboarding the step [stepName], of the stage
/// [OnboardingStage.permission], whose functions are in [stepFile]: the
/// onboarding shows it while the permission is `notAsked`, and its action
/// asks for the permission. Its texts are [stepTitle], [stepText],
/// [stepAction] and [stepLater]. Skipping the onboarding skips the step.
///
/// In an app with neither, nothing asks for the permission until the code
/// of the app calls `appNotifications.request()`, and the README of the app
/// and the guide for coding agents say so.
///
/// The texts of the entry and of the step are texts of the template, in
/// English and in Ukrainian, which it gives the [LocalizationRole] only in
/// an app with the role that shows them.
///
/// ## What a provider keeps to
///
/// The contract of `NotificationsService` is in [serviceFile]. In short:
/// - the function of the implementation asks the user nothing, and may be
///   called again: the service that it returns then has what the device
///   kept, such as the notifications that are scheduled;
/// - `show` and `schedule` complete whether the app may show notifications
///   or not;
/// - every notification goes to the channel [defaultChannel], whose name is
///   the name of the app, with a high importance and, on Android, the small
///   icon [androidIcon]. It shows also while the app is in the foreground;
/// - `schedule` is inexact: it shows a notification at about its time, not
///   to the minute, which needs no permission for exact alarms. The
///   notification shows also when the app is closed then, and after a
///   restart of the device;
/// - a notification with the id of one that is shown or scheduled takes its
///   place: `show` cancels the scheduled notification of its id, if there
///   is one, so that it does not show later, and a notification scheduled
///   with the id of one that is shown takes its place when it shows.
///   `cancel` removes the notification of its id, shown or scheduled;
/// - `taps` and `launchTap` have the data that the notification had;
/// - `request` completes once the user answered, also with a no, and never
///   throws for it. Where the platform has no question to show and the app
///   may not show notifications, as on Android before 13, it opens the
///   settings of the system for the notifications of the app instead, as
///   `openSettings` does, so the user needs only one request to turn them
///   on.
///
/// Only a running app shows whether a provider keeps to it.
///
/// ## Rules
///
/// The structural rules of the role read the index of each Dart file of an
/// app, so they see what a file itself imports and calls:
/// - `notifications.factory_calls`: no file of a module, and none of the
///   template of another role, calls `createNotificationsService()`, and of
///   such files only those of the provider's implementation, the files of
///   its class and of its function, import or export [serviceFile];
/// - `notifications.start_calls`: only the file of `bootstrap()` calls
///   `initNotifications()`, and no file of a module or of the template of
///   another role calls `appNotifications.start()`, which
///   `initNotifications()` and tests call;
/// - `notifications.implementation_factories`: the function of the
///   implementation is in its file and takes no arguments.
///
/// They do not see a `part` file of a library that imports
/// [controllerFile], a file that reaches [controllerFile] through an export
/// of another file of the app, or `appNotifications` under another name.
///
/// ## Tests
///
/// A call of `appNotifications` made before the first
/// `initNotifications()` waits for it in the zone it was made in. Code may
/// have read `appNotifications` first anywhere, even in the body of an
/// earlier widget test. A test gives `appNotifications.start()`
/// a service of its own to script what a provider answers, and runs
/// `initNotifications()` again to see what the next launch of the app
/// finds. A test that brings the user back to the app may go through any
/// state of the lifecycle: the controller looks only at
/// `AppLifecycleState.resumed`.
///
/// The mocks of the platform side of a provider, with which the tests of
/// the apps run, start as on a first launch: the app may not show
/// notifications and has not asked, so the onboarding shows its step. A
/// request grants the permission, so that a test that asks goes on with an
/// app that may show notifications, and `openSettings` completes. The mocks
/// of no module ask for the permission before the tests of the app start,
/// since the test of the role, and the tests of the step of the onboarding,
/// expect `notAsked` right after `bootstrap()`.
final class NotificationsRole extends Role<RoleImplementation> {
  const NotificationsRole._();

  /// The path of the file with `NotificationsService`, which the provider
  /// implements.
  static const serviceFile =
      'lib/core/notifications/notifications_service.dart';

  /// The path of the file with `appNotifications`, which the code of the app
  /// uses.
  static const controllerFile = 'lib/core/notifications/app_notifications.dart';

  /// The path of the small icon of a notification on Android, the drawable
  /// [androidIcon].
  static const androidIconFile =
      'android/app/src/main/res/drawable/ic_notification.xml';

  /// The path of the file that keeps [androidIconFile] in a release build.
  static const androidKeepFile =
      'android/app/src/main/res/raw/notifications_keep.xml';

  /// The path of the file with `NotificationsSetting`, the entry of the
  /// settings screen, which only an app with the [SettingsScreenRole] has.
  /// So it is no file of the [interface] of the role: the provider of the
  /// settings screen creates the entry, and no other code names it.
  static const settingFile =
      'lib/core/notifications/notifications_setting.dart';

  /// The path of the file with the functions of the step [stepName] of the
  /// onboarding, which only an app with the [OnboardingScreenRole] has.
  static const stepFile = 'lib/core/notifications/notifications_step.dart';

  /// The heading of the section of the README of the app in which the
  /// template tells how the app shows notifications and where it asks for
  /// the permission. The section of a provider can refer to it.
  static const readmeHeading = 'Notifications';

  /// The key of the preferences of the app under which the app remembers
  /// that it asked for the permission to show notifications, as a `bool`.
  /// The file of the role keeps the key to itself, so a test of an app
  /// takes it from here.
  static const askedKey = 'notifications.asked';

  /// The key under which a notification with an owner names its owner in
  /// its data; see [NotificationsRole]. The file of the role has it as
  /// `notificationOwnerKey`.
  static const ownerKey = 'notifications.owner';

  /// The id of the channel of Android in which the app shows its
  /// notifications, which every provider creates, such as for the meta-data
  /// of a module that has the system show a notification in it. The file of
  /// the service has it as `notificationChannelId`.
  static const defaultChannel = 'default';

  /// The name of the drawable of Android that a notification shows as its
  /// small icon, `@drawable/ic_notification`, which the template generates
  /// in [androidIconFile]. The file of the service has it as
  /// `notificationIcon`.
  static const androidIcon = 'ic_notification';

  /// The name of the step of the onboarding that asks for the permission,
  /// as [OnboardingStep.name] has it.
  static const stepName = 'permission';

  /// The title of the entry of the settings screen, a text of the template
  /// of the role in an app with a settings screen.
  static const settingTitle = LocalizedText(
    'settingTitle',
    en: 'Notifications',
    translations: {'uk': 'Сповіщення'},
  );

  /// What the entry of the settings screen shows while the app may show
  /// notifications.
  static const settingOn = LocalizedText(
    'settingOn',
    en: 'On',
    translations: {'uk': 'Увімкнено'},
  );

  /// What the entry of the settings screen shows while the app may not show
  /// notifications.
  static const settingOff = LocalizedText(
    'settingOff',
    en: 'Off',
    translations: {'uk': 'Вимкнено'},
  );

  /// The title of the step of the onboarding, a text of the template of the
  /// role in an app with an onboarding screen.
  static const stepTitle = LocalizedText(
    'stepTitle',
    en: 'Turn on notifications',
    translations: {'uk': 'Увімкніть сповіщення'},
  );

  /// The text of the step of the onboarding, below its title.
  static const stepText = LocalizedText(
    'stepText',
    en: 'The app tells you when something needs your attention, even when '
        'it is closed.',
    translations: {
      'uk': 'Застосунок повідомить, коли щось потребує вашої уваги, навіть '
          'коли він закритий.',
    },
  );

  /// The label of the button of the step that asks for the permission.
  static const stepAction = LocalizedText(
    'stepAction',
    en: 'Allow notifications',
    translations: {'uk': 'Дозволити сповіщення'},
  );

  /// The label of the button of the step that goes on without asking.
  static const stepLater = LocalizedText(
    'stepLater',
    en: 'Not now',
    translations: {'uk': 'Не зараз'},
  );

  /// The implementation of `NotificationsService`, which the template
  /// renders from the provider's [RoleImplementation]; modules do not
  /// contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    notificationsRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'notifications';

  @override
  String get description => 'Notifications';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  /// The preferences, which remember that the app asked for the permission.
  @override
  Set<Role> get requires => {preferencesRole};

  /// The settings screen and the onboarding, to which the template gives an
  /// entry and a step that ask for the permission, and the languages of the
  /// app, in which they show their texts.
  @override
  Set<Role> get uses =>
      {settingsScreenRole, onboardingScreenRole, localizationRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [serviceFile, controllerFile, androidIconFile, androidKeepFile],
      );

  @override
  RoleTemplate<RoleImplementation> get template =>
      const _NotificationsTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'notifications.factory_calls',
          description: 'No module calls createNotificationsService(), and '
              'only the files of the implementation of the provider import '
              'the file of NotificationsService: the code of the app shows '
              'notifications through appNotifications.',
          check: _checkNotificationsService,
        ),
        StructuralRule(
          id: 'notifications.start_calls',
          description: 'Only bootstrap() calls initNotifications(), and no '
              'module calls appNotifications.start().',
          check: _checkNotificationsStart,
        ),
        StructuralRule(
          id: 'notifications.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
      ];
}

/// The problems with the service of the provider in [input]; see
/// [_checkServiceReach].
List<SmfIssue> _checkNotificationsService(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkServiceReach(
      input,
      factory: 'createNotificationsService',
      service: 'NotificationsService',
      serviceFile: NotificationsRole.serviceFile,
      controllerFile: NotificationsRole.controllerFile,
      hint: 'Show notifications and ask for the permission through '
          'appNotifications of ${NotificationsRole.controllerFile}, which '
          'also exports AppNotification and NotificationTap.',
    );

/// The problems with the start of `appNotifications` in [input]; see
/// [_checkControllerStart].
List<SmfIssue> _checkNotificationsStart(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkControllerStart(
      input,
      init: 'initNotifications',
      controller: 'appNotifications',
      controllerFile: NotificationsRole.controllerFile,
      hint: 'The role starts the notifications in bootstrap(), before the '
          'first frame. Read the permission and the taps from '
          'appNotifications.',
    );

/// The texts of the entry of the settings screen, each with the variable
/// of its brick that reads it.
const Map<String, LocalizedText> _settingTexts = {
  'text_title': NotificationsRole.settingTitle,
  'text_on': NotificationsRole.settingOn,
  'text_off': NotificationsRole.settingOff,
};

/// The file of the functions of the step of the onboarding, as code
/// imports it.
const _stepImport = ImportRef.app('core/notifications/notifications_step.dart');

/// The step of the onboarding that asks for the permission.
const _step = OnboardingStep(
  name: NotificationsRole.stepName,
  stage: OnboardingStage.permission,
  icon: Fragment(
    'Icons.notifications_active_outlined',
    imports: [ImportRef('package:flutter/material.dart')],
  ),
  title: NotificationsRole.stepTitle,
  text: NotificationsRole.stepText,
  action: NotificationsRole.stepAction,
  later: NotificationsRole.stepLater,
  run: FunctionRef('allowNotifications', import: _stepImport),
  showIf: FunctionRef('notificationsStepShows', import: _stepImport),
);

/// The name of [appName], a name in snake_case, as a title: each of its
/// words with a capital letter, such as `My App` for `my_app`, as the app
/// entry names the app on the screens of the system.
String _titleOf(String appName) => [
      for (final word in appName.split('_'))
        if (word.isNotEmpty) word[0].toUpperCase() + word.substring(1),
    ].join(' ');

/// Where the app of the README section asks for the permission, by the
/// roles that it has: the onboarding, the entry of the settings screen,
/// both, or neither.
String _whereAsked({required bool settings, required bool onboarding}) {
  const step = 'The onboarding asks on a page of its own, with the functions '
      'of `${NotificationsRole.stepFile}`. A user who skips the onboarding '
      'does not see that page.';
  const entry = 'The entry `NotificationsSetting` of the settings screen, in '
      '`${NotificationsRole.settingFile}`, shows whether the app may show '
      'notifications. A tap asks while the app has not asked, and opens the '
      'settings of the system after that.';
  return switch ((settings, onboarding)) {
    (true, true) => '$step $entry',
    (false, true) => step,
    (true, false) => entry,
    (false, false) => 'Nothing in this app asks yet. Call '
        '`appNotifications.request()` where the user turns on something '
        'that notifies, so that the question of the system explains itself.',
  };
}

/// The section of the role in the README of an app: how the app shows
/// notifications and the taps on them, the permission and where the app
/// asks for it, which depends on whether it has a settings screen and an
/// onboarding, and the small icon of Android. It holds with every provider
/// and names none.
String _notificationsReadme({
  required bool settings,
  required bool onboarding,
}) =>
    '''
The app shows notifications through `appNotifications` in `${NotificationsRole.controllerFile}`. `show()` shows one now and `schedule()` at a time to come, `cancel()` and `cancelAll()` remove them, and `scheduled()` lists those still to come. A scheduled notification shows at about its time, not to the minute, even if the app is closed by then, and after the device restarts. A tap on a notification reaches `appNotifications.taps` with the `data` of the notification, and `appNotifications.launchTap` is the tap that launched the app.

The app needs the permission of the user to show notifications. `appNotifications.permission` is `granted`, `denied` once the user said no or turned them off, or `notAsked`, and `appNotifications.request()` asks. Where the system has no question to show, as on Android before 13, the request opens the settings of the system for the notifications of the app instead. ${_whereAsked(settings: settings, onboarding: onboarding)} After `denied` the system may not ask again: iOS asks only once, and Android stops asking after a second no. `appNotifications.openSettings()` opens the settings of the system, where the user turns the notifications on.

On Android a notification shows `${NotificationsRole.androidIconFile}` as its small icon. Replace the bell there with the icon of the app, a shape on a transparent background, and keep the name of the file: `${NotificationsRole.androidKeepFile}` keeps the icon in a release build. In the settings of the system, the channel of the notifications has the name of the app.
''';

/// What the role adds to its note in an app with a settings screen: the
/// entry that asks for the permission, which only such an app has.
const String _settingAgentNote = '''
- `NotificationsSetting` in `${NotificationsRole.settingFile}`, an entry of the settings screen, shows whether the app may show notifications. A tap asks while the app has not asked, and opens the settings of the system after that.
''';

/// What the role adds to its note in an app with an onboarding: the step
/// that asks for the permission, which only such an app has, and that a
/// user may skip it.
const String _stepAgentNote = '''
- The onboarding asks for the permission on a page of its own, with the functions of `${NotificationsRole.stepFile}`. A user who skips the onboarding does not see that page, so code that needs notifications calls `appNotifications.request()` too.
''';

/// What the role adds to its note in an app with neither a settings screen
/// nor an onboarding, where nothing asks for the permission.
const String _unaskedAgentNote = '''
- Nothing in this app asks for the permission yet: call `appNotifications.request()` where the user turns on something that notifies.
''';

/// The template of the [NotificationsRole]: the files of the role, the
/// implementation of the provider and the start of the notifications in
/// `bootstrap()`, the restorer of the permission, the entry of the settings
/// screen and the step of the onboarding with their texts, the section of
/// the role in the README of the app and its notes for coding agents.
final class _NotificationsTemplate
    extends _ServiceTemplate<RoleImplementation> {
  const _NotificationsTemplate();

  @override
  Role<RoleImplementation> get role => notificationsRole;

  @override
  MasonBundle get bundle => notificationsRoleBundle;

  @override
  String get file => NotificationsRole.controllerFile;

  @override
  String get service => 'NotificationsService';

  @override
  String get factory => 'createNotificationsService';

  @override
  String get initFunction => 'initNotifications';

  @override
  String get variable => '_notificationsService';

  @override
  SocketRef<CodeSocket> get implementations =>
      NotificationsRole.implementations;

  /// The note of the role in the guide for coding agents: how the code of
  /// an app shows and schedules notifications and which ids it takes, how
  /// it asks for the permission, how it handles a tap, where the small icon
  /// of Android is, and which functions of the role are not for the code of
  /// the app.
  @override
  String get agentNote => '''
- `appNotifications` in `$file` shows the notifications of the app. `show()` shows one now, `schedule(notification, at: time)` at about that time, not to the minute, even if the app is closed by then. `cancel()` and `cancelAll()` remove them, and `scheduled()` lists those still to come, those of an owner too. A notification is an `AppNotification` with an `id`, a `title`, a `body` and `data`, and one with the id of a notification that is shown or scheduled takes its place. Give it an id from 0 up: a negative id is for a notification with an owner, which names it under `notificationOwnerKey` in its `data`, and whose taps go to `tapsOf(owner)` and `launchTapOf(owner)`.
- `appNotifications.permission` is `granted`, `denied` or `notAsked`. Ask with `appNotifications.request()` where the user turns on something that notifies, so that the question explains itself. Where the system has no question to show, as on Android before 13, the request opens its settings instead. After `denied` the system may not ask again (iOS asks only once, and Android stops after a second no), so open its settings with `appNotifications.openSettings()`. The app remembers that it asked under `${NotificationsRole.askedKey}`, so write nothing under that key.
- A tap on a notification reaches `appNotifications.taps` with the `data` of the notification, and the tap that launched the app is `appNotifications.launchTap`. Handle both once the first screen is shown, and navigate as the rest of the app does. A notification runs no code of the app when it shows.
- On Android a notification shows `${NotificationsRole.androidIconFile}` as its small icon. Change the drawing there and keep the name of the file.
- A new provider implements `$service` of `${NotificationsRole.serviceFile}`, and only the files of that implementation import it. The code of the app imports `$file`, which exports `AppNotification` and `NotificationTap`, and calls neither `$initFunction()` nor `$factory()` nor `appNotifications.start()`.
''';

  /// The bricks, the restorer, the entry and the step with their texts, and
  /// the notes of the role. The role registers nothing in a DI container:
  /// the code of an app uses `appNotifications`, not the service of the
  /// provider.
  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(agentNote),
        ),
        SocketContribution.item(
          PreferencesRole.restorers,
          Fragment('restoreNotifications', imports: [import]),
        ),
        // Only an app with a settings screen gets the entry and its texts.
        BrickContribution(
          notificationsRoleSettingBundle,
          when: const {settingsScreenRole},
        ),
        settingsScreenRole.data(
          const SettingsEntry(
            widget: TypeRef(
              'NotificationsSetting',
              import: ImportRef.app(
                'core/notifications/notifications_setting.dart',
              ),
            ),
          ),
        ),
        localizationRole.data(
          TextsData([..._settingTexts.values]),
          when: const {settingsScreenRole},
        ),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(_settingAgentNote),
          when: const {settingsScreenRole},
        ),
        // Only an app with an onboarding gets the step and its texts.
        BrickContribution(
          notificationsRoleStepBundle,
          when: const {onboardingScreenRole},
        ),
        onboardingScreenRole.data(_step),
        localizationRole.data(
          TextsData([..._step.shownTexts]),
          when: const {onboardingScreenRole},
        ),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(_stepAgentNote),
          when: const {onboardingScreenRole},
        ),
      ];

  /// The implementation, the section of the role in the README of the app,
  /// the note that nothing asks for the permission in an app with neither a
  /// settings screen nor an onboarding, and the variables of the bricks:
  /// the keys of the role, the channel and the icon, and the code that
  /// reads each text of the entry of the settings screen.
  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) {
    final settings = input.has(settingsScreenRole);
    final onboarding = input.has(onboardingScreenRole);
    return RoleOutput(
      fragments: [
        ...super.render(input).fragments,
        AppEntryRole.readmeSections.entry(
          NotificationsRole.readmeHeading,
          _notificationsReadme(settings: settings, onboarding: onboarding),
        ),
        if (!settings && !onboarding)
          AppEntryRole.agentSections.entry(
            notificationsRole.description,
            AgentNote.ofRole(_unaskedAgentNote),
          ),
      ],
      vars: {
        'asked_key': SmfNames.dartString(NotificationsRole.askedKey),
        'owner_key': SmfNames.dartString(NotificationsRole.ownerKey),
        'channel_id': SmfNames.dartString(NotificationsRole.defaultChannel),
        'channel_name': SmfNames.dartString(_titleOf(input.context.appName)),
        'icon': SmfNames.dartString(NotificationsRole.androidIcon),
        for (final MapEntry(key: variable, value: text)
            in _settingTexts.entries)
          variable: localizationRole.expressionOf(
            input,
            const RoleTemplateOrigin(notificationsRole),
            text,
          ),
      },
    );
  }

  /// `bootstrap()` always awaits `initNotifications()`, which also starts
  /// `appNotifications`, whether the implementation is created
  /// asynchronously or not.
  @override
  String bootstrap({required bool hasAsync}) => 'await $initFunction();';

  /// The service of the provider, and `initNotifications()`, which creates
  /// it with the only implementation in [all] and starts `appNotifications`
  /// with it.
  ///
  /// It may run again, so the variable is not final.
  @override
  String _single(
    List<_Prefixed> all,
    RoleHookInput<RoleImplementation> input,
  ) {
    final (:implementation, :prefix) = all.single;
    final factory = implementation.factory.codeWith(prefix);
    final create = implementation.isAsync ? 'await $factory()' : '$factory()';
    return '''
late $service $variable;

/// Creates the service of the provider of notifications and starts
/// [appNotifications] with it; `bootstrap()` awaits it before the first
/// frame, and nothing else in the app calls it.
///
/// It may run again, as a test does to see what the next launch of the app
/// finds: it creates the service anew, with what the device kept, and
/// starts [appNotifications] with it.
Future<void> $initFunction() async {
  $variable = $create;
  await appNotifications.start($variable);
}''';
  }
}
