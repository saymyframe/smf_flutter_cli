// A test that continuous integration runs in the apps with the module
// native_splash: what the real flutter_native_splash leaves in the app, which
// a new version of the tool may change. Only this module knows its colours,
// and what the tool does to a file that it writes anew.
//
// It reads the files of the app as smf create left them, and starts no app.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _lightBackground = '{{light_background}}';
const _darkBackground = '{{dark_background}}';
const _infoPlist = '{{info_plist}}';
const _manifest = '{{android_manifest}}';

/// The items of the style `LaunchTheme` in the directory [values] of the
/// resources of the Android app, by their names.
Map<String, String> _launchThemeIn(String values) {
  final file = File('${File(_manifest).parent.path}/res/$values/styles.xml');
  return {
    for (final style
        in XmlDocument.parse(file.readAsStringSync()).findAllElements('style'))
      if (style.getAttribute('name') == 'LaunchTheme')
        for (final item in style.findElements('item'))
          item.getAttribute('name')!: item.innerText.trim(),
  };
}

/// The keys of the property list [file] with the elements of their values.
Map<String, XmlElement> _plist(File file) {
  final dict = XmlDocument.parse(
    file.readAsStringSync(),
  ).rootElement.findElements('dict').single.childElements.toList();
  return {
    for (var index = 0; index + 1 < dict.length; index += 2)
      dict[index].innerText: dict[index + 1],
  };
}

void main() {
  test(
      'from Android 12 on, the splash screen has the colours of the module, '
      'one for each mode', () {
    const background = 'android:windowSplashScreenBackground';
    expect(
      _launchThemeIn('values-v31')[background]?.toUpperCase(),
      _lightBackground,
      reason: 'The light mode has the light colour of the module.',
    );
    expect(
      _launchThemeIn('values-night-v31')[background]?.toUpperCase(),
      _darkBackground,
      reason: 'The dark mode has the dark colour of the module.',
    );
  });

  test(
      'flutter_native_splash writes Info.plist anew and keeps its keys, with '
      'the build variables that the Xcode project fills in', () {
    final plist = _plist(File(_infoPlist));
    for (final key in const [
      'CFBundleDisplayName',
      'CFBundleExecutable',
      'CFBundleIdentifier',
      'CFBundleShortVersionString',
      'CFBundleVersion',
    ]) {
      expect(
        plist[key]?.innerText,
        startsWith(r'$('),
        reason: '$key of Info.plist still reads a build variable.',
      );
    }
    for (final key in const [
      'UILaunchStoryboardName',
      'UIMainStoryboardFile',
      'UISupportedInterfaceOrientations',
    ]) {
      expect(plist, contains(key), reason: 'Info.plist still has $key.');
    }
  });
}
