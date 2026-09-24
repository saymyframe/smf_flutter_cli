import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/version.dart';
import 'package:test/test.dart';
import 'package:yaml_edit/yaml_edit.dart';

void main() {
  group('packageVersion', () {
    test('matches the version in pubspec.yaml', () async {
      final libDir = await Isolate.resolvePackageUri(
        Uri.parse('package:smf_flutter_cli/'),
      );
      final pubspec = File(
        p.join(p.dirname(libDir!.toFilePath()), 'pubspec.yaml'),
      );

      final version = YamlEditor(pubspec.readAsStringSync())
          .parseAt(['version']).value as String;

      expect(packageVersion, version);
    });
  });
}
