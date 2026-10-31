// A test that continuous integration runs in the apps with the app icon role,
// whichever module provides it: once the step of the provider has run, the
// native projects of the app have the icon that its two source images make.
//
// The step changes only the native files of the app, so neither the rules of
// the role nor a snapshot see what it did, and nothing of an icon shows in
// Dart. So the test reads the files of the app from the directory of the app,
// in which flutter test runs. It starts no app.
//
// It asks only what every provider has to give the two systems, and no form
// that one tool writes: an Android icon below API 26, an adaptive icon from
// API 26 on, and on iOS an icon set for each name of the build configurations.
// One name for all of them is for the test of the provider.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// The directory of the resources of the Android app.
const _resources = 'android/app/src/main/res';

/// The directory of the asset catalog of the iOS app.
const _catalog = 'ios/Runner/Assets.xcassets';

/// The densities of Android and the side, in pixels, of a launcher icon of 48
/// dp in each.
const _densities = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// The bytes of the file at [path], which the test fails without.
Uint8List _bytesOf(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'The app has no $path.');
  return file.readAsBytesSync();
}

/// The text of the file at [path], which the test fails without.
String _textOf(String path) => utf8.decode(_bytesOf(path));

/// The width and the height of the PNG image [bytes] of the file at [path].
(int, int) _sizeOf(Uint8List bytes, String path) {
  final data = ByteData.sublistView(bytes);
  expect(
    bytes.length > 24 && String.fromCharCodes(bytes, 12, 16) == 'IHDR',
    isTrue,
    reason: '$path is no PNG image.',
  );
  return (data.getUint32(16), data.getUint32(20));
}

/// Whether the PNG image [bytes] can have a pixel that is not opaque: its
/// colour type has an alpha channel, or it has a `tRNS` chunk.
bool _mayHaveAlpha(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final colorType = bytes[25];
  if (colorType == 4 || colorType == 6) return true;
  for (var at = 8; at + 8 <= bytes.length;) {
    final length = data.getUint32(at);
    if (String.fromCharCodes(bytes, at + 4, at + 8) == 'tRNS') return true;
    at += 12 + length;
  }
  return false;
}

/// The pixels of the PNG image [bytes], four bytes each.
Future<ByteData> _pixelsOf(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final pixels = await frame.image.toByteData();
  frame.image.dispose();
  codec.dispose();
  return pixels!;
}

/// The value of the attribute [name] of [element], whatever the prefix of its
/// namespace in the file is.
String? _androidAttribute(XmlElement element, String name) => element.attributes
    .where((attribute) => attribute.name.local == name)
    .map((attribute) => attribute.value)
    .firstOrNull;

/// Checks that [reference], such as `@color/name` or `@drawable/name`, of the
/// layer [layer] of the adaptive icon names a resource of the app: a colour in
/// a file of `values/`, or an image for each density or one file for all.
void _expectResolves(String layer, String? reference) {
  final match = RegExp(r'^@(\w+)/(\w+)$').firstMatch(reference ?? '');
  expect(
    match,
    isNotNull,
    reason: 'The $layer of the adaptive icon names no resource: $reference.',
  );
  final (type, name) = (match![1]!, match[2]!);
  if (type == 'color') {
    final colors = [
      for (final entity in Directory('$_resources/values').listSync())
        if (entity is File && entity.path.endsWith('.xml'))
          ...XmlDocument.parse(entity.readAsStringSync())
              .findAllElements('color')
              .map((element) => element.getAttribute('name')),
    ];
    expect(
      colors,
      contains(name),
      reason: 'The $layer of the adaptive icon is a colour that the app lacks.',
    );
    return;
  }
  bool has(String directory) =>
      File('$_resources/$directory/$name.png').existsSync() ||
      File('$_resources/$directory/$name.webp').existsSync() ||
      File('$_resources/$directory/$name.xml').existsSync();
  expect(
    has(type) || _densities.keys.every((density) => has('$type-$density')),
    isTrue,
    reason: 'The $layer of the adaptive icon is an image that the app lacks '
        'for a density.',
  );
}

/// The drawable of the layer [layer] of the adaptive icon [icon]: its
/// attribute, or that of the element inside it, such as an inset.
String? _drawableOf(XmlElement icon, String layer) {
  final element = icon.findElements(layer).firstOrNull;
  expect(element, isNotNull, reason: 'The adaptive icon has no $layer.');
  return _androidAttribute(element!, 'drawable') ??
      element.childElements
          .map((child) => _androidAttribute(child, 'drawable'))
          .firstOrNull;
}

/// The names of the icon of the app in the build configurations of the Xcode
/// project.
Set<String> _iconNames() => {
      for (final match
          in RegExp(r'ASSETCATALOG_COMPILER_APPICON_NAME = "?([^";]*)"?;')
              .allMatches(_textOf('{{xcode_project_file}}')))
        match[1]!,
    };

/// The entries of the `Contents.json` of the icon set [name].
List<Map<String, Object?>> _entriesOf(String name) {
  final contents = jsonDecode(
    _textOf('$_catalog/$name.appiconset/Contents.json'),
  ) as Map<String, Object?>;
  return (contents['images']! as List<Object?>).cast();
}

/// The side in pixels of [entry], an entry of a `Contents.json`.
int _sideOf(Map<String, Object?> entry) {
  final size = double.parse((entry['size']! as String).split('x').first);
  final scale = double.parse((entry['scale'] as String? ?? '1x').split('x')[0]);
  return (size * scale).round();
}

/// The paths of the images that the App Store takes as the icon: the entries
/// of 1024 pixels of each icon set, for the look that has no appearance.
List<String> _storeIcons() => [
      for (final name in _iconNames())
        for (final entry in _entriesOf(name))
          if (_sideOf(entry) == 1024 && entry['appearances'] == null)
            '$_catalog/$name.appiconset/${entry['filename']}',
    ];

void main() {
  group('the sources of the icon', () {
    test('are the two images that the role names, of 1024 by 1024', () {
      for (final path in const ['{{image_file}}', '{{foreground_file}}']) {
        expect(_sizeOf(_bytesOf(path), path), (1024, 1024), reason: path);
      }
    });

    test('are an opaque image and one with a transparent background', () {
      expect(
        _mayHaveAlpha(_bytesOf('{{image_file}}')),
        isFalse,
        reason: 'The App Store refuses an icon with alpha.',
      );
      expect(
        _mayHaveAlpha(_bytesOf('{{foreground_file}}')),
        isTrue,
        reason: 'The logo of an adaptive icon is on a transparent background.',
      );
    });
  });

  group('on Android', () {
    /// The type and the name of the resource of the icon in the manifest.
    (String, String) iconOfManifest() {
      final manifest = XmlDocument.parse(_textOf('{{android_manifest_file}}'));
      final application = manifest.findAllElements('application').single;
      final match = RegExp(r'^@(\w+)/(\w+)$')
          .firstMatch(_androidAttribute(application, 'icon') ?? '');
      expect(
        match,
        isNotNull,
        reason: 'The application of the manifest names no icon.',
      );
      return (match![1]!, match[2]!);
    }

    test('the manifest names an icon with an image for each density', () {
      final (type, name) = iconOfManifest();
      for (final MapEntry(key: density, value: side) in _densities.entries) {
        final path = '$_resources/$type-$density/$name.png';
        expect(_sizeOf(_bytesOf(path), path), (side, side), reason: path);
      }
    });

    test(
        'the icon is adaptive from API 26 on, with a background and a '
        'foreground that the app has', () {
      final (type, name) = iconOfManifest();
      final path = '$_resources/$type-anydpi-v26/$name.xml';
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'An app whose step did not run keeps the icon of flutter '
            'create, which has no adaptive icon.',
      );
      final icon = XmlDocument.parse(_textOf(path)).rootElement;
      expect(icon.name.local, 'adaptive-icon');
      _expectResolves('background', _drawableOf(icon, 'background'));
      _expectResolves('foreground', _drawableOf(icon, 'foreground'));
    });
  });

  group('on iOS', () {
    test('each build configuration names an icon set of the app', () {
      final names = _iconNames();
      expect(names, isNotEmpty);
      for (final name in names) {
        expect(
          File('$_catalog/$name.appiconset/Contents.json').existsSync(),
          isTrue,
          reason: 'The Xcode project names the icon $name, and the app has no '
              'such icon set.',
        );
      }
    });

    test('each image of an icon set has the size of its entry', () {
      for (final name in _iconNames()) {
        final entries = _entriesOf(name);
        expect(entries, isNotEmpty);
        for (final entry in entries) {
          final path = '$_catalog/$name.appiconset/${entry['filename']}';
          final side = _sideOf(entry);
          expect(_sizeOf(_bytesOf(path), path), (side, side), reason: path);
        }
      }
    });

    test('the icon for the App Store has no alpha', () {
      final icons = _storeIcons();
      expect(icons, isNotEmpty, reason: 'No icon set has an icon of 1024.');
      for (final path in icons) {
        expect(
          _mayHaveAlpha(_bytesOf(path)),
          isFalse,
          reason: 'The App Store refuses an icon with alpha: $path.',
        );
      }
    });

    test('the icon for the App Store has the pixels of the source', () async {
      final source = await _pixelsOf(_bytesOf('{{image_file}}'));
      for (final path in _storeIcons()) {
        final pixels = await _pixelsOf(_bytesOf(path));
        expect(pixels.lengthInBytes, source.lengthInBytes, reason: path);
        // A tool may encode the image anew, but not change it.
        var different = 0;
        for (var at = 0; at < source.lengthInBytes; at++) {
          if ((pixels.getUint8(at) - source.getUint8(at)).abs() > 2) {
            different++;
          }
        }
        expect(
          different,
          0,
          reason: '$path is made from the image of the role, {{image_file}}. '
              'An app whose step did not run keeps the icon of flutter create.',
        );
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
