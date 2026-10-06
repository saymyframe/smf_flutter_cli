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
/// against [texts], those that it gives this role:
/// - texts of one name in the data of a role that differ, for each of which
///   the app would show the text of that name that the module gives this
///   role;
/// - a text that is not among [texts], which the app would show in English
///   in every language though the module lists this role;
/// - a text that differs from the one of its name among [texts], which the
///   app would show otherwise with the role than without it.
///
/// A text that the data of a role has several times counts once.
List<SmfIssue> _dataTextIssues(
  ModuleRuleInput<TextsData> input,
  List<LocalizedText> texts,
  ModuleOrigin origin,
) {
  final issues = <SmfIssue>[];
  for (final MapEntry(key: role, value: byName)
      in _dataTextsOf(input.contributions).entries) {
    for (final MapEntry(key: name, value: named) in byName.entries) {
      final gives = 'The module gives the $role';
      if (named.length > 1) {
        issues.add(
          SmfIssue(
            '$gives ${named.length} texts named "$name" in its data that '
            'differ: ${named.map(_shown).join('; ')}. The app reads a text '
            'of a module by its name, so it would show the same text for '
            'each of them.',
            hint: 'Give each of these texts a name of its own, and the '
                '$localizationRole each of them among the texts of the module.',
            origin: origin,
          ),
        );
        continue;
      }
      final text = named.single;
      final given = texts.where((own) => own.name == name).firstOrNull;
      final what = '$gives the text "$name" in its data';
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

/// The texts of the data with texts among [contributions], those of a
/// module, by the role of the data and by their name, in the order of the
/// data: under each name the texts that differ, each once.
Map<Role, Map<String, List<LocalizedText>>> _dataTextsOf(
  List<Contribution> contributions,
) {
  final texts = <Role, Map<String, List<LocalizedText>>>{};
  for (final data in contributions.whereType<RoleData<Object>>()) {
    final value = data.value;
    if (value is! DataWithTexts) continue;
    final byName = texts.putIfAbsent(data.role, () => {});
    for (final text in value.shownTexts) {
      final named = byName.putIfAbsent(text.name, () => []);
      if (!named.any((other) => _sameText(other, text))) named.add(text);
    }
  }
  return texts;
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

/// The role whose data the code of [owner] renders with texts of the
/// modules: the role of the template that [owner] is, unless it is this
/// role, whose data are the texts themselves. A module has none: it reads
/// the texts of the modules it depends on.
Role? _roleWithTextsOf(ContributionOrigin owner) => switch (owner) {
      RoleTemplateOrigin(:final role) when !identical(role, localizationRole) =>
        role,
      _ => null,
    };

/// The roles that [module] provides whose templates render data with
/// texts of the modules: those that require or use this role, but for this
/// role itself. The texts of that data are for the template of the role to
/// read, not for the module.
Iterable<Role> _rolesWithTextsOf(ModuleDescriptor? module) => [
      for (final role in module?.provides ?? const <Role>{})
        if (!identical(role, localizationRole) &&
            role.visibleRoles.contains(localizationRole))
          role,
    ];

/// What to do about a text of another owner that code reads: for the
/// template of the role [rendered], which renders data with texts of the
/// modules, and for a module [module] that provides such roles, also where
/// those texts are read.
String _ownTextHint(Role? rendered, ModuleDescriptor? module) {
  final hint = StringBuffer('Give the role a text of your own.');
  if (rendered != null) {
    hint.write(
      ' A text of a module comes with the data that the module gives your '
      'role, a DataWithTexts, and the code that reads it from '
      'LocalizationRole.expressionOf().',
    );
  }
  for (final role in _rolesWithTextsOf(module)) {
    hint.write(
      ' A text that a module gives the $role in its data is read by the '
      'template of that role, and a provider of the role shows it through '
      'what the template generates.',
    );
  }
  return '$hint';
}

/// The texts of the modules that the template of [role] may read besides
/// its own, each as its owner and its name: the texts of the data of
/// [role] and of the roles that it requires or uses (see [DataWithTexts]),
/// such as the labels of the destinations for the layout role.
///
/// The hooks of the role render that data, so they know which texts these
/// are; the rule reads them from what those hooks get.
Set<(ContributionOrigin, String)> _textsOfDataFor(
  StructuralRuleInput<TextsData> input,
  Role role,
) {
  final seen = input.inputOf(role);
  return {
    for (final read in {role, ...role.visibleRoles})
      for (final data in read.dataIn(seen))
        // Every data that a hook gets has an origin.
        if (data.value case final DataWithTexts value)
          for (final text in value.shownTexts)
            (_ownerOf(data.origin!), text.name),
  };
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
    if (!_readsTexts(owner, module)) continue;
    final readable = {
      owner,
      for (final dependency in module?.dependsOn ?? const <ModuleId>{})
        ModuleOrigin(dependency),
    };
    // The template of another role renders what the modules give that role,
    // so it reads the texts of their data too.
    final rendered = _roleWithTextsOf(owner);
    final ofData = rendered == null
        ? const <(ContributionOrigin, String)>{}
        : _textsOfDataFor(input, rendered);
    final own = switch (owner) {
      ModuleOrigin() => 'its own texts and those of the modules it depends on',
      _ when rendered != null => 'its own texts and those that the modules '
          'give its role in their data',
      _ => 'its own texts',
    };
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
      } else if (!readable.contains(text.owner) &&
          !ofData.contains((text.owner, text.text.name))) {
        issues.add(
          SmfIssue(
            '$path reads $read, the $text, but ${_named(owner)} may only '
            'read $own.',
            hint: _ownTextHint(rendered, module),
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
