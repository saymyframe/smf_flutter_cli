import 'app_notifications.dart';

/// Whether the onboarding shows its step that asks for the permission to
/// show notifications: while the app may not show them and has not asked.
bool notificationsStepShows() =>
    appNotifications.permission.value == NotificationPermission.notAsked;

/// Asks for the permission to show notifications: the action of the step of
/// the onboarding.
Future<void> allowNotifications() => appNotifications.request();
