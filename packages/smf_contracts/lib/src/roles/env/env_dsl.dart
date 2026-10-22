part of '../env.dart';

/// The form of the name of a key: UPPER_SNAKE_CASE of two words or more,
/// the first of which starts with a letter.
final RegExp _keyName = RegExp(r'^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+$');

/// The prefix of the names of the values that Flutter gives the app itself,
/// such as `FLUTTER_VERSION`.
const _flutterPrefix = 'FLUTTER_';

/// The longest description of a key, which [EnvRole.dotEnvFile] has as a
/// comment line of its own.
const _maxDescription = 100;

/// Names that no getter of `AppEnv` can have: the members of `Object`,
/// which every class has already.
const Set<String> _objectMembers = {
  'hashCode',
  'noSuchMethod',
  'runtimeType',
  'toString',
};

/// What the [EnvRole] takes from the app: an [EnvKey] from a module whose
/// code reads a value, and [EnvToolArguments] from the provider of the
/// role.
@immutable
sealed class EnvData {
  const EnvData();
}

/// A value that the code of its owner reads, which the developer of the app
/// fills in under the key [name] in [EnvRole.dotEnvFile]:
///
/// ```dart
/// envRole.data(
///   const EnvKey(
///     'REVENUECAT_APPLE_KEY',
///     description: 'The public API key of the App Store app in RevenueCat',
///   ),
/// )
/// ```
///
/// The data needs no condition, since it applies only when the role is
/// present. Code reads the value as `AppEnv.<getter>`, with the [getter] of
/// the key (see [EnvRole.appEnv]), or through a variable of
/// [EnvRole.varsOf].
@immutable
final class EnvKey extends EnvData {
  /// Creates the key [name], which [description] tells the developer of the
  /// app what to fill in under.
  const EnvKey(this.name, {required this.description});

  /// The name of the key, in UPPER_SNAKE_CASE of two words or more, such as
  /// `REVENUECAT_APPLE_KEY`.
  ///
  /// It starts with the id of its module in upper case and an underscore,
  /// such as `REVENUECAT_` for the module `revenuecat`. So the keys of two
  /// modules differ, and a developer sees in [EnvRole.dotEnvFile] whose
  /// each is. It does not
  /// start with `FLUTTER_`, under which Flutter gives the app values of its
  /// own, such as `FLUTTER_VERSION`.
  final String name;

  /// What the developer fills in under the key, as one line of at most 100
  /// characters without a backslash, such as `The public API key of the App
  /// Store app in RevenueCat`.
  ///
  /// It is the comment above the key in [EnvRole.dotEnvFile] and
  /// [EnvRole.exampleFile], and its description in the README of the app.
  final String description;

  /// The name of the static getter of `AppEnv` that returns the value: the
  /// key in lowerCamelCase, such as `revenuecatAppleKey` for
  /// `REVENUECAT_APPLE_KEY`.
  ///
  /// A key has two words or more, so its getter is never a reserved word of
  /// Dart. Keys whose words are cut differently can have one getter, such
  /// as `SHOP1_KEY` and `SHOP_1_KEY`; the role reports two such keys.
  String get getter => SmfNames.lowerCamelCase(name.toLowerCase());

  /// The name of the variable of [EnvRole.varsOf] that reads the value.
  String get _variable => 'env_${name.toLowerCase()}';

  /// Describes what is wrong with the key on its own, or returns an empty
  /// list. Whether its name starts with the id of its owner, and whether it
  /// differs from the other keys, is for the role to tell.
  List<String> problems() {
    final what = 'The key "$name"';
    final problems = <String>[];
    if (!_keyName.hasMatch(name)) {
      problems.add(
        '$what needs a name in UPPER_SNAKE_CASE of two words or more that '
        'starts with a letter, such as REVENUECAT_APPLE_KEY.',
      );
    } else if (name.startsWith(_flutterPrefix)) {
      problems.add(
        '$what starts with $_flutterPrefix, under which Flutter gives the app '
        'values of its own, such as FLUTTER_VERSION.',
      );
    } else if (_objectMembers.contains(getter)) {
      problems.add(
        '$what would be read as $_appEnv.$getter, which every Dart object '
        'has already.',
      );
    }
    if (description.trim().isEmpty) {
      problems.add('$what has no description.');
    } else if (description != description.trim() ||
        description.contains('\n') ||
        description.contains('\r')) {
      problems.add(
        '$what has a description that is not one line of text without '
        'spaces around it.',
      );
    }
    if (description.length > _maxDescription) {
      problems.add(
        '$what has a description of ${description.length} characters; at '
        'most $_maxDescription fit on its comment line in .env.',
      );
    }
    if (description.contains(r'\')) {
      problems.add(
        '$what has a backslash in its description, which mason removes '
        'before a line break and Markdown reads as an escape.',
      );
    }
    return problems;
  }

  @override
  String toString() => 'key $name';
}

/// The arguments that the provider of the [EnvRole] needs on the commands
/// of the `flutter` tool that build, run or test the app, so that the
/// values of [EnvRole.dotEnvFile] reach `AppEnv`:
///
/// ```dart
/// envRole.data(const EnvToolArguments(['--some-option=.env']))
/// ```
///
/// Only a provider of the role gives them, at most once, and a provider
/// that needs none gives none. Code that runs such commands takes them from
/// [EnvRole.toolArgumentsIn].
@immutable
final class EnvToolArguments extends EnvData {
  /// Creates the [arguments] of the provider.
  const EnvToolArguments(this.arguments);

  /// The arguments, in the order a command takes them, each one line that
  /// is not empty, since a tool may write them one on each line.
  final List<String> arguments;

  /// Describes what is wrong with the arguments, or returns an empty list.
  List<String> problems() => [
        if (arguments.any((argument) => argument.isEmpty))
          'An argument of the tool arguments of the $envRole is empty.',
        if (arguments.any(
          (argument) => argument.contains('\n') || argument.contains('\r'),
        ))
          'An argument of the tool arguments of the $envRole is not one line.',
      ];

  @override
  String toString() => 'tool arguments ${arguments.join(' ')}';
}

/// A key of the app: an [EnvKey] with its owner.
///
/// Obtain the keys of an app with [EnvRole.keysIn].
@immutable
final class AppEnvKey {
  const AppEnvKey._(this.owner, this.key);

  /// Who gave the app the key: a module, also for a key of its variant. A
  /// key of the template of a role, which the role refuses, has that
  /// template.
  final ContributionOrigin owner;

  /// The key.
  final EnvKey key;

  /// The name of the key; see [EnvKey.name].
  String get name => key.name;

  /// The description of the key; see [EnvKey.description].
  String get description => key.description;

  /// The getter of `AppEnv` that returns the value; see [EnvKey.getter].
  String get getter => key.getter;

  @override
  String toString() => '$key of ${_named(owner)}';
}

/// Who owns the keys that [origin] gave: a variant of a module gives the
/// keys of its module.
ContributionOrigin _ownerOf(ContributionOrigin origin) => switch (origin) {
      ModuleOrigin(:final module) => ModuleOrigin(module),
      _ => origin,
    };

/// How a message names [owner], who gave the app a key or generated a file
/// that reads one.
String _named(ContributionOrigin owner) => switch (owner) {
      ModuleOrigin(:final module) => 'the module $module',
      RoleTemplateOrigin(:final role) => 'the template of the $role',
      PipelineOrigin() => 'the $owner',
    };

/// The problems of [keys], the keys of the module whose id is [owner]:
/// those of each key on its own, a name that does not start with the id of
/// the module, two keys of one name, and two keys with one getter.
List<String> _keyProblems(List<EnvKey> keys, String owner) {
  final prefix = '${owner.toUpperCase()}_';
  final problems = <String>[];
  final names = <String>{};
  final getters = <String, String>{};
  for (final key in keys) {
    problems.addAll(key.problems());
    final valid = _keyName.hasMatch(key.name);
    if (valid && !key.name.startsWith(prefix)) {
      problems.add(
        'The key "${key.name}" does not start with $prefix, the id of its '
        'owner in upper case and an underscore.',
      );
    }
    if (!names.add(key.name)) {
      problems.add('Two keys are named "${key.name}".');
    } else if (valid) {
      final other = getters.putIfAbsent(key.getter, () => key.name);
      if (other != key.name) {
        problems.add(
          'The keys "$other" and "${key.name}" would both be read as '
          '$_appEnv.${key.getter}.',
        );
      }
    }
  }
  return problems;
}
