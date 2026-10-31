@TestOn('vm')
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_native_splash/smf_native_splash.dart';
import 'package:test/test.dart';

/// The canvas of each image, which Android 12 and later want.
const _canvas = 1152;

/// The radius of the circle that Android 12 and later keep of the canvas: two
/// thirds of its width.
const double _keptRadius = _canvas / 3;

/// The image of the app at [path], as the brick of the module has it.
img.Image _image(String path) => img.decodePng(
      File('bricks/native_splash/__brick__/$path').readAsBytesSync(),
    )!;

/// The colour of the hexadecimal text [colour], such as `#F1F1E8`, as the
/// values of its channels.
List<int> _channels(String colour) => [
      for (var start = 1; start < 7; start += 2)
        int.parse(colour.substring(start, start + 2), radix: 16),
    ];

/// The contrast of two colours by the formula of WCAG.
double _contrast(List<int> a, List<int> b) {
  double luminance(List<int> colour) {
    final linear = [
      for (final channel in colour)
        if (channel / 255 <= 0.03928)
          channel / 255 / 12.92
        else
          math.pow((channel / 255 + 0.055) / 1.055, 2.4).toDouble(),
    ];
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2];
  }

  final (x, y) = (luminance(a), luminance(b));
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// What is wrong with the mark [image] on a background of the colour
/// [background]: the canvas, the transparent background, the one colour of
/// the ink, its contrast with the background, and ink outside the circle that
/// Android 12 and later keep.
List<String> _problemsOf(img.Image image, String background) {
  final problems = <String>[];
  if (image.width != _canvas || image.height != _canvas) {
    problems.add('The canvas is ${image.width} by ${image.height}.');
  }
  if (!image.hasAlpha) problems.add('The image has no alpha.');
  final colours = <List<int>>{};
  var ink = 0;
  var outside = 0;
  for (final pixel in image) {
    if (pixel.a == 0) continue;
    ink++;
    if (colours.every(
      (c) => c[0] != pixel.r || c[1] != pixel.g || c[2] != pixel.b,
    )) {
      colours.add([pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()]);
    }
    final distance = math.sqrt(
      math.pow(pixel.x + 0.5 - _canvas / 2, 2) +
          math.pow(pixel.y + 0.5 - _canvas / 2, 2),
    );
    if (distance > _keptRadius) outside++;
  }
  if (ink == 0 || ink == image.width * image.height) {
    problems.add('$ink pixels have ink: the background is not transparent.');
  }
  if (outside > 0) {
    problems.add('$outside pixels of ink are outside the circle.');
  }
  if (colours.length != 1) {
    problems.add('The ink has ${colours.length} colours.');
  } else if (_contrast(colours.single, _channels(background)) < 3) {
    problems.add(
      'The ink ${colours.single} does not show on $background.',
    );
  }
  return problems;
}

void main() {
  test('the mark for the light mode shows on the light background', () {
    expect(
      _problemsOf(_image(SplashRole.lightImageFile), splashLightBackground),
      isEmpty,
    );
  });

  test('the mark for the dark mode shows on the dark background', () {
    expect(
      _problemsOf(_image(SplashRole.darkImageFile), splashDarkBackground),
      isEmpty,
    );
  });

  test('a mark for one mode does not show on the background of the other', () {
    expect(
      _problemsOf(_image(SplashRole.lightImageFile), splashDarkBackground),
      contains(contains('does not show')),
    );
    expect(
      _problemsOf(_image(SplashRole.darkImageFile), splashLightBackground),
      contains(contains('does not show')),
    );
  });

  test('an opaque image, or a mark outside the circle, is reported', () {
    final opaque = img.Image(width: _canvas, height: _canvas);
    expect(
      _problemsOf(opaque, splashLightBackground),
      contains('The image has no alpha.'),
    );
    final wide = img.Image(width: _canvas, height: _canvas, numChannels: 4)
      ..setPixelRgba(0, _canvas ~/ 2, 15, 51, 38, 255);
    expect(
      _problemsOf(wide, splashLightBackground),
      contains('1 pixels of ink are outside the circle.'),
    );
  });
}
