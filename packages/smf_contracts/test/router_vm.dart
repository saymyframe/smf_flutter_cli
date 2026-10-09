import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';

/// A stand-in for the part of Flutter's foundation library that the code
/// of the guards uses, with the signatures of Flutter 3.44.
const vmFoundation = '''
typedef VoidCallback = void Function();

abstract class Listenable {
  const Listenable();

  factory Listenable.merge(Iterable<Listenable?> listenables) = _Merged;

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);
}

abstract class ValueListenable<T> extends Listenable {
  const ValueListenable();

  T get value;
}

class ValueNotifier<T> implements ValueListenable<T> {
  ValueNotifier(this._value);

  final List<VoidCallback> _listeners = [];

  T _value;

  @override
  T get value => _value;

  set value(T value) {
    if (value == _value) return;
    _value = value;
    for (final listener in [..._listeners]) {
      listener();
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

class _Merged extends Listenable {
  _Merged(this._listenables);

  final Iterable<Listenable?> _listenables;

  @override
  void addListener(VoidCallback listener) {
    for (final listenable in _listenables) {
      listenable?.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final listenable in _listenables) {
      listenable?.removeListener(listener);
    }
  }
}
''';

/// A stand-in for the part of Flutter's widgets library that the files of
/// the router role use: what it exports of the foundation library, without
/// `ValueListenable`, as Flutter 3.44 does.
const vmWidgets = '''
export 'foundation.dart' show Listenable, ValueNotifier, VoidCallback;

abstract class BuildContext {}

class RouterConfig<T> {}
''';

/// What the script [main] prints in an app with guards of the routes: the
/// app has the files that the template of the router role renders from
/// [data], stand-ins for Flutter, and [files], the files of the functions
/// of the guards, each by its path in the app. print ends a line with \r\n
/// on Windows.
Future<String> printedByGuards(
  String main, {
  required List<RoleData<Object>> data,
  required Map<String, String> files,
}) async {
  final directory = await Directory.systemTemp.createTemp('smf_guards');
  addTearDown(() => directory.delete(recursive: true));
  final rendered = await renderTemplate(routerRole, data: data);
  final all = {
    'flutter/lib/foundation.dart': vmFoundation,
    'flutter/lib/widgets.dart': vmWidgets,
    for (final MapEntry(key: path, value: text) in rendered.files.entries)
      'app/$path': text,
    // The file of the provider of the role, which no test here calls.
    'app/${RouterRole.appRouterFactoryFile}': '''
import 'app_router.dart';

AppRouter createAppRouter() => throw UnimplementedError();
''',
    for (final MapEntry(key: path, value: text) in files.entries)
      'app/$path': text,
    'app/bin/main.dart': main,
    'app/.dart_tool/package_config.json': jsonEncode({
      'configVersion': 2,
      'packages': [
        for (final (name, root) in [
          ('my_app', '../'),
          ('flutter', '../../flutter/'),
        ])
          {
            'name': name,
            'rootUri': root,
            'packageUri': 'lib/',
            'languageVersion': '3.6',
          },
      ],
    }),
  };
  for (final MapEntry(key: path, value: text) in all.entries) {
    File('${directory.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['run', '${directory.path}/app/bin/main.dart'],
  );

  expect(result.stderr, isEmpty);
  return (result.stdout as String).replaceAll('\r\n', '\n');
}

/// The lines that a script printed below its heading [heading], up to the
/// next heading: a heading is a line that does not start with a space.
String sectionOf(String printed, String heading) {
  final lines = printed.split('\n');
  final start = lines.indexOf(heading);
  expect(start, isNonNegative, reason: 'The script prints "$heading".');
  return lines
      .skip(start + 1)
      .takeWhile((line) => line.startsWith(' '))
      .map((line) => '$line\n')
      .join();
}
