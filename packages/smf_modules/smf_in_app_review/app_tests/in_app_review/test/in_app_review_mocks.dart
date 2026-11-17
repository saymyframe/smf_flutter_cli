// The platform side of in_app_review for the tests that continuous
// integration runs in the apps with the in_app_review module: a device with
// the store of its platform, whose store can show its review dialog, which
// shows nothing in the tests. A request completes at once, a page of the
// store opens, and the version of the app is 1.0.0, as the review role asks
// of the mocks of a provider. The matrix sets it up before the tests of
// every module of such an app (MatrixAppTest.mocks), so that any of them may
// run the start-up of the app, which starts the reviews on it.
//
// in_app_review has no mocks for tests, so this answers the messages of the
// package to the platform on its method channel. A version of the package
// that changes its messages breaks these tests. It records every call that
// reaches the channel. openStoreListing() of the package, which the module
// never calls, picks its platform by the system of the machine that runs
// the test and not by the platform of the test, so it would not reach the
// channel there: the unit tests of the module keep it out.
//
// The page of the app in its store opens with url_launcher, so this puts a
// recorder of the pages of the stores in place of the platform side of
// url_launcher, which passes every other link on to the platform side that
// was there before: the tests of other modules that open links find what
// they found without it. The version of the app comes from
// package_info_plus, whose values for tests this sets.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// The method channel of in_app_review.
const _channel = MethodChannel('dev.britannio.in_app_review');

/// The hosts of the pages of the stores, which the recorder opens.
const _storeHosts = {'play.google.com', 'apps.apple.com'};

/// The platform side of in_app_review in memory; see [mockInAppReview].
final class MockInAppReview {
  MockInAppReview._();

  /// Whether the store of the device can show its review dialog.
  bool available = true;

  /// Whether an app of the device opens a page of a store.
  bool opens = true;

  /// The calls that reached the platform side of in_app_review, in their
  /// order.
  final List<MethodCall> calls = [];

  /// The pages of the stores that the app opened, in their order, each as
  /// `<link> <mode>`.
  final List<String> opened = [];

  final Map<String, PlatformException> _failures = {};

  /// What the next page of a store fails to open with, if anything.
  PlatformException? _pageFailure;

  /// The names of the methods of the calls that reached the platform side
  /// of in_app_review, in their order.
  List<String> get methods => [for (final call in calls) call.method];

  /// Has the next call of [method] fail with [error], as the platform
  /// fails it, such as Android without the review service of Google Play
  /// for `requestReview`.
  void failNext(String method, PlatformException error) =>
      _failures[method] = error;

  /// Has the next page of a store fail to open with [error], as the
  /// platform side of url_launcher fails, such as on a device without an
  /// app for the link.
  void failNextPage(PlatformException error) => _pageFailure = error;

  /// Answers the messages of the package to the platform, gives
  /// package_info_plus the values of the tests, and puts the recorder of the
  /// pages of the stores in front of the platform side of url_launcher.
  void _install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (_failures.remove(call.method) case final error?) throw error;
      return switch (call.method) {
        'isAvailable' => available,
        'requestReview' => null,
        _ => throw MissingPluginException('No answer for ${call.method}'),
      };
    });
    PackageInfo.setMockInitialValues(
      appName: '{{app_name}}',
      packageName: 'com.example.{{app_name}}',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    UrlLauncherPlatform.instance = _StorePages(
      this,
      UrlLauncherPlatform.instance,
    );
  }
}

/// The platform side of url_launcher with the pages of the stores: it opens
/// a page of a store as [_device] says, and passes every other link on to
/// [_before], the platform side that was there before.
final class _StorePages extends UrlLauncherPlatform {
  _StorePages(this._device, this._before);

  final MockInAppReview _device;
  final UrlLauncherPlatform _before;

  static bool _isStorePage(String url) =>
      _storeHosts.contains(Uri.tryParse(url)?.host);

  @override
  LinkDelegate? get linkDelegate => _before.linkDelegate;

  @override
  Future<bool> canLaunch(String url) async =>
      _isStorePage(url) || await _before.canLaunch(url);

  // The call of the platform interface before launchUrl, which the module
  // never makes: an implementation that does not forward it throws.
  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) =>
      _before.launch(
        url,
        useSafariVC: useSafariVC,
        useWebView: useWebView,
        enableJavaScript: enableJavaScript,
        enableDomStorage: enableDomStorage,
        universalLinksOnly: universalLinksOnly,
        headers: headers,
        webOnlyWindowName: webOnlyWindowName,
      );

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (!_isStorePage(url)) return _before.launchUrl(url, options);
    _device.opened.add('$url ${options.mode.name}');
    final failure = _device._pageFailure;
    _device._pageFailure = null;
    if (failure != null) throw failure;
    return _device.opens;
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) =>
      _before.supportsMode(mode);

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) =>
      _before.supportsCloseForMode(mode);

  @override
  Future<void> closeWebView() => _before.closeWebView();
}

/// Answers the platform side of in_app_review as a device with the store of
/// its platform, as an app finds it on any launch, and returns it: a test
/// reads there what reached the platform side and the pages that opened,
/// and scripts what the platform answers.
///
/// The binding of the tests must be initialized first. A test file that
/// calls it for a device of its own does so before it asks the reviews of
/// the app for anything.
MockInAppReview mockInAppReview() => MockInAppReview._().._install();
