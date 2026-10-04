// A test that continuous integration runs in the apps with the
// shared_preferences module, on the real shared_preferences package, whose
// platform side keeps the values in memory (shared_preferences_mocks.dart):
// what the preferences of the module save reaches the package under the
// same key and with the same type, what they remove is gone from it, and
// they read what the package has when they are opened, a number only as the
// type that it was saved as.
//
// When the preferences are opened, a platform returns a list in a form of
// its own, which the platform side in memory does not: iOS a list of
// objects, and Android a list that casts each item to a text as it is read.
// So the test also opens the preferences over a platform side in memory
// that returns its lists in each of these forms, and runs the probe of the
// module over each (integration_test/shared_preferences/probe.dart), which
// the start check runs on a device, where the platform side is the real
// one.
//
// It uses the preferences of the module, which openSharedAppPreferences()
// opens, and runs none of the start-up of the app. What the package has, it
// reads through SharedPreferencesAsync of the package, which reads the
// platform side without a cache. The matrix sets up the mocks of the
// platform side of every module of the app before the tests, those of
// shared_preferences among them. The keys are under the id of the module.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart'
    show GetPreferencesParameters;
import 'package:{{app_name}}/core/preferences/shared_app_preferences.dart';

import '../integration_test/shared_preferences/probe.dart';

/// A platform side that keeps what is saved in memory, and returns each
/// list of it in the form that a platform returns a list in when the
/// preferences are opened: what [_formOf] makes of its items.
base class _PlatformLists extends InMemorySharedPreferencesAsync {
  _PlatformLists(this._formOf, [Map<String, Object> saved = const {}])
      : super.withData(saved);

  final Object Function(List<Object?> items) _formOf;

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async =>
      {
        for (final MapEntry(:key, :value)
            in (await super.getPreferences(parameters, options)).entries)
          key: value is List<Object?> ? _formOf(List.of(value)) : value,
      };
}

/// The forms of a list that the platforms return when the preferences are
/// opened, by the name of the platform.
final Map<String, Object Function(List<Object?> items)> _platformLists = {
  // A list of objects, as Flutter decodes the list of a message of the
  // platform.
  'iOS': List<Object?>.of,
  // The list that the package decodes from the JSON that it saves a list
  // as, which casts each item to a text as it is read, and so throws on an
  // item that is none.
  'Android': (items) =>
      (jsonDecode(jsonEncode(items)) as List<Object?>).cast<String>(),
};

/// Puts [platform] in place of the platform side of the package for the
/// rest of the test.
void _use(SharedPreferencesAsyncPlatform platform) {
  final before = SharedPreferencesAsyncPlatform.instance;
  addTearDown(() => SharedPreferencesAsyncPlatform.instance = before);
  SharedPreferencesAsyncPlatform.instance = platform;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'a value that the preferences save reaches shared_preferences under '
      'the same key and with the same type', () async {
    final preferences = await openSharedAppPreferences();
    final package = SharedPreferencesAsync();

    await preferences.setString('shared_preferences.text', 'text');
    await preferences.setBool('shared_preferences.flag', true);
    await preferences.setInt('shared_preferences.count', 3);
    await preferences.setDouble('shared_preferences.ratio', 1.5);
    await preferences.setStringList('shared_preferences.list', ['a', 'b']);

    // The reads of the package throw on a value of another type.
    expect(await package.getString('shared_preferences.text'), 'text');
    expect(await package.getBool('shared_preferences.flag'), isTrue);
    expect(await package.getInt('shared_preferences.count'), 3);
    expect(await package.getDouble('shared_preferences.ratio'), 1.5);
    expect(
      await package.getStringList('shared_preferences.list'),
      ['a', 'b'],
    );
  });

  test('a key that the preferences remove is gone from shared_preferences',
      () async {
    final preferences = await openSharedAppPreferences();
    final package = SharedPreferencesAsync();
    await preferences.setInt('shared_preferences.removed', 3);
    expect(await package.containsKey('shared_preferences.removed'), isTrue);

    await preferences.remove('shared_preferences.removed');

    expect(await package.containsKey('shared_preferences.removed'), isFalse);
    expect(preferences.getInt('shared_preferences.removed'), isNull);
  });

  test(
      'the preferences read what shared_preferences has when they are '
      'opened, each value as its type', () async {
    final package = SharedPreferencesAsync();
    await package.setString('shared_preferences.earlier_text', 'text');
    await package.setBool('shared_preferences.earlier_flag', false);
    await package.setInt('shared_preferences.earlier_count', 5);
    await package.setDouble('shared_preferences.earlier_ratio', 2.5);
    await package.setStringList('shared_preferences.earlier_list', ['c']);

    final preferences = await openSharedAppPreferences();

    expect(preferences.getString('shared_preferences.earlier_text'), 'text');
    expect(preferences.getBool('shared_preferences.earlier_flag'), isFalse);
    expect(preferences.getInt('shared_preferences.earlier_count'), 5);
    expect(preferences.getDouble('shared_preferences.earlier_ratio'), 2.5);
    expect(
      preferences.getStringList('shared_preferences.earlier_list'),
      ['c'],
    );
    // Not as another type, on which the reads of the package throw.
    expect(preferences.getInt('shared_preferences.earlier_text'), isNull);
    expect(preferences.getString('shared_preferences.earlier_list'), isNull);
    expect(
      preferences.getStringList('shared_preferences.earlier_text'),
      isNull,
    );
  });

  test(
      'a number is read only as the type that it was saved as, in the run '
      'that saved it and once the preferences are opened again', () async {
    final preferences = await openSharedAppPreferences();
    await preferences.setInt('shared_preferences.whole_count', 2);
    // A whole number, saved as a double.
    await preferences.setDouble('shared_preferences.whole_ratio', 2);

    for (final (opened, run) in [
      (preferences, 'in the run that saved the numbers'),
      (await openSharedAppPreferences(), 'once they are opened again'),
    ]) {
      expect(
        opened.getInt('shared_preferences.whole_count'),
        isA<int>().having((value) => value, 'value', 2),
        reason: run,
      );
      expect(
        opened.getDouble('shared_preferences.whole_count'),
        isNull,
        reason: 'An int is not read as a double, $run.',
      );
      expect(
        opened.getDouble('shared_preferences.whole_ratio'),
        isA<double>().having((value) => value, 'value', 2.0),
        reason: run,
      );
      expect(
        opened.getInt('shared_preferences.whole_ratio'),
        isNull,
        reason: 'A double is not read as an int, $run.',
      );
    }
  });

  for (final MapEntry(key: platform, value: formOf) in _platformLists.entries) {
    test(
        'the preferences read a list in the form that $platform returns it '
        'in when they are opened, and none with an item that is no text',
        () async {
      _use(
        _PlatformLists(formOf, {
          'shared_preferences.platform_list': ['a', 'b'],
          'shared_preferences.platform_empty_list': <String>[],
          'shared_preferences.platform_mixed_list': ['a', 1],
        }),
      );

      final preferences = await openSharedAppPreferences();

      expect(
        preferences.getStringList('shared_preferences.platform_list'),
        isA<List<String>>().having((list) => list, 'items', ['a', 'b']),
        reason: 'A list of texts that $platform returns is read as it was '
            'saved.',
      );
      expect(
        preferences.getStringList('shared_preferences.platform_empty_list'),
        isEmpty,
      );
      expect(
        preferences.getStringList('shared_preferences.platform_mixed_list'),
        isNull,
        reason: 'A list with an item that is no text is no list of texts, '
            'and its read does not throw.',
      );
      // No other read takes a list for its type.
      expect(
        preferences.getString('shared_preferences.platform_list'),
        isNull,
      );
    });

    test(
        'the probe of the module finds no problem over a platform side that '
        'returns lists as $platform does', () async {
      _use(_PlatformLists(formOf));

      expect(
        // As the start check runs it on a device; it waits for no screen.
        await probeSharedPreferences(() async {}),
        isEmpty,
        reason: 'Preferences that are opened anew read what was saved, each '
            'value as its type, as $platform returns it.',
      );
    });
  }
}
