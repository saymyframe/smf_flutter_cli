// A test that continuous integration runs in the apps with the splash role,
// whichever module provides it: the step of the provider made the screen that
// the system shows while the app starts, in the native projects of the app.
//
// Nothing of the screen shows in Dart, and a snapshot of an app shows it before
// its steps, so the test reads the files of the app as smf create left them.
// It starts no app and has no probe for the start check. It names no tool and
// no file that only one tool writes: it follows what the system follows, from
// the theme of the activity and from the launch storyboard, and asks for each
// resource what Android would pick for a version of the system and a mode of
// the device.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _lightImage = '{{light_image}}';
const _darkImage = '{{dark_image}}';
const _manifest = '{{android_manifest}}';
const _infoPlist = '{{info_plist}}';

/// The directory of the resources of the Android app.
final _res = Directory('${File(_manifest).parent.path}/res');

/// The versions of Android below 12 that the apps run on, which show the
/// window background of the theme of the activity.
const _belowAndroid12 = [24, 25, 26, 27, 28, 29, 30];

/// The first version of Android that has a splash screen of its own.
const _android12 = 31;

/// A directory of resources: `drawable-night-xhdpi-v21`, as its parts.
final _directoryName = RegExp(
  r'^([a-z]+)(-night)?(-(?:[a-z]+dpi))?(?:-v(\d+))?$',
);

/// The parts of the name of [directory], or `null` for a directory of a kind
/// that the test does not look at, such as one for a language.
RegExpMatch? _matchOf(Directory directory) => _directoryName.firstMatch(
      directory.uri.pathSegments.lastWhere((segment) => segment.isNotEmpty),
    );

/// The files of the resource [name] of [kinds], such as the drawable
/// `launch_background`, that Android would pick at the version [api] of the
/// system in a mode of the device, one for each density that it has them in.
///
/// Android leaves out what contradicts the device. Then a directory for the
/// night mode wins over one for no mode, and within a density the highest
/// version wins.
List<File> _picked(
  List<String> kinds,
  String name, {
  required int api,
  required bool night,
}) {
  final candidates = <(String, bool, int, File)>[];
  for (final directory in _res.listSync().whereType<Directory>()) {
    final match = _matchOf(directory);
    if (match == null || !kinds.contains(match[1])) continue;
    final forNight = match[2] != null;
    final version = int.parse(match[4] ?? '0');
    if ((forNight && !night) || version > api) continue;
    for (final file in directory.listSync().whereType<File>()) {
      if (file.uri.pathSegments.last.split('.').first == name) {
        candidates.add((match[3] ?? '', forNight, version, file));
      }
    }
  }
  final ofMode = candidates.any((candidate) => candidate.$2)
      ? candidates.where((candidate) => candidate.$2)
      : candidates;
  final byDensity = <String, (int, File)>{};
  for (final (density, _, version, file) in ofMode) {
    final best = byDensity[density];
    if (best == null || best.$1 < version) byDensity[density] = (version, file);
  }
  return [for (final (_, file) in byDensity.values) file];
}

/// The items of the style [name] that Android would pick at [api] in a mode
/// of the device, by their names, or `null` if no file has the style.
Map<String, String>? _styleItems(
  String name, {
  required int api,
  required bool night,
}) {
  final files = <(bool, int, Map<String, String>)>[];
  for (final directory in _res.listSync().whereType<Directory>()) {
    final match = _matchOf(directory);
    if (match == null || match[1] != 'values' || match[3] != null) continue;
    final forNight = match[2] != null;
    final version = int.parse(match[4] ?? '0');
    if ((forNight && !night) || version > api) continue;
    for (final file in directory.listSync().whereType<File>()) {
      if (!file.path.endsWith('.xml')) continue;
      final document = XmlDocument.parse(file.readAsStringSync());
      for (final style in document.findAllElements('style')) {
        if (style.getAttribute('name') != name) continue;
        files.add((
          forNight,
          version,
          {
            for (final item in style.findElements('item'))
              item.getAttribute('name')!: item.innerText.trim(),
          },
        ));
      }
    }
  }
  if (files.isEmpty) return null;
  files.sort((a, b) {
    if (a.$1 != b.$1) return a.$1 ? -1 : 1;
    return b.$2.compareTo(a.$2);
  });
  return files.first.$3;
}

/// The name of the style of the activity that the launcher starts.
String _launchStyle() {
  final manifest = XmlDocument.parse(File(_manifest).readAsStringSync());
  final activity = manifest.findAllElements('activity').singleWhere(
        (activity) => activity.findAllElements('action').any(
              (action) =>
                  action.getAttribute('android:name') ==
                  'android.intent.action.MAIN',
            ),
      );
  final theme = activity.getAttribute('android:theme');
  expect(
    theme,
    startsWith('@style/'),
    reason: 'The activity that the launcher starts has a theme of the app.',
  );
  return theme!.substring('@style/'.length);
}

/// The width of the PNG image [bytes], or `null` for an image in another
/// format, which has no such place.
int? _pngWidth(List<int> bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47];
  for (var index = 0; index < signature.length; index++) {
    if (index >= bytes.length || bytes[index] != signature[index]) return null;
  }
  return bytes[16] << 24 | bytes[17] << 16 | bytes[18] << 8 | bytes[19];
}

/// Whether [file] has more to show than the image of one pixel that a new
/// Flutter project has in the place of an image.
bool _showsSomething(File file) => (_pngWidth(file.readAsBytesSync()) ?? 2) > 1;

/// The name after the `@drawable/` or `@mipmap/` of the reference [value], or
/// `null` for any other value.
String? _referenced(String? value) =>
    RegExp(r'^@(?:drawable|mipmap)/(.+)$').firstMatch(value ?? '')?.group(1);

/// Whether the drawable [name] shows an image at [api] in a mode of the device,
/// as a file of its own or as a layer of an XML file.
bool _hasImage(String name, {required int api, required bool night}) {
  final files = _picked(
    const ['drawable', 'mipmap'],
    name,
    api: api,
    night: night,
  );
  if (files.isEmpty) return false;
  return files.every((file) {
    if (!file.path.endsWith('.xml')) return _showsSomething(file);
    final document = XmlDocument.parse(file.readAsStringSync());
    if (document.rootElement.name.local == 'vector') return true;
    final layers = [
      for (final element in document.descendantElements)
        _referenced(
          element.getAttribute('android:src') ??
              element.getAttribute('android:drawable'),
        ),
    ].nonNulls;
    return layers.any((layer) => _hasImage(layer, api: api, night: night));
  });
}

/// What the files of the drawable [name] hold at [api] in a mode of the device,
/// with the files of its layers.
List<String> _contentOf(String name, {required int api, required bool night}) {
  final content = <String>[];
  for (final file in _picked(
    const ['drawable', 'mipmap'],
    name,
    api: api,
    night: night,
  )) {
    content.add(base64.encode(file.readAsBytesSync()));
    if (!file.path.endsWith('.xml')) continue;
    final document = XmlDocument.parse(file.readAsStringSync());
    for (final element in document.descendantElements) {
      final layer = _referenced(
        element.getAttribute('android:src') ??
            element.getAttribute('android:drawable'),
      );
      if (layer != null) {
        content.addAll(_contentOf(layer, api: api, night: night));
      }
    }
  }
  return content;
}

/// The values of the keys of the property list [file] that are plain strings.
Map<String, String> _plistStrings(File file) {
  final dict = XmlDocument.parse(file.readAsStringSync())
      .rootElement
      .findElements('dict')
      .single
      .childElements
      .toList();
  return {
    for (var index = 0; index + 1 < dict.length; index += 2)
      if (dict[index + 1].name.local == 'string')
        dict[index].innerText: dict[index + 1].innerText,
  };
}

/// The file or the directory called [name] in the directory of the iOS app,
/// or `null` if there is none.
FileSystemEntity? _inIosApp(String name) {
  final app = File(_infoPlist).parent;
  for (final entity in app.listSync(recursive: true, followLinks: false)) {
    if (entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty) == name) {
      return entity;
    }
  }
  return null;
}

void main() {
  test('the two images of the role are in the app', () {
    expect(
      [
        for (final path in const [_lightImage, _darkImage])
          if (!File(path).existsSync()) path,
      ],
      isEmpty,
      reason: 'A provider of the splash role generates its two images.',
    );
  });

  test(
      'below Android 12, the window background of the activity has an image '
      'in each mode, at each version of the system', () {
    final style = _launchStyle();
    final blank = <String>[];
    for (final api in _belowAndroid12) {
      for (final night in const [false, true]) {
        final mode = night ? 'dark' : 'light';
        final background = _referenced(
          _styleItems(style,
              api: api, night: night)?['android:windowBackground'],
        );
        if (background == null ||
            !_hasImage(background, api: api, night: night)) {
          blank.add('API $api, $mode mode: $background');
        }
      }
    }
    expect(
      blank,
      isEmpty,
      reason: 'The launch background that the system shows below Android 12 '
          'has an image, in each mode and at each version of the system.',
    );
  });

  test('below Android 12, the two modes of the device look different', () {
    final style = _launchStyle();
    List<String> look({required bool night}) {
      final background = _referenced(
        _styleItems(
          style,
          api: _belowAndroid12.last,
          night: night,
        )?['android:windowBackground'],
      );
      return _contentOf(
        background ?? '',
        api: _belowAndroid12.last,
        night: night,
      );
    }

    expect(
      look(night: true),
      isNot(look(night: false)),
      reason: 'The splash role has an image for each mode of the device.',
    );
  });

  test(
      'from Android 12 on, the splash screen of the system has a background '
      'and an icon in each mode, and the two modes differ', () {
    final style = _launchStyle();
    final looks = <bool, (String, List<String>)>{};
    for (final night in const [false, true]) {
      final mode = night ? 'dark' : 'light';
      final items = _styleItems(style, api: _android12, night: night);
      final background = items?['android:windowSplashScreenBackground'];
      final icon =
          _referenced(items?['android:windowSplashScreenAnimatedIcon']);
      expect(
        background,
        isNotNull,
        reason: 'From Android 12 on, the theme of the activity names the '
            'background of the splash screen in the $mode mode.',
      );
      expect(
        icon != null && _hasImage(icon, api: _android12, night: night),
        isTrue,
        reason: 'From Android 12 on, the theme of the activity names an icon '
            'of the splash screen with an image in the $mode mode.',
      );
      looks[night] = (
        background!,
        _contentOf(icon!, api: _android12, night: night),
      );
    }
    expect(
      looks[true]!.$1 != looks[false]!.$1 ||
          looks[true]!.$2.join() != looks[false]!.$2.join(),
      isTrue,
      reason: 'The splash role has an image for each mode of the device.',
    );
  });

  test(
      'on iOS, the launch storyboard shows an image with an appearance for '
      'the dark mode, at a size that fits each scale', () {
    final name = _plistStrings(File(_infoPlist))['UILaunchStoryboardName'];
    expect(name, isNotNull, reason: 'Info.plist names a launch storyboard.');
    final storyboard = _inIosApp('$name.storyboard');
    expect(
      storyboard,
      isA<File>(),
      reason: 'The launch storyboard that Info.plist names is in the app.',
    );
    final document =
        XmlDocument.parse((storyboard! as File).readAsStringSync());
    final images = {
      for (final view in document.findAllElements('imageView'))
        view.getAttribute('image'),
    }.nonNulls;

    /// The entries of the image set of [image], or none without one.
    List<Map<String, Object?>> entriesOf(String image) {
      final set = _inIosApp('$image.imageset');
      if (set is! Directory) return const [];
      final contents = jsonDecode(
        File('${set.path}/Contents.json').readAsStringSync(),
      ) as Map<String, Object?>;
      return [
        for (final entry in contents['images']! as List<Object?>)
          if ((entry! as Map<String, Object?>)['filename'] != null)
            entry as Map<String, Object?>,
      ];
    }

    bool isDark(Map<String, Object?> entry) =>
        (entry['appearances'] as List<Object?>? ?? const []).any(
          (appearance) =>
              (appearance! as Map<String, Object?>)['value'] == 'dark',
        );

    final marks = [
      for (final image in images)
        if (entriesOf(image) case final entries when entries.any(isDark))
          if (_inIosApp('$image.imageset') case final Directory set)
            if (entries.every(
              (entry) =>
                  _showsSomething(File('${set.path}/${entry['filename']}')),
            ))
              (set, entries),
    ];
    expect(
      marks,
      isNotEmpty,
      reason: 'The launch storyboard shows an image that is more than one '
          'pixel wide and has an entry for the dark mode.',
    );
    for (final (set, entries) in marks) {
      for (final dark in const [false, true]) {
        final logicalWidths = {
          for (final entry in entries)
            if (isDark(entry) == dark)
              if (_pngWidth(
                File('${set.path}/${entry['filename']}').readAsBytesSync(),
              )
                  case final width?)
                width /
                    int.parse(
                      (entry['scale']! as String).replaceAll('x', ''),
                    ),
        };
        expect(
          logicalWidths.length,
          lessThanOrEqualTo(1),
          reason: 'Each file of ${set.path} is in the ratio of its scale: '
              '$logicalWidths.',
        );
      }
    }
  });
}
