// The two images of the brick, as the module generates them: what the role
// asks of them, and what the safe zone of an adaptive icon asks of the logo.
@TestOn('vm')
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_launcher_icons/smf_launcher_icons.dart';
import 'package:smf_launcher_icons/src/brand.dart';
import 'package:smf_launcher_icons/src/readme.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The side of both images.
const _side = 1024;

/// The colour of the logo in both images.
const _ink = (0xF1, 0xF1, 0xE8);

/// [hex], such as `#0F3326`, as its red, green and blue.
(int, int, int) _rgbOf(String hex) {
  final value = int.parse(hex.substring(1), radix: 16);
  return (value >> 16, (value >> 8) & 0xFF, value & 0xFF);
}

/// The colour of [pixel].
(int, int, int) _colorOf(Pixel pixel) =>
    (pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());

/// The share of the width of the foreground that the circle has which every
/// launcher keeps: an adaptive icon has 108 dp, of which it keeps a circle of
/// 66 dp, and an inset of [inset] percent on each side leaves that much less
/// of the 108 dp for the image.
double _safeShare(int inset) => 66 / (108 * (1 - 2 * inset / 100));

/// The largest distance from the centre of [image], as a share of its width,
/// of a pixel that shows anything.
double _reachOf(Image image) {
  var reach = 0.0;
  final center = image.width / 2;
  for (final pixel in image) {
    if (pixel.a == 0) continue;
    final x = (pixel.x + (pixel.x < center ? 0 : 1) - center).abs();
    final y = (pixel.y + (pixel.y < center ? 0 : 1) - center).abs();
    reach = max(reach, sqrt(x * x + y * y));
  }
  return reach * 2 / image.width;
}

void main() {
  late Image icon;
  late Image foreground;
  late int inset;

  setUpAll(() async {
    final result = await ContractHarness(
      ModuleRegistry(const [FlutterCoreModule(), LauncherIconsModule()]),
    ).check(
      const ContractCase(
        'launcher_icons',
        requested: [LauncherIconsModule.id],
      ),
    );
    final files = result.app!.files;
    Image decoded(String path) =>
        decodePng(Uint8List.fromList(files[path]!.bytes))!;
    icon = decoded(AppIconRole.imageFile);
    foreground = decoded(AppIconRole.foregroundFile);
    final config = loadYaml(files[configFile]!.text) as YamlMap;
    final tool = config['flutter_launcher_icons'] as YamlMap;
    inset = tool['adaptive_icon_foreground_inset'] as int;
  });

  group('the image of the icon', () {
    test('is square, of the size that the role asks for', () {
      expect((icon.width, icon.height), (_side, _side));
    });

    test('has no alpha channel, which the App Store would refuse', () {
      expect(icon.numChannels, 3);
      expect(icon.hasPalette, isFalse);
    });

    test('is the colour of the background to each corner', () {
      for (final (x, y) in const [
        (0, 0),
        (_side - 1, 0),
        (0, _side - 1),
        (_side - 1, _side - 1),
      ]) {
        expect(_colorOf(icon.getPixel(x, y)), _rgbOf(iconBackground));
      }
    });

    test('shows the logo in its colour', () {
      expect(icon.where((pixel) => _colorOf(pixel) == _ink), isNotEmpty);
    });
  });

  group('the foreground', () {
    test('is square, of the size that the role asks for', () {
      expect((foreground.width, foreground.height), (_side, _side));
    });

    test('shows the logo in its colour, on a transparent background', () {
      expect(foreground.numChannels, 4);
      for (final (x, y) in const [
        (0, 0),
        (_side - 1, 0),
        (0, _side - 1),
        (_side - 1, _side - 1),
      ]) {
        expect(foreground.getPixel(x, y).a, 0);
      }
      expect(foreground.getPixel(_side ~/ 2, 0).a, 0);
      for (final pixel in foreground) {
        if (pixel.a > 0) {
          expect(_colorOf(pixel), _ink);
        }
      }
      expect(foreground.where((pixel) => pixel.a == 255), isNotEmpty);
    });

    test('keeps the logo inside the circle that every launcher keeps', () {
      expect(_safeShare(inset), closeTo(0.9, 0.01));
      expect(
        _reachOf(foreground),
        lessThanOrEqualTo(_safeShare(inset)),
        reason: 'A launcher cuts what is outside that circle.',
      );
    });
  });
}
