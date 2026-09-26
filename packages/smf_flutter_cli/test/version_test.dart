import 'dart:io';

import 'package:smf_flutter_cli/version.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('packageVersion is the version of the pubspec', () {
    final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as Map;

    expect(packageVersion, pubspec['version']);
  });
}
