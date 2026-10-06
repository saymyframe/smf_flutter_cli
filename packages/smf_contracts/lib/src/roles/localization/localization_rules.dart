part of '../localization.dart';

/// Names that no getter of a text can have: the members of `Object`, which
/// the type of the texts has already.
const Set<String> _reservedGetters = {
  'hashCode',
  'noSuchMethod',
  'runtimeType',
  'toString',
};

/// The code of a variable of a brick that reads a text of the app, with
/// the getter of the text.
final RegExp _readsText = RegExp(r'^context\.l10n\.([A-Za-z0-9_$]+)$');

List<SmfIssue> _checkTexts(ModuleRuleInput<TextsData> input) {
  final origin = ModuleOrigin(input.module.id);
  final texts = [for (final data in input.data) ...data.value.texts];
  return [
    for (final problem in _textProblems(texts))
      SmfIssue(problem, origin: origin),
    ..._variableIssues(input, origin),
    ..._dataTextIssues(input, texts, origin),
  ];
}

/// The problems of the texts that the module of [input] gives other roles
/// in its data (see [DataWithTexts]), such as the label of a destination,
/// against [texts], those that it gives this role: one that is not among
/// them, which the app would show in English in every language though the
/// module lists this role, and one that differs from the text of its name
/// among them, which the app would show otherwise with the role than
/// without it. Each text is reported once for a role.
List<SmfIssue> _dataTextIssues(
  ModuleRuleInput<TextsData> input,
  List<LocalizedText> texts,
  ModuleOrigin origin,
) {
  final issues = <SmfIssue>[];
  final seen = <(Role, String)>{};
  for (final data in input.contributions.whereType<RoleData<Object>>()) {
    final value = data.value;
    if (value is! DataWithTexts) continue;
    for (final text in value.shownTexts) {
      if (!seen.add((data.role, text.name))) continue;
      final given = texts.where((own) => own.name == text.name).firstOrNull;
      final what = 'The module gives the ${data.role} the $text in its data';
      if (given == null) {
        issues.add(
          SmfIssue(
            '$what, but not the $localizationRole, so the app would show it '
            'in English in every language.',
            hint: 'Give the role the text among the texts of the module: '
                'localizationRole.data(TextsData([...])).',
            origin: origin,
          ),
        );
      } else if (!_sameText(given, text)) {
        issues.add(
          SmfIssue(
            '$what, and the $localizationRole a text of that name that '
            'differs from it: ${_shown(text)} and ${_shown(given)}.',
            hint: 'Give both roles the same text, such as one constant.',
            origin: origin,
          ),
        );
      }
    }
  }
  return issues;
}

/// Whether [a] and [b] read the same in every language.
bool _sameText(LocalizedText a, LocalizedText b) =>
    a.en == b.en &&
    a.translations.length == b.translations.length &&
    a.translations.entries.every(
      (translation) => b.translations[translation.key] == translation.value,
    );

/// [text] as a message shows it: its English text, and its translations by
/// the code of their language.
String _shown(LocalizedText text) => [
      SmfNames.dartString(text.en),
      for (final MapEntry(key: language, value: translation)
          in text.translations.entries)
        '$language: ${SmfNames.dartString(translation)}',
    ].join(', ');

/// The code of [value], a value of a [RoleVar]: a fragment or a string of
/// code.
String _codeOf(Object value) => value is Fragment ? value.code : '$value';

/// The problems of the variables of the bricks of the module of [input]
/// that read a text of the app, as those of [LocalizationRole.varsOf] do:
/// one whose text the app lacks, as when the module gave the role no such
/// text, and one whose code for an app without the role is not the English
/// text of its text, so that the app would read otherwise without the role
/// than with it.
List<SmfIssue> _variableIssues(
  ModuleRuleInput<TextsData> input,
  ModuleOrigin origin,
) {
  final byGetter = {
    for (final text in localizationRole.textsIn(input.roleInput))
      text.getter: text,
  };
  final issues = <SmfIssue>[];
  for (final brick in input.contributions.whereType<BrickContribution>()) {
    for (final MapEntry(key: name, value: variable) in brick.vars.entries) {
      if (variable is! RoleVar || !identical(variable.role, localizationRole)) {
        continue;
      }
      final getter = _readsText.firstMatch(_codeOf(variable.present))?[1];
      if (getter == null) continue;
      final where = 'The variable $name of the brick ${brick.bundle.name}';
      final text = byGetter[getter];
      if (text == null) {
        issues.add(
          SmfIssue(
            '$where reads context.l10n.$getter, but no text of the app has '
            'the getter $getter.',
            hint: 'Give the role the texts of the variables as data too: '
                'localizationRole.data(texts).',
            origin: origin,
          ),
        );
      } else if (_codeOf(variable.absent) !=
          SmfNames.dartString(text.text.en)) {
        issues.add(
          SmfIssue(
            '$where is ${_codeOf(variable.absent)} in an app without the '
            '$localizationRole, but the $text is '
            '${SmfNames.dartString(text.text.en)} in English.',
            hint: 'Make the variables with localizationRole.varsOf() from '
                'the texts that the module gives the role.',
            origin: origin,
          ),
        );
      }
    }
  }
  return issues;
}

/// Whether the code of [owner], whose descriptor is [module] if it is a
/// module of the app, may read texts of the app, so that the rule
/// `localization.text_access` looks at its files.
///
/// A module without the role among its roles, and the template of a role
/// that neither requires nor uses the role, read none: a variable of theirs
/// called `l10n` is something else, and the harness reports their import of
/// the file of the texts. The provider of the role renders every text. A
/// module whose descriptor the app lacks has no roles to tell by.
bool _readsTexts(ContributionOrigin owner, ModuleDescriptor? module) =>
    switch (owner) {
      ModuleOrigin() => module != null &&
          module.roles.contains(localizationRole) &&
          !module.provides.contains(localizationRole),
      RoleTemplateOrigin(:final role) => identical(role, localizationRole) ||
          role.visibleRoles.contains(localizationRole),
      PipelineOrigin() => true,
    };

/// Whether [owner] is the template of a role other than this one, whose
/// data may have texts of the modules (see [DataWithTexts]): the data of
/// this role are the texts themselves.
bool _rendersDataOfModules(ContributionOrigin owner) =>
    owner is RoleTemplateOrigin && !identical(owner.role, localizationRole);

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
    if (!_readsTexts(owner, module)) continue;
    // The template of another role renders what the modules give that role,
    // so it reads the texts of their data too: which texts those are, only
    // its role knows.
    final readable = _rendersDataOfModules(owner)
        ? null
        : {
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
      } else if (readable != null && !readable.contains(text.owner)) {
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

/// The texts of the app that the provider of the role does not render:
/// those whose getter none of the text files of the provider names, as the
/// key of the text in a file of translations or as its getter in Dart code.
///
/// So no provider leaves out a text that a module gives the role, and the
/// tests of the modules need not look into the files of any provider.
/// Without the descriptor of a provider in [input], no file renders the
/// texts and there is nothing to check.
List<SmfIssue> _checkTextsRendered(StructuralRuleInput<TextsData> input) {
  final providers = {
    for (final module in input.modules)
      if (module.provides.contains(localizationRole)) module.id,
  };
  if (providers.isEmpty) return const [];
  final files = [
    for (final MapEntry(key: path, value: text) in input.texts.entries)
      if (input.owners[path] case ModuleOrigin(:final module)
          when providers.contains(module))
        text,
  ];
  return [
    for (final text in localizationRole.textsIn(input.roleInput))
      if (!files.any(_wholeName(text.getter).hasMatch))
        SmfIssue(
          'The provider of the $localizationRole does not render the $text: '
          'none of its files names the getter ${text.getter}.',
          hint: 'Render every text of LocalizationRole.textsIn() under the '
              'name of its getter, in the languages of '
              'LocalizationRole.localesIn().',
          origin: text.owner,
          path: LocalizationRole.textsFile,
        ),
  ];
}

/// Matches [name] as a whole name: not as a part of a longer one.
RegExp _wholeName(String name) =>
    RegExp('(?<![A-Za-z0-9_\$])${RegExp.escape(name)}(?![A-Za-z0-9_\$])');
