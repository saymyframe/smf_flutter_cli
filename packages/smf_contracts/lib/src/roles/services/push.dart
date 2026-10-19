part of '../services.dart';

/// The push role; see [PushRole].
const pushRole = PushRole._();

/// The role of push messages: the address of the device, to which a server
/// sends messages for the app through a provider, the messages that arrive,
/// and the taps of the user on them.
///
/// The role's template generates these files, whichever module provides
/// the role:
/// - [serviceFile] with `PushService`, the interface that the provider
///   implements, and `PushMessage`;
/// - [controllerFile] with `appPush`, the `AppPushController` of the app.
///   The file exports `PushMessage`, so the code of the app imports this
///   file alone.
///
/// The provider contributes its implementation of `PushService` as a
/// [RoleImplementation], created with the app or asynchronously. The role
/// registers nothing in a DI container: the code of an app uses `appPush`,
/// a top-level variable, and no module or template of another role reaches
/// the service of the provider.
///
/// The role requires the [NotificationsRole]: the app shows a message that
/// arrives in the foreground as a notification of the app where the
/// platform does not show it, and the permission to show messages is the
/// permission of the notifications. The role asks for no permission itself.
///
/// The template also gives the iOS app what every provider needs there,
/// since every push message reaches an iPhone through the Apple Push
/// Notification service (APNs): the entitlement [apsEnvironment] with the
/// value `development` in [AppEntryRole.iosEntitlements], with the step by
/// hand [AppEntryRole.iosAppIdStep] that it needs, and
/// [remoteNotificationMode] among the [backgroundModes] of the
/// [AppEntryRole.infoPlist]. It writes the section [readmeHeading] of the
/// README of the app, and the note of the role in the guide for coding
/// agents of the app under its description.
///
/// ## The controller
///
/// `appPush.address` is a `ValueListenable<String?>` of the address of the
/// device, `null` while the platform gives none, as on an iOS device whose
/// build is not signed for push messages. The controller asks the service
/// for it when it starts, without waiting for it, so the first frame never
/// waits for the network, and again each time the user comes back to the
/// app while it has none. It follows the new addresses that the service
/// tells of. In debug mode it prints each new address, for a message that a
/// developer sends by hand.
///
/// `appPush.messages` tells of each message that arrives while the app is
/// in the foreground. One with a title or a body that the platform does not
/// show itself (`PushService.platformShowsInForeground`) the controller
/// shows with `appNotifications.show()`, as a notification with an owner:
/// the id of the role under [NotificationsRole.ownerKey] in its data, a
/// negative id, the data of the message, and the message under
/// [messageKey]. An empty title or body counts as none, and a message with
/// a body alone shows its body as the title.
///
/// `appPush.taps` tells of each tap on a message while the app runs: those
/// that the service tells of, on the messages that the platform showed, and
/// those that `appNotifications.tapsOf()` gives the role, on the messages
/// that the controller showed. `appPush.launchMessage` is the message whose
/// tap launched the app, from the service or from
/// `appNotifications.launchTapOf()`, known once `bootstrap()` is over: the
/// template of a role comes after the roles that its role requires, so
/// `initNotifications()` comes before `initPush()` there. The notifications
/// of the app leave such taps out of `appNotifications.taps` and
/// `launchTap`, so the code of the app sees each tap once.
///
/// What the service sends on its streams with an error, an error of a
/// notification that the controller shows, one of an address that it asks
/// for, and one of the message that launched the app have no caller: they
/// reach the handlers of the uncaught errors of the app, and the controller
/// goes on. So the app starts also with a provider that fails to give the
/// message that launched it.
///
/// ## What a provider keeps to
///
/// The contract of `PushService` is in [serviceFile]. In short:
/// - the function of the implementation asks the user nothing, and may be
///   called again: the service that it returns then has the address that
///   the device kept;
/// - the provider never asks for the permission to show notifications, and
///   never keeps the notifications of the app from showing while the app is
///   in the foreground;
/// - `address` needs no permission, does not throw, and gives the same
///   address from one launch of the app to the next, unless the platform
///   gives the device another, which `addressChanges` tells of.
///   `addressChanges` also tells of the first address that the device gets
///   after `address` gave none;
/// - `messages` tells of each message in the foreground once, and a value
///   of its data that the platform gives as something other than a string
///   is its JSON;
/// - the platform shows a message with a title or a body that arrives in
///   the background or while the app is closed, on Android in the channel
///   [NotificationsRole.defaultChannel], and `taps` and `launchMessage` have
///   its taps; the tap that launched the app is not among `taps`. In the
///   foreground, the provider shows nothing of a message unless
///   `platformShowsInForeground` says that the platform or the provider
///   shows it;
/// - `launchMessage` completes without the network, and does not throw.
///
/// Only a running app shows whether a provider keeps to it.
///
/// ## Rules
///
/// The structural rules of the role read the index of each Dart file of an
/// app, so they see what a file itself imports and calls:
/// - `push.factory_calls`: no file of a module, and none of the template of
///   another role, calls `createPushService()`, and of such files only
///   those of the provider's implementation, the files of its class and of
///   its function, import or export [serviceFile];
/// - `push.start_calls`: only the file of `bootstrap()` calls `initPush()`,
///   and no file of a module or of the template of another role calls
///   `appPush.start()`, which `initPush()` and tests call;
/// - `push.implementation_factories`: the function of the implementation is
///   in its file and takes no arguments.
///
/// They do not see a `part` file of a library that imports
/// [controllerFile], a file that reaches [controllerFile] through an export
/// of another file of the app, or `appPush` under another name.
///
/// ## Tests
///
/// A test gives `appPush.start()` a service of its own to script what a
/// provider answers, and runs `initPush()` again to see what the next
/// launch of the app finds: the address is then `null` until the new
/// service gives one. A test that brings the user back to the app may go
/// through any state of the lifecycle: the controller looks only at
/// `AppLifecycleState.resumed`.
///
/// The mocks of the platform side of a provider, with which the tests of
/// the apps run, give the device an address that stays the same from one
/// launch of the app to the next, as a backend expects.
final class PushRole extends Role<RoleImplementation> {
  const PushRole._();

  /// The path of the file with `PushService`, which the provider
  /// implements.
  static const serviceFile = 'lib/core/push/push_service.dart';

  /// The path of the file with `appPush`, which the code of the app uses.
  static const controllerFile = 'lib/core/push/app_push.dart';

  /// The heading of the section of the README of the app in which the
  /// template tells how the app receives push messages. The section of a
  /// provider can refer to it.
  static const readmeHeading = 'Push messages';

  /// The entitlement of the iOS app that lets it receive push messages, for
  /// [AppEntryRole.iosEntitlements].
  static const apsEnvironment = 'aps-environment';

  /// The key of the `Info.plist` of the iOS app with the modes in which the
  /// app runs in the background.
  static const backgroundModes = 'UIBackgroundModes';

  /// The mode among the [backgroundModes] that lets iOS wake the app for a
  /// push message that arrives in the background.
  static const remoteNotificationMode = 'remote-notification';

  /// The key under which a notification that shows a message keeps the
  /// message in its data, as JSON; see [PushRole].
  static const messageKey = 'push.message';

  /// The implementation of `PushService`, which the template renders from
  /// the provider's [RoleImplementation]; modules do not contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    pushRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'push';

  @override
  String get description => 'Push messages';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  /// The notifications, through which the app shows a message that arrives
  /// in the foreground, and whose permission lets the app show messages.
  @override
  Set<Role> get requires => {notificationsRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [serviceFile, controllerFile],
      );

  @override
  RoleTemplate<RoleImplementation> get template => const _PushTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'push.factory_calls',
          description: 'No module calls createPushService(), and only the '
              'files of the implementation of the provider import the file '
              'of PushService: the code of the app receives push messages '
              'through appPush.',
          check: _checkPushService,
        ),
        StructuralRule(
          id: 'push.start_calls',
          description: 'Only bootstrap() calls initPush(), and no module '
              'calls appPush.start().',
          check: _checkPushStart,
        ),
        StructuralRule(
          id: 'push.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
      ];
}

/// The problems with the service of the provider in [input]; see
/// [_checkServiceReach].
List<SmfIssue> _checkPushService(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkServiceReach(
      input,
      factory: 'createPushService',
      service: 'PushService',
      serviceFile: PushRole.serviceFile,
      controllerFile: PushRole.controllerFile,
      hint: 'Receive push messages through appPush of '
          '${PushRole.controllerFile}, which also exports PushMessage.',
    );

/// The problems with the start of `appPush` in [input]; see
/// [_checkControllerStart].
List<SmfIssue> _checkPushStart(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkControllerStart(
      input,
      init: 'initPush',
      controller: 'appPush',
      controllerFile: PushRole.controllerFile,
      hint: 'The role starts the push messages in bootstrap(), before the '
          'first frame. Read the address, the messages and the taps from '
          'appPush.',
    );

/// The section of the role in the README of an app: the address of the
/// device and what it needs on iOS, how a message shows in the foreground
/// and in the background, the taps, and what the app does not handle. It
/// holds with every provider and names none.
const String _pushReadme = '''
The app receives push messages through `appPush` in `${PushRole.controllerFile}`.

`appPush.address` is the address of this device. The backend of the app sends its messages there. It is `null` until the platform gives one, and the app works without it. Send each new address to the backend: it may come late, and it may change. In debug mode the app prints it, so you can send this device a message by hand.

On iOS the address needs a token of the Apple Push Notification service (APNs). iOS gives one only to a build signed with the entitlement `${PushRole.apsEnvironment}`, which `${AppEntryRole.iosEntitlementsFile}` has. The iOS simulator on a Mac gets a token. One on a macOS virtual machine, such as a hosted CI runner, never does. On an iPhone, signing with the entitlement needs a team of the paid Apple Developer Program. With a free personal team, Xcode cannot sign the app: to run it on an iPhone, remove the key `${PushRole.apsEnvironment}` from `${AppEntryRole.iosEntitlementsFile}`, and the app runs there without an address. The simulator needs no change. The value `development` suits the builds that you run from Xcode. When Xcode exports the app for distribution, it takes the value of the provisioning profile (production for a distribution profile).

A message that arrives while the app is in the foreground reaches `appPush.messages`. One with a title or a body also shows as a notification, as it does in the background. Where the system does not show it, the app shows it with `appNotifications`. Either way the user has to allow the notifications of the app, as the section ${NotificationsRole.readmeHeading} tells. In the background the system shows the message, on Android in the channel of the notifications of the app.

`appPush.taps` tells of each tap on a message while the app runs, and `appPush.launchMessage` is the message whose tap launched the app. Read both once the first screen is shown, and navigate as the rest of the app does. A tap on a message does not reach `appNotifications.taps`, so the code of the app sees each tap once.

A message with data and no title or body reaches the app only while it is in the foreground. In the background, or when the app is closed, it runs no code of the app. Images in a message do not show on iOS, which needs an extension of the app for them.
''';

/// The template of the [PushRole]: the files of the role, the
/// implementation of the provider and the start of the push messages in
/// `bootstrap()`, the entitlement and the background mode of the iOS app,
/// the section of the role in the README of the app and its note for coding
/// agents.
final class _PushTemplate extends _ServiceTemplate<RoleImplementation> {
  const _PushTemplate();

  @override
  Role<RoleImplementation> get role => pushRole;

  @override
  MasonBundle get bundle => pushRoleBundle;

  @override
  String get file => PushRole.controllerFile;

  @override
  String get service => 'PushService';

  @override
  String get factory => 'createPushService';

  @override
  String get initFunction => 'initPush';

  @override
  String get variable => '_pushService';

  @override
  SocketRef<CodeSocket> get implementations => PushRole.implementations;

  /// The note of the role in the guide for coding agents: where the address
  /// of the device is and what to do with it, how a message shows in the
  /// foreground and which permission that needs, how the app handles a tap,
  /// what it does not handle, and which functions of the role are not for
  /// the code of the app.
  @override
  String get agentNote => '''
- `appPush` in `$file` receives the push messages of the app. A message is a `PushMessage` with `data`, and with an `id`, a `title` and a `body` when it has them.
- `appPush.address` is the address of this device for the backend that sends the messages. It is `null` until the platform gives one. Listen to it and send each new address to the backend: it may come late, and it may change. Never wait for it before the first frame.
- `appPush.messages` tells of each message that arrives while the app is in the foreground. A message with a title or a body also shows as a notification there, which needs the permission of the notifications of the app. `appNotifications.request()` asks for it.
- A tap on a message reaches `appPush.taps`, and the message whose tap launched the app is `appPush.launchMessage`. Handle both once the first screen is shown, and navigate as the rest of the app does. Such a tap does not reach `appNotifications.taps`.
- A message with data and no title or body reaches the app only while it is in the foreground.
- A new provider implements `$service` of `${PushRole.serviceFile}`, and only the files of that implementation import it. The code of the app imports `$file`, which exports `PushMessage`, and calls neither `$initFunction()` nor `$factory()` nor `appPush.start()`.
''';

  /// The brick, the note of the role, the section of the README, and the
  /// entitlement and the background mode of the iOS app, with the step by
  /// hand that the entitlement needs (see [AppEntryRole.iosAppIdStep]). The
  /// role registers nothing in a DI container: the code of an app uses
  /// `appPush`, not the service of the provider.
  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(agentNote),
        ),
        AppEntryRole.readmeSections.entry(PushRole.readmeHeading, _pushReadme),
        // Xcode takes the value of the provisioning profile when it exports
        // the app for distribution. Only a paid team signs the entitlement,
        // so the app lists the step by hand of its App ID with it.
        ...AppEntryRole.paidTeamEntitlement(
          PushRole.apsEnvironment,
          const PlistString('development'),
        ),
        AppEntryRole.infoPlist.entry(
          PushRole.backgroundModes,
          const PlistStringArray([PushRole.remoteNotificationMode]),
        ),
      ];

  /// The implementation, and the variables of the brick: the owner of the
  /// notifications that show messages, which is the id of the role, and the
  /// key under which they keep a message.
  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) => RoleOutput(
        fragments: super.render(input).fragments,
        vars: {
          'push_owner': SmfNames.dartString(pushRole.id),
          'message_key': SmfNames.dartString(PushRole.messageKey),
        },
      );

  /// `bootstrap()` always awaits `initPush()`, which also starts `appPush`,
  /// whether the implementation is created asynchronously or not.
  @override
  String bootstrap({required bool hasAsync}) => 'await $initFunction();';

  /// The service of the provider, and `initPush()`, which creates it with
  /// the only implementation in [all] and starts `appPush` with it.
  ///
  /// It may run again, so the variable is not final.
  @override
  String _single(List<_Prefixed> all) {
    final (:implementation, :prefix) = all.single;
    final factory = implementation.factory.codeWith(prefix);
    final create = implementation.isAsync ? 'await $factory()' : '$factory()';
    return '''
late $service $variable;

/// Creates the service of the provider of push messages and starts
/// [appPush] with it; `bootstrap()` awaits it before the first frame, after
/// the notifications of the app started, and nothing else in the app calls
/// it.
///
/// It may run again, as a test does to see what the next launch of the app
/// finds: it creates the service anew, with what the device kept, and
/// starts [appPush] with it.
Future<void> $initFunction() async {
  $variable = $create;
  await appPush.start($variable);
}''';
  }
}
