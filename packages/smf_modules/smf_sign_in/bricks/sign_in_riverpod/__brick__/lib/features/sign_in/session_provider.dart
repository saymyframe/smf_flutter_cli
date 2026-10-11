import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_session.dart';

/// The session of the app, through which the providers of the sign-in sign
/// in and up. No other file of the screens names the session: a test
/// overrides this provider with a session of its own.
final appSessionProvider = Provider<AppSessionController>((ref) => appSession);
