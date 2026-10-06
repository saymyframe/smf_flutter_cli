import 'package:flutter/foundation.dart';

import '../../core/preferences/app_preferences.dart';

/// Whether the user has finished the onboarding of the app, which the app
/// remembers between its launches.
///
/// Until the user has, the router shows the onboarding in place of every
/// other screen: the guard of the routes of the onboarding asks
/// [onboardingCompleted]. So the app shows the onboarding exactly while it
/// is not finished, and nothing navigates to it: [OnboardingStatus.restart]
/// shows it again.
final onboardingStatus = OnboardingStatus._();

/// Keeps whether the user has finished the onboarding, tells its listeners
/// when that changes, and saves it in the preferences of the app. The app
/// has one, [onboardingStatus].
final class OnboardingStatus {
  OnboardingStatus._();

  /// The key in the preferences under which it is saved.
  static const _key = {{{completed_key}}};

  /// The preferences that remember it, once the app opened them.
  AppPreferences? _preferences;

  final ValueNotifier<bool> _completed = ValueNotifier(false);

  /// Whether the user has finished the onboarding. It notifies its
  /// listeners when that changes.
  ValueListenable<bool> get completed => _completed;

  /// Finishes the onboarding, at once, and saves that: the future completes
  /// once it is saved. Until the app opened its preferences for the first
  /// time, it changes only memory.
  ///
  /// The router leaves the onboarding as soon as this is called, so call it
  /// outside the build of a frame, such as in the handler of a tap.
  ///
  /// If the preferences fail to save it, the future completes with their
  /// error. The app has left the onboarding by then, and its next launch
  /// shows the onboarding again.
  Future<void> complete() async {
    _completed.value = true;
    await _preferences?.setBool(_key, true);
  }

  /// Starts the onboarding again, at once, and saves that: the future
  /// completes once it is saved. Call it where the user asks to see the
  /// onboarding again, such as in the handler of a tap on a row of the
  /// settings, and navigate nowhere.
  ///
  /// The router shows the onboarding as soon as this is called, in place of
  /// the screen that the user is on. Once the onboarding is finished again,
  /// the router shows that screen again. If the user was on a page pushed
  /// over another screen, it shows the screen below the pushed pages
  /// instead. An app that is closed before that shows the onboarding on its
  /// next launch.
  ///
  /// Call it outside the build of a frame, where the router cannot
  /// navigate. In a build, Flutter reports an error, and the app shows the
  /// onboarding only at its next navigation.
  ///
  /// Call it after `bootstrap()`. Until the app opened its preferences for
  /// the first time, it changes only memory, and the start-up then takes
  /// what the preferences have saved.
  ///
  /// If the preferences fail to save it, the future completes with their
  /// error, and the next launch of the app finds the onboarding finished.
  Future<void> restart() async {
    _completed.value = false;
    await _preferences?.setBool(_key, false);
  }

  /// Takes what [preferences] have saved, and keeps the current value when
  /// they have nothing saved. It keeps [preferences] for [complete] and
  /// [restart].
  void _restore(AppPreferences preferences) {
    _preferences = preferences;
    _completed.value = preferences.getBool(_key) ?? _completed.value;
  }
}

/// Whether the user has finished the onboarding, as the guard of the routes
/// of the onboarding asks it: while the value is `false`, the router shows
/// the onboarding in place of every other screen.
ValueListenable<bool> onboardingCompleted() => onboardingStatus.completed;

/// Restores from [preferences], which the app opened, whether the user has
/// finished the onboarding, and keeps them for when that changes: a
/// restorer of the preferences, which the app calls before its first frame.
void restoreOnboarding(AppPreferences preferences) =>
    onboardingStatus._restore(preferences);
