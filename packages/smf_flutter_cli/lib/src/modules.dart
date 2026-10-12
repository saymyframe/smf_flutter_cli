import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_bottom_tabs/smf_bottom_tabs.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_event_bus/smf_event_bus.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_auth/smf_firebase_auth.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_material_theme/smf_material_theme.dart';
import 'package:smf_onboarding/smf_onboarding.dart';
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
/// this list, and an answer keeps that order.
///
/// A role first appears with the first module that provides, requires or
/// uses it. So a module that requires or uses a role comes after the
/// providers of that role, which keeps the questions of the roles in the
/// order of their providers. `onboarding`, for example, comes after
/// `shared_preferences`, whose role it requires, and after `gen_l10n`,
/// whose role it uses.
const List<SmfModule> smfModules = [
  FlutterCoreModule(),
  GoRouterModule(),
  BlocModule(),
  RiverpodModule(),
  HomeModule(),
  SettingsModule(),
  BottomTabsModule(),
  MaterialThemeModule(),
  GenL10nModule(),
  GetItModule(),
  EventBusModule(),
  SharedPreferencesModule(),
  OnboardingModule(),
  FirebaseCoreModule(),
  FirebaseCrashlyticsModule(),
  FirebaseAnalyticsModule(),
  FirebaseAuthModule(),
  SignInModule(),
];
