import 'package:smf_apple_sign_in/smf_apple_sign_in.dart';
import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_dio/smf_dio.dart';
import 'package:smf_event_bus/smf_event_bus.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_firebase_messaging/smf_firebase_messaging.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_github_actions/smf_github_actions.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_google_sign_in/smf_google_sign_in.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_launcher_icons/smf_launcher_icons.dart';
import 'package:smf_local_notifications/smf_local_notifications.dart';
import 'package:smf_material_theme/smf_material_theme.dart';
import 'package:smf_native_splash/smf_native_splash.dart';
import 'package:smf_onboarding/smf_onboarding.dart';
import 'package:smf_paywall/smf_paywall.dart';
import 'package:smf_revenuecat/smf_revenuecat.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:smf_sign_in/smf_sign_in.dart';

/// The modules that `smf create` offers.
///
/// A run in a terminal asks first which of the modules without a role the
/// app has, one question for each kind, such as its features, and then which
/// module provides each role: the roles in the order they first appear in
/// this list, each after the roles whose providers require it, such as the
/// layout before the router. Each question lists its modules in the order of
/// this list, and an answer keeps that order, and Enter takes the first
/// provider of a role that takes one. So this list goes from what the user of
/// the app sees to what gets the app released, as a developer thinks about an
/// app, and `test/questions_test.dart` pins the questions it makes.
///
/// A role first appears with the first module that provides, requires or
/// uses it, and brings with it the roles that it requires or uses. The app
/// entry brings the router, the layout, the localization, the preferences, the
/// DI container and the settings screen that way, and the preferences come
/// after every role that requires them, the push messages and the notifications
/// too, wherever their modules stand. So the place of a module here decides
/// only the question of a role that none of them brings, as `firebase_auth`
/// before `dio` keeps the authentication before the REST API that uses it.
///
/// The apps with every module list their modules in this order too, and their
/// tabs, the entries of their settings screen and the services of their DI
/// container follow it: `home` comes before `settings`, `material_theme`
/// before `gen_l10n`, and `event_bus` before `shared_preferences`. The
/// snapshots of those apps show what a move here changes.
const List<SmfModule> smfModules = [
  // The app, its navigation and its screens.
  FlutterCoreModule(),
  GoRouterModule(),
  BottomTabsModule(),
  HomeModule(),
  SettingsModule(),
  OnboardingModule(),
  // Its look and its languages.
  MaterialThemeModule(),
  GenL10nModule(),
  // What is under the hood.
  LocalNotificationsModule(),
  GetItModule(),
  BlocModule(),
  RiverpodModule(),
  EventBusModule(),
  SharedPreferencesModule(),
  // What it talks to.
  FirebaseCoreModule(),
  FirebaseMessagingModule(),
  FirebaseAuthModule(),
  GoogleSignInModule(),
  AppleSignInModule(),
  SignInModule(),
  DioModule(),
  RevenueCatModule(),
  PaywallModule(),
  DartDefineModule(),
  // What tells how it runs.
  FirebaseCrashlyticsModule(),
  FirebaseAnalyticsModule(),
  // What gets it released.
  LauncherIconsModule(),
  NativeSplashModule(),
  GithubActionsModule(),
];
