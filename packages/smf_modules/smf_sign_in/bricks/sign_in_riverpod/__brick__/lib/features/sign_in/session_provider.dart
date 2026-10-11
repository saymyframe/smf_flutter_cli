import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';

/// The session of the app, through which the providers of the sign-in sign
/// in, up and out. No other file of the screens names the session: a test
/// overrides this provider with a session of its own.
final appSessionProvider = Provider<AppSessionController>((ref) => appSession);

/// Who uses the app, for the widgets of the app: the session of the app, an
/// `AppSession`, which a widget reads with `ref.watch(sessionProvider)` and
/// which rebuilds the widget when the user changes.
final sessionProvider = NotifierProvider<SessionNotifier, AppSession>(
  SessionNotifier.new,
);

/// Follows the session of the app.
class SessionNotifier extends Notifier<AppSession> {
  @override
  AppSession build() {
    final session = ref.watch(appSessionProvider);
    void follow() => state = session.value;
    session.addListener(follow);
    ref.onDispose(() => session.removeListener(follow));
    return session.value;
  }
}
