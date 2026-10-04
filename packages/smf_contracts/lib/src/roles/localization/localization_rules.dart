part of '../localization.dart';

/// Names that no getter of a text can have: the members of `Object`, which
/// the type of the texts has already.
const Set<String> _reservedGetters = {
  'hashCode',
  'noSuchMethod',
  'runtimeType',
  'toString',
};

List<SmfIssue> _checkTexts(ModuleRuleInput<TextsData> input) {
  final origin = ModuleOrigin(input.module.id);
  final texts = [for (final data in input.data) ...data.value.texts];
  return [
    for (final problem in _textProblems(texts))
      SmfIssue(problem, origin: origin),
  ];
}

/// Whether [target], the expression before a dot, is the texts of the app,
/// as code names them: `context.l10n`, or a variable called `l10n`.
bool _isTexts(String? target) =>
    target != null && (target == 'l10n' || target.endsWith('.l10n'));

List<SmfIssue> _checkTextAccess(StructuralRuleInput<TextsData> input) {
  final byGetter = {
    for (final text in localizationRole.textsIn(input.roleInput))
      text.getter: text,
  };
  final issues = <SmfIssue>[];
  for (final MapEntry(key: path, value: file) in input.files.entries) {
    final generatedBy = input.owners[path];
    if (generatedBy == null) continue;
    final owner = _ownerOf(generatedBy);
    final module = switch (owner) {
      ModuleOrigin(:final module) => input.module(module),
      _ => null,
    };
    // The provider renders every text of the app.
    if (module?.provides.contains(localizationRole) ?? false) continue;
    final readable = {
      owner,
      for (final dependency in module?.dependsOn ?? const <ModuleId>{})
        ModuleOrigin(dependency),
    };
    final own = owner is ModuleOrigin
        ? 'its own texts and those of the modules it depends on'
        : 'its own texts';
    for (final access in file.memberAccesses) {
      if (!_isTexts(access.target)) continue;
      final read = '${access.target}.${access.name}';
      final text = byGetter[access.name];
      if (text == null) {
        issues.add(
          SmfIssue(
            '$path reads $read, but no text of the app has the getter '
            '${access.name}.',
            hint: 'Give the role the text as data of its owner: the text '
                'title of the module settings is read as settingsTitle. '
                'The rule matches by name, so rename a variable called '
                'l10n that is not the texts of the app.',
            origin: owner,
            path: path,
          ),
        );
      } else if (!readable.contains(text.owner)) {
        issues.add(
          SmfIssue(
            '$path reads $read, the $text, but ${_named(owner)} may only '
            'read $own.',
            hint: 'Give the role a text of your own.',
            origin: owner,
            path: path,
          ),
        );
      }
    }
    for (final call in file.invocations) {
      if (!_isTexts(call.target)) continue;
      issues.add(
        SmfIssue(
          '$path calls ${call.target}.${call.name}(), but the texts of the '
          'app are getters, each named by the role.',
          hint: 'Read a text as its getter, without arguments.',
          origin: owner,
          path: path,
        ),
      );
    }
  }
  return issues;
}
