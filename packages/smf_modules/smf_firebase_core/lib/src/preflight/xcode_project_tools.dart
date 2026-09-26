import 'package:smf_contracts/lego.dart';

/// The lowest version of the Ruby gem xcodeproj that opens the Xcode project
/// of the app, which has a local Swift package: 1.23.0 added
/// `XCLocalSwiftPackageReference`.
const minimumXcodeprojVersion = '1.23.0';

/// Checks what `flutterfire configure` needs to set up the iOS app in its
/// Xcode project.
///
/// It does that only on macOS, with Ruby and its gem xcodeproj, which must
/// open the Xcode project of the app: [minimumXcodeprojVersion] or newer. On
/// any other system, the check reports that the Xcode project stays as it
/// is, so it is set up by running `flutterfire configure` again on a Mac.
/// Nothing here can be installed for the user.
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
      return const PreflightMissing(
        instructions: 'flutterfire configure changes the Xcode project only '
            'on macOS. Elsewhere it registers the iOS app and writes its '
            'options into lib/firebase_options.dart, but writes no '
            'GoogleService-Info.plist and leaves the Xcode project as it '
            'is: run flutterfire configure again on a Mac.',
      );
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
