import 'package:flutter/foundation.dart';

import '../../core/auth/app_session.dart';

/// Whether the user may see the app, as the gate of the sign-in asks it:
/// while the value is `false`, the router shows the sign-in in place of
/// every other screen. It is always `true` in an app that everyone may use
/// without an account; see `authMode`.
ValueListenable<bool> signInAllowsApp() => appSession.allowsApp;

/// Whether the user of an account is signed in, as the guard of the routes
/// that need an account asks it: while the value is `false`, the router
/// shows the sign-in in place of such a route.
ValueListenable<bool> signInHasAccount() => appSession.hasAccount;
