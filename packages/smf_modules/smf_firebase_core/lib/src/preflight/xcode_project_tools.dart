import 'package:smf_contracts/lego.dart';

/// The lowest version of the Ruby gem xcodeproj that opens the Xcode project
/// of the app, which has a local Swift package: 1.23.0 added
/// `XCLocalSwiftPackageReference`.
const minimumXcodeprojVersion = '1.23.0';

/// Checks what `flutterfire configure` needs on macOS to set up the iOS app
/// in its Xcode project: Ruby and its gem xcodeproj, which must open the
/// Xcode project of the app, [minimumXcodeprojVersion] or newer.
///
/// Without them, flutterfire_cli 1.4 fails on macOS after it registered the
/// apps in the Firebase project and wrote the files of Android and the
/// `GoogleService-Info.plist` of iOS, but before it writes the options, so
/// the step that runs it needs this check. On any other system flutterfire
/// does not change the Xcode project, so the check passes there, and
/// [XcodeProjectOnMacCheck] tells what that leaves to do. Nothing here can
/// be installed for the user.
final class XcodeProjectToolsCheck extends PreflightCheck {
  /// Creates the check.
  const XcodeProjectToolsCheck();

  @override
  String get id => 'xcode_project_tools';

  @override
  String get description => 'Xcode project tools of flutterfire';

  static const _install = 'install it with "gem install xcodeproj", with a '
      'Ruby version manager or, for the Ruby of macOS, with sudo';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    if (environment.operatingSystem != HostOperatingSystem.macos) {
      return const PreflightPassed();
    }
    final ruby = await environment.findExecutable('ruby');
    if (ruby == null) {
      return const PreflightMissing(
        instructions: 'flutterfire configure changes the Xcode project with '
            'Ruby and its gem xcodeproj $minimumXcodeprojVersion or newer: '
            'install Ruby, then the gem with "gem install xcodeproj".',
      );
    }
    final result = await environment.processRunner.run(
      ruby,
      const ['-e', "require 'xcodeproj'; print Xcodeproj::VERSION"],
    );
    if (!result.succeeded) {
      return const PreflightMissing(
        instructions: 'flutterfire configure changes the Xcode project with '
            'the Ruby gem xcodeproj $minimumXcodeprojVersion or newer: '
            '$_install.',
      );
    }
    final version = result.stdout.trim();
    final int order;
    try {
      order = compareLooseVersions(version, minimumXcodeprojVersion);
    } on FormatException {
      return PreflightFailed(
        'Ruby printed "$version" for the version of the gem xcodeproj.',
      );
    }
    if (order < 0) {
      return PreflightMissing(
        instructions: 'The Ruby gem xcodeproj is $version, but flutterfire '
            'configure needs $minimumXcodeprojVersion or newer to open the '
            'Xcode project of the app, which has a Swift package: $_install.',
      );
    }
    return const PreflightPassed();
  }
}

/// Tells, on any system but macOS, that `flutterfire configure` sets up the
/// iOS app in its Xcode project only on macOS.
///
/// Elsewhere it registers the iOS app and writes its options, but writes no
/// `GoogleService-Info.plist` and leaves the Xcode project as it is, so it
/// is set up by running `flutterfire configure` again on a Mac. The check
/// passes on macOS, where [XcodeProjectToolsCheck] checks what that needs,
/// and nothing here can be installed.
final class XcodeProjectOnMacCheck extends PreflightCheck {
  /// Creates the check.
  const XcodeProjectOnMacCheck();

  @override
  String get id => 'xcode_project_on_mac';

  @override
  String get description => 'Setup of the Xcode project on a Mac';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async =>
      environment.operatingSystem == HostOperatingSystem.macos
          ? const PreflightPassed()
          : const PreflightMissing(
              instructions: 'flutterfire configure changes the Xcode project '
                  'only on macOS. Elsewhere it registers the iOS app and '
                  'writes its options into lib/firebase_options.dart, but '
                  'writes no GoogleService-Info.plist and leaves the Xcode '
                  'project as it is: run flutterfire configure again on a '
                  'Mac.',
            );
}
