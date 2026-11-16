import 'package:flutter/foundation.dart';

import '../env/app_env.dart';
import '../preferences/app_preferences.dart';
import 'review_service.dart';

/// When a review is due. The stores ask an app not to ask on its first
/// launch, nor too often, and to ask once the user has used it. Change the
/// numbers here.
abstract final class ReviewPolicy {
  /// How many launches of the app, this one included, there are at least
  /// once a review is due. At least 2, so that the app never asks on its
  /// first launch.
  static const int launches = 3;

  /// How long after the first launch of the app a review is due.
  static const Duration sinceFirstLaunch = Duration(days: 3);

  /// How long after a request the next review is due, also in a new
  /// version of the app. The app asks at most once a version.
  static const Duration between = Duration(days: 14);
}

/// The application id of the app in Google Play: that of the flavor for a
/// release, also in a build of another flavor, whose own id has no page
/// there. Change it here if you change the application id of the app.
const String googlePlayId = {{{google_play_id}}};

/// The reviews of the app in its store: the review dialog, which the app
/// asks for when a review is due, and the page of the app in its store.
final AppReviewController appReview = AppReviewController();

/// Asks the store of the platform for its review dialog when a review is
/// due, and opens the page of the app in its store. The app has one,
/// [appReview].
///
/// It counts the launches of the app and remembers its last request in the
/// preferences of the app. It asks for nothing on its own: only a call of
/// [requestIfDue] asks.
final class AppReviewController {
  /// Creates the controller, which reads the time from [now] and the App
  /// Store ID of the app from [appStoreId], by default the value of
  /// `REVIEW_APP_STORE_ID` in `.env`. A test creates one with a clock and
  /// an ID of its own, gives it the preferences with [restore], and starts
  /// it with a service of its own.
  AppReviewController({
    this._now = DateTime.now,
    this._appStoreId = _appStoreIdOfEnv,
  });

  /// The keys under which the preferences keep what the controller
  /// remembers: the launches of the app, the time of its first launch, and
  /// the time and the version of its last request.
  static const _launchesKey = {{{launches_key}}};
  static const _firstLaunchKey = {{{first_launch_key}}};
  static const _askedAtKey = {{{asked_at_key}}};
  static const _askedVersionKey = {{{asked_version_key}}};

  /// An App Store ID: digits, and nothing else.
  static final RegExp _appStoreIdPattern = RegExp(r'^[0-9]+$');

  final DateTime Function() _now;
  final String? Function() _appStoreId;

  /// The service of the provider, once the controller has started.
  ReviewService? _service;

  /// The preferences that keep what the controller remembers, once the app
  /// opened them.
  AppPreferences? _preferences;

  /// The launches of the app, this one included.
  int _launches = 0;

  /// The time of the first launch of the app.
  DateTime? _firstLaunch;

  /// The time of the last request, if the app asked.
  DateTime? _askedAt;

  /// The version of the app in which it last asked, if it asked.
  String? _askedVersion;

  /// The request that is on its way, if any.
  Future<void>? _request;

  /// Whether the controller told in debug mode that the app has no App
  /// Store ID, or that its version is unknown.
  bool _toldOfStoreId = false;
  bool _toldOfVersion = false;

  /// Whether the app has a page in the store of the platform: on Android
  /// always, and on iOS once `REVIEW_APP_STORE_ID` in `.env` has the App
  /// Store ID of the app.
  bool get hasStorePage => storePage() != null;

  /// The page of the app in the store of the platform, or `null` where it
  /// has none: on Android the Google Play page of [googlePlayId], on iOS
  /// the App Store page of the App Store ID, which is all digits, and none
  /// on any other platform. With [review], the page on which the user
  /// writes a review, which only the App Store has apart.
  Uri? storePage({bool review = false}) => switch (defaultTargetPlatform) {
        TargetPlatform.android => Uri.https(
            'play.google.com',
            '/store/apps/details',
            {'id': googlePlayId},
          ),
        TargetPlatform.iOS => switch (_appStoreId()) {
            final id? when _appStoreIdPattern.hasMatch(id) => Uri.https(
                'apps.apple.com',
                '/app/id$id',
                review ? {'action': 'write-review'} : null,
              ),
            _ => null,
          },
        _ => null,
      };

  /// Opens the page of the app in its store, outside the app, or with
  /// [review] the page on which the user writes a review (see
  /// [storePage]), and returns whether an app of the device opened it:
  /// `false` where the app has no store page, and before the app started.
  /// Never throws.
  Future<bool> openStorePage({bool review = false}) async {
    final page = storePage(review: review);
    final service = _service;
    if (page == null || service == null) return false;
    try {
      return await service.openStorePage(page);
    } on Object catch (error) {
      _tell('The page of the app in its store did not open: $error');
      return false;
    }
  }

  /// Asks the store for its review dialog when a review is due, and does
  /// nothing otherwise. Call it at a natural break of the app, such as when
  /// the user has finished a task:
  ///
  /// ```dart
  /// await saveNote(note);
  /// unawaited(appReview.requestIfDue());
  /// ```
  ///
  /// Never call it from a button, nor after a question of your own, such
  /// as whether the user likes the app: the stores forbid both. The app
  /// shows nothing around the dialog.
  ///
  /// A review is due once the app has had [ReviewPolicy.launches] launches,
  /// this one included, [ReviewPolicy.sinceFirstLaunch] has passed since
  /// its first launch and [ReviewPolicy.between] since its last request, and
  /// it did not ask in this version of the app, while the store of the
  /// device can show the dialog and the user is in no flow of a guard of the
  /// routes, such as the onboarding or a sign-in.
  ///
  /// It completes once the store took the request, and the app then
  /// remembers it. It returns nothing, since the store tells no app whether
  /// the dialog showed, so nothing may depend on it. It never throws: an
  /// error of the store counts as no dialog, and a later call asks again. A
  /// call while a request is on its way gets that request.
  Future<void> requestIfDue() =>
      _request ??= _askIfDue().whenComplete(() => _request = null);

  /// Takes what the controller remembers from [preferences], and keeps it
  /// as it is for a key that has nothing saved. It keeps [preferences] for
  /// the writes of the controller.
  void restore(AppPreferences preferences) {
    _preferences = preferences;
    _launches = preferences.getInt(_launchesKey) ?? _launches;
    _firstLaunch = _timeOf(preferences.getInt(_firstLaunchKey)) ?? _firstLaunch;
    _askedAt = _timeOf(preferences.getInt(_askedAtKey)) ?? _askedAt;
    _askedVersion = preferences.getString(_askedVersionKey) ?? _askedVersion;
  }

  /// Starts with [service]: counts this launch of the app, and the time of
  /// its first launch if it has none, and saves them.
  ///
  /// `initReview()` calls it in `bootstrap()`. It may be called again, with
  /// the service that the app has from then on: `initReview()` does so in a
  /// test of the next launch of the app, and a test gives it a service of
  /// its own. A failed save is told in debug mode and stops nothing.
  Future<void> start(ReviewService service) async {
    _service = service;
    _launches++;
    final saved = _firstLaunch;
    final firstLaunch = _firstLaunch ??= _now().toUtc();
    try {
      await _preferences?.setInt(_launchesKey, _launches);
      if (saved == null) {
        await _preferences?.setInt(
          _firstLaunchKey,
          firstLaunch.millisecondsSinceEpoch,
        );
      }
    } on Object catch (error) {
      _tell('The launch of the app was not saved for the reviews: $error');
    }
    if (!_toldOfStoreId &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !hasStorePage) {
      _toldOfStoreId = true;
      _tell(
        'REVIEW_APP_STORE_ID in .env has no App Store ID, so the app has no '
        'App Store page: appReview.hasStorePage is false on iOS, and '
        'appReview.openStorePage() opens nothing there. Put the Apple ID of '
        'the app in App Store Connect there.',
      );
    }
  }

  /// Asks the store for its dialog if a review is due, and remembers the
  /// request once the store took it. Never throws.
  Future<void> _askIfDue() async {
    try {
      final service = _service;
      if (service == null || !_dueByTime() || _inAGuardFlow()) return;
      final version = await _versionOf(service);
      if (version == null || version == _askedVersion) return;
      if (!await _isAvailable(service) || _inAGuardFlow()) return;
      try {
        await service.requestReview();
      } on Object catch (error) {
        _tell('The store did not take the request for a review: $error');
        return;
      }
      final askedAt = _askedAt = _now().toUtc();
      _askedVersion = version;
      try {
        await _preferences?.setInt(
          _askedAtKey,
          askedAt.millisecondsSinceEpoch,
        );
        await _preferences?.setString(_askedVersionKey, version);
      } on Object catch (error) {
        _tell('The request for a review was not saved: $error');
      }
    } on Object catch (error) {
      _tell('The request for a review failed: $error');
    }
  }

  /// Whether a review is due by the launches and the times that the
  /// controller remembers. A request whose time is to come, as after the
  /// clock of the device went back, counts as recent.
  bool _dueByTime() {
    final firstLaunch = _firstLaunch;
    if (_launches < ReviewPolicy.launches || firstLaunch == null) return false;
    final now = _now();
    if (now.difference(firstLaunch) < ReviewPolicy.sinceFirstLaunch) {
      return false;
    }
    final askedAt = _askedAt;
    if (askedAt == null) return true;
    final since = now.difference(askedAt);
    return !since.isNegative && since >= ReviewPolicy.between;
  }

  /// The version of the app that [service] gives, or `null` if it is
  /// unknown, which makes no review due.
  Future<String?> _versionOf(ReviewService service) async {
    String? version;
    try {
      version = (await service.appVersion())?.trim();
    } on Object catch (error) {
      _tell('The version of the app is unknown: $error');
    }
    if (version != null && version.isNotEmpty) return version;
    if (!_toldOfVersion) {
      _toldOfVersion = true;
      _tell(
        'The version of the app is unknown, so the app asks for no review.',
      );
    }
    return null;
  }

  /// Whether the store of the device can show the review dialog, as
  /// [service] tells: `false` if it fails to tell.
  Future<bool> _isAvailable(ReviewService service) async {
    try {
      return await service.isAvailable();
    } on Object {
      return false;
    }
  }

  /// Prints [message] in debug mode, for the developer of the app.
  static void _tell(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// The time of [milliseconds] since the epoch, in UTC, or `null`.
  static DateTime? _timeOf(int? milliseconds) => milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

/// The App Store ID of the app, as `REVIEW_APP_STORE_ID` in `.env` has it,
/// or `null` while it is empty.
String? _appStoreIdOfEnv() => AppEnv.reviewAppStoreId;

/// Restores from [preferences] what [appReview] remembers, and keeps them
/// for its writes: a restorer of the preferences, which the app calls
/// before its first frame.
void restoreReview(AppPreferences preferences) =>
    appReview.restore(preferences);

/// Returns the service of the provider of the reviews, which [initReview]
/// created: `bootstrap()` awaits it before the first frame, and there is
/// none to return before that.
///
/// The code of the app does not call it: it uses [appReview].
ReviewService createReviewService() => _reviewService;

{{{guard_flows}}}

{{{smf_review__implementations}}}
