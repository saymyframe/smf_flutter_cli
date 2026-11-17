import 'package:flutter/foundation.dart';

/// The values of remote config that the code of the app reads: a getter for
/// each parameter of the app, which returns the value that the backend gave
/// the parameter, or its default while the backend gives none.
///
/// Add a parameter: give it a default in [defaults] and a getter, and create
/// it in the backend of the provider with the same name and type. Every value
/// reaches every installation that fetches it, where anyone can read it, so
/// never put a secret into remote config.
@immutable
final class RemoteValues {
  const RemoteValues._(this._values);

  /// Each parameter of the app by name, with the value that the app reads
  /// while the backend gives none, whose type is the type of the parameter:
  /// a `String`, a `bool`, an `int` or a `double`.
  static const Map<String, Object> defaults = {{{remote_config_defaults}}};

  /// The values while the backend gives none: the [defaults].
  static const initial = RemoteValues._(defaults);

  /// The values of [texts], the active values that the backend gave, by
  /// parameter: each parameter of the app takes its text as the type of its
  /// default takes it, and its default when [texts] lacks it or when the type
  /// does not take the text, which [onInvalid] is told of.
  ///
  /// A `bool` takes `true` and `false`, in any case; an `int` what
  /// [int.tryParse] takes; a `double` a finite number that [double.tryParse]
  /// takes; and a `String` any text.
  factory RemoteValues.of(
    Map<String, String> texts, {
    void Function(String parameter, String text)? onInvalid,
  }) {
    final values = <String, Object>{};
    for (final MapEntry(key: parameter, value: fallback) in defaults.entries) {
      final text = texts[parameter];
      final value = text == null ? fallback : _parsed(text, fallback);
      if (text != null && value == null) onInvalid?.call(parameter, text);
      values[parameter] = value ?? fallback;
    }
    return RemoteValues._(values);
  }

  /// [text] as a value of the type of [fallback], or `null` if that type does
  /// not take it.
  static Object? _parsed(String text, Object fallback) => switch (fallback) {
    bool() => switch (text.toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => null,
    },
    int() => int.tryParse(text),
    double() => switch (double.tryParse(text)) {
      final number? when number.isFinite => number,
      _ => null,
    },
    _ => text,
  };

  final Map<String, Object> _values;
{{{remote_config_getters}}}

  @override
  bool operator ==(Object other) =>
      other is RemoteValues &&
      defaults.keys.every(
        (parameter) => _values[parameter] == other._values[parameter],
      );

  @override
  int get hashCode => Object.hashAll([
    for (final parameter in defaults.keys) _values[parameter],
  ]);

  @override
  String toString() => 'RemoteValues($_values)';
}
