// The platform side of the email_feedback module for the tests that
// continuous integration runs in the apps with the module: a device with a
// mail app, which opens every new mail and says no when it is asked whether
// it can, as Android 11 and later say to an app whose manifest names no
// other app. That is what the feedback role asks of the mocks of every
// provider, and the test of the module gives the address of .env a value,
// so the provider has what it needs. The version of the app is 1.0.0 and its
// build number 1, and the device is a Google Pixel 7 with Android 14 or an
// iPhone 15 Pro with iOS 17.4, by the platform of the test. The matrix sets
// it up before the tests of every module of such an app
// (MatrixAppTest.mocks).
//
// The mail opens with url_launcher, so this puts a device with a mail app
// in place of the platform side of url_launcher, which takes the mailto:
// links and passes every other link on to the platform side that was there
// before, as do those of the other modules that open links: the tests of a
// module that opens a page of a store or of the web find what they found
// without it. The version comes from package_info_plus, whose values for
// tests this sets, and the device from device_info_plus, whose method
// channel this answers. A test may hold that answer, as a slow device does.
// The version is not read through a channel once package_info_plus has its
// values for tests, so no test can hold it.
import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// The method channel of device_info_plus.
const _deviceInfo = MethodChannel('dev.fluttercommunity.plus/device_info');

/// What the mail app of the device does with the next new mail.
enum MailAnswer {
  /// It opens the mail.
  opens,

  /// Nothing opens it, as iOS answers without a mail app, such as on the
  /// simulator.
  nothingOpens,

  /// No app takes the link, which Android throws as `ACTIVITY_NOT_FOUND`.
  noActivity,
}

/// A link of a new mail that reached the mail app of the device, with the
/// mode in which the app asked to open it.
typedef OpenedMail = ({Uri link, String raw, String mode});

/// The device of the tests, with a mail app; see [mockEmailFeedback].
final class MailDevice {
  MailDevice._();

  /// The new mails that reached the mail app, in their order.
  final List<OpenedMail> opened = [];

  /// How many times the app asked whether the device can open a mailto:
  /// link, which it never should.
  int questions = 0;

  /// Whether device_info_plus fails to read the device.
  bool deviceFails = false;

  /// The answer of device_info_plus that waits until [releaseDevice], if a
  /// test holds one.
  Completer<void>? _deviceHeld;

  /// Holds what device_info_plus reads until [releaseDevice], as a device
  /// that is slow to tell what it is.
  void holdDevice() => _deviceHeld = Completer<void>();

  /// Lets the read of device_info_plus that waits get its answer.
  void releaseDevice() {
    final held = _deviceHeld;
    _deviceHeld = null;
    held?.complete();
  }

  /// What the mail app does with the next new mail; then it opens mails
  /// again.
  MailAnswer next = MailAnswer.opens;

  /// The answer of the mail app that waits until [release], if a test holds
  /// one.
  Completer<void>? _held;

  /// Holds the next new mail until [release], as a slow device does.
  void hold() => _held = Completer<void>();

  /// Lets the new mail that waits get its answer.
  void release() {
    final held = _held;
    _held = null;
    held?.complete();
  }

  /// What the mail app answers to the link [url], opened in [mode].
  Future<bool> _open(String url, String mode) async {
    opened.add((link: Uri.parse(url), raw: url, mode: mode));
    if (_held case final held?) await held.future;
    final answer = next;
    next = MailAnswer.opens;
    return switch (answer) {
      MailAnswer.opens => true,
      MailAnswer.nothingOpens => false,
      MailAnswer.noActivity => throw PlatformException(
          code: 'ACTIVITY_NOT_FOUND',
          message: 'No Activity found to handle Intent { $url }',
        ),
    };
  }

  /// What device_info_plus reads on the platform of the test.
  Map<String, Object?> _deviceData() {
    if (deviceFails) {
      throw PlatformException(code: 'error', message: 'No device.');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return IosDeviceInfo.setMockInitialValues(
        name: 'The iPhone of the tests',
        systemName: 'iOS',
        systemVersion: '17.4',
        model: 'iPhone',
        modelName: 'iPhone 15 Pro',
        localizedModel: 'iPhone',
        freeDiskSize: 0,
        totalDiskSize: 0,
        isPhysicalDevice: true,
        isiOSAppOnMac: false,
        isiOSAppOnVision: false,
        physicalRamSize: 0,
        availableRamSize: 0,
        utsname: IosUtsname.setMockInitialValues(
          sysname: 'Darwin',
          nodename: 'iPhone',
          release: '23.4.0',
          version: 'Darwin Kernel Version 23.4.0',
          machine: 'iPhone16,1',
        ),
      ).data;
    }
    return AndroidDeviceInfo.setMockInitialValues(
      version: AndroidBuildVersion.setMockInitialValues(
        codename: 'REL',
        incremental: '1',
        previewSdkInt: 0,
        release: '14',
        sdkInt: 34,
        securityPatch: '2024-03-05',
      ),
      board: 'panther',
      bootloader: 'slider',
      brand: 'google',
      device: 'panther',
      display: 'AP1A',
      fingerprint: 'google/panther/panther:14',
      hardware: 'panther',
      host: 'build',
      id: 'AP1A',
      manufacturer: 'Google',
      model: 'Pixel 7',
      product: 'panther',
      name: 'Pixel 7',
      supported32BitAbis: const [],
      supported64BitAbis: const ['arm64-v8a'],
      supportedAbis: const ['arm64-v8a'],
      tags: 'release-keys',
      time: 0,
      type: 'user',
      isPhysicalDevice: true,
      freeDiskSize: 0,
      totalDiskSize: 0,
      systemFeatures: const [],
      isLowRamDevice: false,
      physicalRamSize: 0,
      availableRamSize: 0,
    ).data;
  }

  /// Gives package_info_plus the version 1.0.0 and the build number 1 of
  /// the app, answers the method channel of device_info_plus, and puts the
  /// mail app in front of the platform side of url_launcher.
  void _install() {
    setVersion('1.0.0', '1');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_deviceInfo, (call) async {
      if (call.method != 'getDeviceInfo') {
        throw MissingPluginException('No answer for ${call.method}');
      }
      if (_deviceHeld case final held?) await held.future;
      return _deviceData();
    });
    UrlLauncherPlatform.instance = _MailApp(this, UrlLauncherPlatform.instance);
  }
}

/// Gives package_info_plus [version] and [buildNumber] as the version of
/// the app, such as an empty one for a test of a version that is unknown.
void setVersion(String version, String buildNumber) =>
    PackageInfo.setMockInitialValues(
      appName: '{{app_name}}',
      packageName: 'com.example.{{app_name}}',
      version: version,
      buildNumber: buildNumber,
      buildSignature: '',
    );

/// The platform side of url_launcher with the mail app of [_device]: it
/// takes the mailto: links, and passes every other link on to [_before],
/// the platform side that was there before.
final class _MailApp extends UrlLauncherPlatform {
  _MailApp(this._device, this._before);

  final MailDevice _device;
  final UrlLauncherPlatform _before;

  static bool _isMail(String url) => Uri.tryParse(url)?.scheme == 'mailto';

  @override
  LinkDelegate? get linkDelegate => _before.linkDelegate;

  @override
  Future<bool> canLaunch(String url) async {
    if (!_isMail(url)) return _before.canLaunch(url);
    // Android 11 and later answer no to an app whose manifest names no
    // other app, though a mail app is there.
    _device.questions++;
    return false;
  }

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
      _isMail(url)
          ? _device._open(url, 'launch')
          : _before.launch(
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
  Future<bool> launchUrl(String url, LaunchOptions options) => _isMail(url)
      ? _device._open(url, options.mode.name)
      : _before.launchUrl(url, options);

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) =>
      _before.supportsMode(mode);

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) =>
      _before.supportsCloseForMode(mode);

  @override
  Future<void> closeWebView() => _before.closeWebView();
}

/// Puts a device with a mail app in place of the platform side of the
/// module, as an app finds it on any launch, and returns it: a test reads
/// there the new mails that reached the mail app and the questions that the
/// app asked, and scripts what the device answers.
///
/// The binding of the tests must be initialized first. A test file that
/// calls it for a device of its own does so before it opens a mail.
MailDevice mockEmailFeedback() => MailDevice._().._install();
