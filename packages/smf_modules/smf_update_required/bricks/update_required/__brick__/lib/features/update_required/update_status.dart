import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/remote_config/app_remote_config.dart';
import '../../core/review/app_review.dart';
import 'version_compare.dart';

/// What came of the last tap on "Update" on the screen "Update required".
enum StoreVisit {
  /// The user has not opened the store from the screen yet.
  none,

  /// The page of the app in its store opened.
  opened,

  /// No app of the device opened the page of the app in its store.
  failed,
}

/// Whether the version of the app may run, which the guard of the routes of
/// the screen "Update required" asks: while it may not, the router shows the
/// screen in place of every other screen of the app.
///
/// The app may not run while its version is below the lowest version that
/// may run, `update_required_minimum_version` of remote config, and the app
/// has a page in its store to update from. So nothing navigates to the
/// screen: [UpdateStatus.continueForNow] lets the user in.
final updateStatus = UpdateStatus._();

/// Follows the lowest version that may run in remote config, compares the
/// version of the app with it, and keeps what the screen "Update required"
/// offers. The app has one, [updateStatus].
///
/// Until the user taps "Update", which opens the page of the app in its store,
/// the screen offers no way into the app. From then on, or at once when the
/// page did not open, it also offers "Not now", which lets the user in for this
/// launch. So a lowest version above the version in the store, set too early,
/// costs a user one trip to the store and never locks anyone out.
final class UpdateStatus {
  UpdateStatus._();

  /// How long [start] waits at most for the version of the app.
  static const versionWait = Duration(seconds: 2);

  /// How long [openStore] waits at most for the store page to open. A page
  /// that does not answer in that time counts as opened, so that the screen
  /// offers "Not now" and nobody is locked out.
  static const storeWait = Duration(seconds: 10);

  /// The reviews of the app, whose store page the screen opens: [appReview],
  /// or the controller that a test gives [start].
  AppReviewController _review = appReview;

  final ValueNotifier<bool> _supported = ValueNotifier(true);

  final ValueNotifier<StoreVisit> _storeVisit = ValueNotifier(
    StoreVisit.none,
  );

  /// The version of the app, once [start] read it.
  String? _version;

  /// The lowest version that the user let pass for this launch with "Not
  /// now", if any.
  String? _waived;

  /// Whether the status follows the values of remote config.
  bool _following = false;

  /// The opening of the store page that is on its way, if any.
  Future<void>? _opening;

  /// What a debug build printed, so that it prints each once.
  final Set<String> _told = {};

  /// Whether the version of the app may run. It notifies its listeners when
  /// that changes; the guard of the routes of the screen reads it.
  ValueListenable<bool> get supported => _supported;

  /// What came of the last tap on "Update" since the screen last took the
  /// place of the app.
  ValueListenable<StoreVisit> get storeVisit => _storeVisit;

  /// The version of the app without its build number, such as `1.4.0`, once
  /// [start] read it, or `null` while it is unknown.
  String? get version => _version;

  /// The lowest version that may run, as remote config has it now, without
  /// the spaces around it: empty for none.
  String get minimum =>
      appRemoteConfig.value.updateRequiredMinimumVersion.trim();

  /// The lowest version that the user let pass for this launch with "Not
  /// now", or `null`.
  String? get waived => _waived;

  /// Whether the app has a page in its store to update from: without one,
  /// the screen never shows.
  bool get hasStorePage => _review.hasStorePage;

  /// Reads the version of the app, within [versionWait], and starts to
  /// follow the lowest version that may run in remote config: when it
  /// returns, [supported] tells whether the version may run, before the
  /// first frame of the app.
  ///
  /// `bootstrap()` calls it once the services of the app are ready, and the
  /// store page is that of [appReview]. It may be called again, as at the
  /// next launch of the app in a test: the screen is then hard again, and a
  /// lowest version that the user let pass counts again. A test gives it
  /// [review], a controller of the reviews of its own, such as one with an
  /// App Store ID that it scripts. A version that it cannot read leaves the
  /// app running, and a debug build prints why.
  Future<void> start({AppReviewController? review}) async {
    _review = review ?? appReview;
    _waived = null;
    _storeVisit.value = StoreVisit.none;
    String? version;
    try {
      final info = await PackageInfo.fromPlatform().timeout(versionWait);
      version = info.version.trim();
    } on Object catch (error) {
      _tell(
        'The version of the app is unknown, so the screen "Update required" '
        'does not show: $error',
      );
    }
    if (version != null && versionNumbers(version) == null) {
      _tell(
        'The version of the app, "$version", is not numbers between dots, '
        'such as 1.4.0, so the screen "Update required" does not show.',
      );
    }
    _version = version;
    if (!_following) {
      _following = true;
      appRemoteConfig.addListener(_update);
    }
    _update();
  }

  /// Opens the page of the app in its store, outside the app, and offers
  /// "Not now" on the screen from then on: once the page opened, or at once
  /// if no app of the device opened it, which the screen says. A page that
  /// does not answer within [storeWait] counts as opened. A tap while the
  /// page is opening opens it once.
  Future<void> openStore() =>
      _opening ??= _openStore().whenComplete(() => _opening = null);

  Future<void> _openStore() async {
    final opened = await _review.openStorePage().timeout(
      storeWait,
      onTimeout: () => true,
    );
    _storeVisit.value = opened ? StoreVisit.opened : StoreVisit.failed;
  }

  /// Lets the user in for this launch, below the lowest version that remote
  /// config has now: "Not now" on the screen. The router then shows the
  /// screen that the screen "Update required" took the place of.
  ///
  /// It does nothing until the user opened the store from the screen, or the
  /// store did not open. Another lowest version takes the place of the app
  /// again, and so does the next launch.
  void continueForNow() {
    if (_storeVisit.value == StoreVisit.none) return;
    _waived = minimum;
    _update();
  }

  /// Takes whether the version of the app may run from the values of remote
  /// config.
  void _update() {
    final minimum = this.minimum;
    final version = _version;
    var supported = true;
    if (version != null && minimum.isNotEmpty) {
      if (versionNumbers(minimum) == null) {
        _tell(
          'update_required_minimum_version of remote config, "$minimum", is '
          'not numbers between dots, such as 1.4.0, so the app runs.',
        );
      } else if (versionBelow(version, minimum) && minimum != _waived) {
        if (_review.hasStorePage) {
          supported = false;
        } else {
          _tell(
            'The version of the app, $version, is below $minimum, the lowest '
            'version that may run, but the screen "Update required" does not '
            'show: the app has no page in its store to update from. On iOS, '
            'put the App Store ID of the app into {{app_store_id_key}} of '
            '.env.',
          );
        }
      }
    }
    // The screen offers no way in again each time it takes the place of the
    // app.
    if (!supported && _supported.value) _storeVisit.value = StoreVisit.none;
    _supported.value = supported;
  }

  /// Prints [message] once in a debug build, for the developer of the app.
  void _tell(String message) {
    if (kDebugMode && _told.add(message)) debugPrint(message);
  }
}

/// Whether the version of the app may run, as the guard of the routes of the
/// screen "Update required" asks it: while the value is `false`, the router
/// shows the screen in place of every other screen of the app.
ValueListenable<bool> versionSupported() => updateStatus.supported;
