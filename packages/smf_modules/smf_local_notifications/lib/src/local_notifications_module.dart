import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_local_notifications/bundles/local_notifications_bundle.dart';
import 'package:smf_local_notifications/src/agents.dart';
import 'package:smf_local_notifications/src/readme.dart';

/// The module that shows the notifications of the app with the
/// flutter_local_notifications package, and so provides the notifications
/// role: the permission to show them, notifications now and at about a
/// time to come, and the taps of the user on them.
///
/// The template of the role generates `NotificationsService`, the interface
/// of the service of a provider, `appNotifications`, through which the code
/// of the app shows notifications, and `initNotifications()`, which
/// `bootstrap()` awaits before the first frame. This module adds
/// `flutter_local_notifications` and `timezone` to the dependencies of the
/// app and implements the service in
/// `lib/core/notifications/local_notifications_service.dart` on
/// `FlutterLocalNotificationsPlugin`, which it opens asynchronously: it sets
/// up the plugin without asking the user anything, creates the channel of
/// the app on Android and reads the tap that launched the app.
///
/// The service keeps what the role promises and the plugin does not:
/// - showing a notification cancels the scheduled one of its id, whose
///   alarm Android would keep;
/// - a request opens the settings of the system for the notifications of
///   the app where the system shows no question, as Android before 13
///   does, since the plugin then answers at once;
/// - a notification carries its data as the JSON of a map in the payload
///   of the plugin, and a tap with a payload that the app did not write has
///   none.
///
/// A scheduled notification uses an inexact alarm on Android, which needs
/// no permission, and its time goes to the plugin in UTC, so the app needs
/// no database of time zones.
///
/// In the native projects, the module turns on core library desugaring of
/// the Android app, which the package needs, declares the receivers of the
/// package that show the scheduled notifications, also after a restart of
/// the device, with the permission for the restart, and makes the app
/// delegate of iOS the delegate of the notification center before the
/// launch finishes, so that the plugin shows a notification in the
/// foreground and hears of the tap that launched the app.
///
/// The README of the app tells what the module set up in the native
/// projects, how to schedule to the minute and why the app does not, and
/// that the actions of a notification are not set up. Its guide for coding
/// agents tells which file is on the package, how to add a channel, and
/// what a test needs in place of the platform side of the package.
final class LocalNotificationsModule extends SmfModule {
  /// Creates the module.
  const LocalNotificationsModule();

  /// The id of the module.
  static const id = ModuleId('local_notifications');

  static const _file = ImportRef.app(
    'core/notifications/local_notifications_service.dart',
  );

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Notifications with flutter_local_notifications',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(notificationsRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(localNotificationsBundle),
        const PubspecContribution.hosted(
          'flutter_local_notifications',
          '^22.3.2',
        ),
        const PubspecContribution.hosted('timezone', '^0.11.0'),
        notificationsRole.data(
          const RoleImplementation.async(
            type: TypeRef('LocalNotificationsService', import: _file),
            init: FactoryRef('openLocalNotifications', import: _file),
          ),
        ),
        AppEntryRole.androidCoreLibraryDesugaring.value(desugaringVersion),
        AppEntryRole.androidManifestPermissions.key(bootPermission),
        const SocketContribution.code(
          AppEntryRole.androidManifestApplicationComponents,
          Fragment(receivers),
        ),
        const SocketContribution.code(
          AppEntryRole.iosAppDelegateLaunch,
          Fragment(delegateStatement),
        ),
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          notificationsRole.description,
          AgentNote(agentNote),
        ),
      ];
}
