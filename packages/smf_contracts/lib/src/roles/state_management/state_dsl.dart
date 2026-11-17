part of '../state_management.dart';

/// The form of the name of an entry: lowerCamelCase of letters and digits
/// that starts with a lower-case letter.
final RegExp _entryName = RegExp(r'^[a-z][a-zA-Z0-9]*$');

/// The longest description of an entry, which is the doc of its bridge.
const _maxDescription = 100;

/// What the [StateManagementRole] takes from the app: a [SharedState] from
/// a module or the template of a role that keeps a value in a controller,
/// and [StateBridges] from the provider of the role.
@immutable
sealed class StateData {
  const StateData();
}

/// A value that a controller of the app keeps and that screens read, such
/// as the theme mode, which the state manager of the app follows through a
/// bridge of its own:
///
/// ```dart
/// stateManagementRole.data(
///   const SharedState(
///     'themeMode',
///     listenable: FunctionRef(
///       'themeModeListenable',
///       import: ImportRef.app('core/theme/theme_mode.dart'),
///     ),
///     type: TypeRef(
///       'ThemeMode',
///       import: ImportRef('package:flutter/material.dart'),
///     ),
///     description: 'The theme mode that the user selected; '
///         '`appThemeMode.choose()` changes it.',
///   ),
/// )
/// ```
///
/// Its owner, a module or the template of a role, feeds the role (see
/// [ModuleDescriptor.feeds] and [Role.feeds]): the data applies only where
/// the role is present, and the owner renders the same files whether it is
/// or not. The bridge is read-only: code changes the value only through the
/// controller, which [description] names.
@immutable
final class SharedState extends StateData {
  /// Creates the entry [name], whose value [listenable] returns as a
  /// `ValueListenable` of [type], or of [type] or `null` if [nullable].
  const SharedState(
    this.name, {
    required this.listenable,
    required this.type,
    required this.description,
    this.nullable = false,
  });

  /// The name of the entry, in lowerCamelCase of two words or more, such as
  /// `themeMode`.
  ///
  /// It starts with the id of its owner in lowerCamelCase, such as `theme`
  /// for the theme role or `myFeature` for the module `my_feature`, so the
  /// entries of two owners differ. A provider names the bridge of the entry
  /// after it, such as `themeModeProvider` or `ThemeModeCubit`.
  final String name;

  /// The top-level function of a file of the app, without parameters, that
  /// returns the controller of the value as a `ValueListenable`, such as
  /// `themeModeListenable` of `lib/core/theme/theme_mode.dart`: the same
  /// listenable at each call.
  ///
  /// Its file declares it with the return type [listenableType], which the
  /// rule `state_management.listenable_functions` checks. A developer may
  /// use the function with a `ValueListenableBuilder` too.
  final FunctionRef listenable;

  /// The type of the value, without `?`, with the import that declares it,
  /// or with none for a type of `dart:core`, such as `String`.
  final TypeRef type;

  /// Whether the value may be `null`, such as the language that the user
  /// chose, which is `null` while the app follows the device.
  final bool nullable;

  /// What the value is and which call changes it, as one line of at most
  /// 100 characters, such as ``The theme mode that the user selected;
  /// `appThemeMode.choose()` changes it.``.
  ///
  /// It is the doc of the bridge of the entry, which may have Markdown.
  final String description;

  /// The return type of [listenable] as its file declares it, such as
  /// `ValueListenable<ThemeMode>` or `ValueListenable<Locale?>`: the type
  /// as [type] names it, without a prefix.
  String get listenableType =>
      'ValueListenable<${type.name}${nullable ? '?' : ''}>';

  /// The type of the value as code that imports its file with [prefix]
  /// writes it, with `?` if it is [nullable].
  String typeWith(String? prefix) =>
      '${type.import == null ? type.name : type.codeWith(prefix)}'
      '${nullable ? '?' : ''}';

  /// Describes what is wrong with the entry on its own, or returns an empty
  /// list. Whether its name starts with the id of its owner, and whether it
  /// differs from the other entries, is for the role to tell.
  List<String> problems() {
    final what = 'The entry "$name"';
    final problems = <String>[];
    if (!_entryName.hasMatch(name) || !SmfNames.isDartIdentifier(name)) {
      problems.add(
        '$what needs a name in lowerCamelCase of letters and digits, such as '
        'themeMode.',
      );
    }
    problems.addAll(listenable.problems());
    if (!listenable.import.isAppFile) {
      problems.add(
        '$what reads its value through $listenable of '
        '${listenable.import.uri}, which is no file of the app.',
      );
    }
    problems.addAll(type.problems());
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
        'most $_maxDescription fit.',
      );
    }
    return problems;
  }

  @override
  String toString() => 'entry $name';
}

/// How a widget follows a bridge of the provider of the
/// [StateManagementRole], which the provider gives the role once, as its
/// data, for code that knows only the role.
///
/// Its only reader is the test of the role in a running app, which watches
/// each entry of the app through [watch] and knows no provider.
abstract base class StateBridges extends StateData {
  /// Allows subclasses to have constant constructors.
  const StateBridges();

  /// The code of a widget that rebuilds with the value of the bridge of
  /// [entry], read as a developer of the app reads it, such as with
  /// `ref.watch` or `context.watch`, and returns what [child] returns for
  /// it: [child] is the code of a `Widget Function(Object? value)`.
  ///
  /// The code imports the file of the bridges with the prefix `bridges`,
  /// and a widget below the root of the app builds it.
  Fragment watch(SharedState entry, String child);

  @override
  String toString() => 'bridges';
}

/// An entry of the app: a [SharedState] with its owner.
///
/// Obtain the entries of an app with [StateManagementRole.sharedStateIn].
@immutable
final class AppSharedState {
  const AppSharedState._(this.owner, this.state);

  /// Who gave the app the entry: a module, also for an entry of its
  /// variant, or the template of a role.
  final ContributionOrigin owner;

  /// The entry.
  final SharedState state;

  /// The name of the entry; see [SharedState.name].
  String get name => state.name;

  @override
  String toString() => '$state of ${_named(owner)}';
}

/// Who owns the entries that [origin] gave: a variant of a module gives the
/// entries of its module.
ContributionOrigin _ownerOf(ContributionOrigin origin) => switch (origin) {
      ModuleOrigin(:final module) => ModuleOrigin(module),
      _ => origin,
    };

/// How a message names [owner], who gave the app an entry.
String _named(ContributionOrigin owner) => switch (owner) {
      ModuleOrigin(:final module) => 'the module $module',
      RoleTemplateOrigin(:final role) => 'the template of the $role',
      PipelineOrigin() => 'the $owner',
    };

/// The problems of [entries], the entries of the module or of the template
/// of the role whose id is [owner]: those of each entry on its own, a name
/// that does not start with that id in lowerCamelCase and another word, and
/// two entries of one name.
List<String> _entryProblems(List<SharedState> entries, String owner) {
  final prefix = SmfNames.lowerCamelCase(owner);
  final word = RegExp('^${RegExp.escape(prefix)}[A-Z0-9]');
  final problems = <String>[];
  final names = <String>{};
  for (final entry in entries) {
    problems.addAll(entry.problems());
    if (_entryName.hasMatch(entry.name) && !word.hasMatch(entry.name)) {
      problems.add(
        'The entry "${entry.name}" does not start with $prefix, the id of '
        'its owner in lowerCamelCase, and another word.',
      );
    }
    if (!names.add(entry.name)) {
      problems.add('Two entries are named "${entry.name}".');
    }
  }
  return problems;
}
