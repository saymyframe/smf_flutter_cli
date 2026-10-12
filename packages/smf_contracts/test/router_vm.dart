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

/// The library `answers.dart` next to the script of [printedByGuards]: how
/// a script writes what `GuardedNavigation` of the app answers a router
/// that knows a location by its URI.
///
/// Each switch names every answer and has no default, so a script does not
/// compile once `asked` or `changed` has an answer that the switch lacks.
const vmAnswers = r'''
import 'package:my_app/core/router/app_router.dart';

/// What `asked` answered: `shows it` for none, the location that the
/// router shows in place of its stack, the location that it shows over the
/// page on top with the routes of the flow that the request waits for, or
/// `nothing`.
String whenAsked(WhenAsked<String>? answer) => switch (answer) {
      null => 'shows it',
      ShowInstead(:final location) => location,
      ShowOver(:final location, :final flow) =>
        '$location over the page, while ${flow.join(', ')}',
      ShowNothing() => 'nothing',
    };

/// What `changed` answered: `stays` for none, the location that the router
/// shows in place of its stack, or how many pages on top it closes, and
/// whether it then drops the request that waits.
String whenChanged(WhenChanged<String>? answer) => switch (answer) {
      null => 'stays',
      ShowInstead(:final location) => location,
      ClosePages(:final pages, :final dropsRequest) =>
        'closes $pages${dropsRequest ? ', and drops the request' : ''}',
    };

/// The pages of a stack for `changed`, the one on top first: each of
/// [pages] is written as its route, or `-` for none, its location, and
/// `pushed` if the router can close it on its own.
List<({String? route, String location, bool pushed})> pagesOf(
  List<String> pages,
) =>
    [
      for (final page in pages.map((page) => page.split(' ')))
        (
          route: page[0] == '-' ? null : page[0],
          location: page[1],
          pushed: page.length > 2,
        ),
    ];

/// The routes of [pages] for `asked`, the one on top first.
List<String?> routesOf(List<String> pages) =>
    [for (final page in pagesOf(pages)) page.route];
''';

/// What the script [main] prints in an app with guards of the routes: the
/// app has the files that the template of the router role renders from
/// [data], stand-ins for Flutter, and [files], the files of the functions
/// of the guards, each by its path in the app. The script may import
/// `answers.dart` ([vmAnswers]). print ends a line with \r\n on Windows.
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
    'app/bin/answers.dart': vmAnswers,
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
