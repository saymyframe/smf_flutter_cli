/// What the tests that CI runs with an app that SMF generated, such as each
/// app with every module, read of the pubspec of the app.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

/// Whether the app in the directory [app] depends on the package
/// [package], by the dependencies of its pubspec.yaml rather than its dev
/// dependencies: such as on firebase_core, which gives flutterfire the app
/// to configure.
bool dependsOn(String app, String package) =>
    switch (loadYaml(File('$app/pubspec.yaml').readAsStringSync())) {
      {'dependencies': final YamlMap dependencies} =>
        dependencies.containsKey(package),
      _ => false,
    };
