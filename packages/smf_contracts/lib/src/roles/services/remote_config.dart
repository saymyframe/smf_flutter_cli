part of '../services.dart';

/// The remote config role; see [RemoteConfigRole].
const remoteConfigRole = RemoteConfigRole._();

/// The role of remote config: values that the code of the app reads, which a
/// backend of the provider changes without a new version of the app, each
/// with a default that the app has while the backend gives none.
///
/// A module that requires or uses the role gives it a [RemoteConfigKey] for
/// each parameter that its code reads: a name in lower snake_case of two
/// words or more that starts with the id of the module, such as
/// `update_required_minimum_version` of a module `update_required`, a type,
/// a default of that type and a description of one line. The template of a
/// role that requires or uses this role does the same for a parameter that
/// the code of the role reads, with a name that starts with the id of the
/// role. [keysIn] has the parameters of an app.
///
/// The role's template generates these files, whichever module provides
/// the role:
/// - [serviceFile] with `RemoteConfigService`, the interface that the
///   provider implements;
/// - [valuesFile] with `RemoteValues`, which has the default of each
///   parameter of the app in `RemoteValues.defaults` and a getter for each,
///   named by [RemoteConfigKey.getter], which returns a value of the type of
///   the parameter;
/// - [controllerFile] with `appRemoteConfig`, the `AppRemoteConfigController`
///   of the app. The file exports [valuesFile], so the code of the app
///   imports this file alone.
///
/// The provider contributes its implementation of `RemoteConfigService` as a
/// [RemoteConfigImplementation], created with the app. The role registers
/// nothing in a DI container: the code of an app uses `appRemoteConfig`, a
/// top-level variable, and no module or template of another role reaches the
/// service of the provider.
///
/// The template also writes the section [readmeHeading] of the README of the
/// app, from its render hook, since the section lists the parameters of the
/// app, and the note of the role in the guide for coding agents of the app
/// under its description.
///
/// Every value reaches every installation of the app that fetches it, where
/// anyone can read it. So no secret goes into remote config, such as a key
/// or a password: the doc of the role, its note and its section of the
/// README say so.
///
/// ## The controller
///
/// `appRemoteConfig` is a `ValueListenable<RemoteValues>`. Its `value` has
/// the values that the app reads: for each parameter of the app, the value
/// that the backend gave it, as the type of the parameter takes it, or its
/// default while the backend gives none, or gives a text that the type does
/// not take, such as `abc` for a whole number. A debug build prints such a
/// text once. `RemoteValues` compares by its values, and the controller
/// tells its listeners only when a value of a parameter of the app changes.
///
/// `Future<void> initRemoteConfig()` creates the service with the provider's
/// function and starts `appRemoteConfig` with it. `bootstrap()` awaits it in
/// its platform phase. The values never hold the start: the start opens the
/// service and makes active what the last fetch got, which the device keeps
/// from one launch of the app to the next, without the network, and waits
/// for that at most `AppRemoteConfigController.startWait`, a second. Values
/// that come later still become the value.
///
/// In an app with parameters, the controller then asks the backend for its
/// values in the background, in a later turn of the event loop than the end
/// of the start: so code that runs right after the start reads what the
/// start made active. It asks again each time the user comes back to the
/// app, which the provider throttles to the fetch interval of the role, and
/// makes the new values active at once, also while a screen shows. Where the
/// provider tells of values that the backend publishes while the app runs
/// (`RemoteConfigService.liveUpdates`), the controller listens to them and
/// makes each active as it comes. While the app has no parameter, it asks
/// the backend nothing and listens to nothing: the app starts asking with its
/// first parameter.
///
/// The calls of the service run one after another, and the controller drops
/// those of a service that it no longer has. An error of the service keeps
/// the values, reaches no handler of the uncaught errors of the app, and
/// prints in a debug build. The controller tells its listeners of a change
/// from the completion of a call of the service and from the values that the
/// service tells of, and from `start()`, which takes the defaults back:
/// never while a widget builds.
///
/// ## What a provider keeps to
///
/// The contract of `RemoteConfigService` is in [serviceFile]. In short:
/// - the function of the implementation asks the backend nothing, and may be
///   called again, as at the next launch of the app;
/// - `open` comes once, before any other member, with the defaults of the
///   parameters of the app, the fetch interval and the timeout of a fetch;
/// - what was activated stays on the device from one launch to the next:
///   after `open`, `activate` makes what the last fetch got active, also
///   without the network;
/// - `values` has the active values that the backend gave, as texts, and
///   never a default, nor a value that the provider makes up for a parameter
///   that the backend lacks;
/// - `fetch` asks the backend, unless the last fetch that succeeded is more
///   recent than the fetch interval, and fails when the backend cannot be
///   reached or refuses;
/// - `updates` is a broadcast stream, which tells of nothing where
///   `liveUpdates` is false.
///
/// Only a running app shows whether a provider keeps to it.
///
/// ## Rules
///
/// The module rule `remote_config.keys` checks the parameters of a module,
/// and the template of the role checks those of the templates of roles and
/// two owners with one name or one getter. The structural rules of the role
/// read the index of each Dart file of an app, so they see what a file
/// itself imports, calls and reads:
/// - `remote_config.factory_calls`: no file of a module, and none of the
///   template of another role, calls `createRemoteConfigService()`, and of
///   such files only those of the provider's implementation, the files of its
///   class and of its function, import or export [serviceFile];
/// - `remote_config.start_calls`: only the file of `bootstrap()` calls
///   `initRemoteConfig()`, and no file of a module or of the template of
///   another role calls `appRemoteConfig.start()`, which
///   `initRemoteConfig()` and tests call;
/// - `remote_config.implementation_factories`: the function of the
///   implementation is in its file and takes no arguments;
/// - `remote_config.key_access`: the files of a module read the getters of
///   the parameters of the module and of the modules it depends on alone,
///   and the files of the template of a role those of its own parameters.
///
/// They do not see a `part` file of a library that imports
/// [controllerFile], a file that reaches [controllerFile] through an export
/// of another file of the app, or `appRemoteConfig` under another name.
///
/// ## Tests
///
/// A test gives `appRemoteConfig.start()` a service of its own to script
/// what a provider answers, and runs `initRemoteConfig()` again to see what
/// the next launch of the app finds. A test that brings the user back to the
/// app may go through any state of the lifecycle: the controller looks only
/// at `AppLifecycleState.resumed`.
///
/// The mocks of the platform side of every provider, with which the tests
/// of the apps run, keep to one convention, so that the tests of the role
/// and of the modules hold with each:
/// - the backend has no value of any parameter of the app, so the app reads
///   the default of each, and a module whose code acts on a value, such as a
///   gate of the app, stays as it is in the tests of the other modules;
/// - the backend has one parameter outside the app, [checkParameter], with a
///   text of its own, which no app reads: the test of the role fetches and
///   activates it, and finds it at the next start of the app;
/// - a fetch completes at once with what the backend has, and no value comes
///   from the backend while the app runs unless a test of the provider's own
///   module publishes one;
/// - the device keeps what was activated from one start of the app to the
///   next, as the role asks.
final class RemoteConfigRole extends Role<RemoteConfigData> {
  const RemoteConfigRole._();

  /// The path of the file with `RemoteConfigService`, which the provider
  /// implements.
  static const serviceFile =
      'lib/core/remote_config/remote_config_service.dart';

  /// The path of the file with `appRemoteConfig`, which the code of the app
  /// uses.
  static const controllerFile = 'lib/core/remote_config/app_remote_config.dart';

  /// The path of the file with `RemoteValues`, the values that the code of
  /// the app reads, which [controllerFile] exports.
  static const valuesFile = 'lib/core/remote_config/remote_values.dart';

  /// The heading of the section of the README of the app in which the
  /// template tells how the app reads remote config and lists its
  /// parameters. The section of a provider can refer to it.
  static const readmeHeading = 'Remote config';

  /// The parameter that the backend of the mocks of every provider has,
  /// which is no parameter of the app; see [RemoteConfigRole].
  static const checkParameter = 'remote_config_role_check';

  /// The implementation of `RemoteConfigService`, which the template renders
  /// from the provider's [RemoteConfigImplementation]; modules do not
  /// contribute to it.
  static const implementations = SocketRef<CodeSocket>.role(
    remoteConfigRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'remote_config';

  @override
  String get description => 'Remote config';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [serviceFile, controllerFile, valuesFile],
      );

  @override
  RoleTemplate<RemoteConfigData> get template => const _RemoteConfigTemplate();

  @override
  List<ModuleRule<RemoteConfigData>> get moduleRules => const [
        ModuleRule(
          id: _implementationsRuleId,
          description: _implementationsRuleDescription,
          check: _checkImplementations,
        ),
        ModuleRule(
          id: 'remote_config.keys',
          description: 'The parameters of a module have names in lower '
              'snake_case of two words or more and at most 256 characters, '
              'which start with the id of the module and an underscore, each '
              'once and each with a getter of its own that no Dart object '
              'has; a default of their type, finite for a decimal and of one '
              'line without a backtick for a text; and a description of one '
              'line of at most 100 characters without a backslash or an angle '
              'bracket.',
          check: _checkRemoteConfigKeys,
        ),
      ];

  @override
  List<StructuralRule<RemoteConfigData>> get structuralRules => const [
        StructuralRule(
          id: 'remote_config.factory_calls',
          description: 'No module calls createRemoteConfigService(), and only '
              'the files of the implementation of the provider import the '
              'file of RemoteConfigService: the code of the app reads the '
              'values through appRemoteConfig.',
          check: _checkRemoteConfigService,
        ),
        StructuralRule(
          id: 'remote_config.start_calls',
          description: 'Only bootstrap() calls initRemoteConfig(), and no '
              'module calls appRemoteConfig.start().',
          check: _checkRemoteConfigStart,
        ),
        StructuralRule(
          id: 'remote_config.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
        StructuralRule(
          id: 'remote_config.key_access',
          description: 'The files of a module with the role among its roles '
              'read only the getters of its own parameters and of the '
              'parameters of the modules it depends on, and the files of the '
              'template of a role only those of its own parameters. A value '
              'is read on an instance of RemoteValues, so the rule takes a '
              'read of a member with the name of the getter of a parameter of '
              'the app, on any object, for a read of that parameter: the name '
              'starts with the id of the owner of the parameter, so a member '
              'of another type with that name is unlikely.',
          check: _checkRemoteConfigKeyAccess,
        ),
      ];

  /// The parameters of the app in [input], the input of a hook of this role,
  /// of its provider, or of a role that requires or uses this role: those of
  /// the modules, in the order the modules were selected, and then those of
  /// the templates of roles. The parameters of one owner keep its order.
  ///
  /// `RemoteValues` of the app has their defaults and their getters in this
  /// order.
  List<AppRemoteConfigKey> keysIn(RoleHookInput<Object> input) => [
        for (final data in dataIn(input))
          if (data.value case final RemoteConfigKey key)
            // Every data that a hook gets has an origin.
            AppRemoteConfigKey._(_parameterOwnerOf(data.origin!), key),
      ];
}

/// The form of the name of a parameter: lower snake_case of two words or
/// more, the first of which starts with a letter.
final RegExp _parameterName = RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)+$');

/// The longest name of a parameter that a backend of remote config takes,
/// such as Firebase Remote Config.
const _maxParameterName = 256;

/// The longest description of a parameter, which the README of the app has
/// on a line of the list of the parameters.
const _maxParameterDescription = 100;

/// Names that no getter of `RemoteValues` can have: the members of `Object`,
/// which every class has already.
const Set<String> _objectMemberNames = {
  'hashCode',
  'noSuchMethod',
  'runtimeType',
  'toString',
};

/// What the [RemoteConfigRole] takes from the app: the
/// [RemoteConfigImplementation] of its provider, and a [RemoteConfigKey] for
/// each parameter that the code of a module or of the template of a role
/// reads.
@immutable
sealed class RemoteConfigData {
  const RemoteConfigData();
}

/// The implementation of `RemoteConfigService` that the provider of the
/// [RemoteConfigRole] contributes, created with the app:
///
/// ```dart
/// remoteConfigRole.data(
///   const RemoteConfigImplementation(
///     type: TypeRef('BackendRemoteConfigService', import: file),
///     create: FactoryRef('createBackendRemoteConfigService', import: file),
///   ),
/// )
/// ```
///
/// It has no asynchronous form: the service opens in `open`, which the
/// controller of the role awaits within the start of the app.
@immutable
final class RemoteConfigImplementation extends RemoteConfigData {
  /// An implementation of [type] that [create] returns.
  const RemoteConfigImplementation({
    required this.type,
    required this.create,
  });

  /// The class of the implementation.
  final TypeRef type;

  /// The function that returns the implementation.
  final FactoryRef create;

  /// The implementation as the service roles take one.
  RoleImplementation get implementation =>
      RoleImplementation(type: type, create: create);

  @override
  String toString() => 'implementation $type';
}

/// The type of a parameter of remote config: the type of the value of its
/// getter in the app and of its default.
enum RemoteParameterType {
  /// A text, a `String`.
  text('String', 'a text'),

  /// `true` or `false`, a `bool`.
  boolean('bool', 'a Boolean'),

  /// A whole number, an `int`.
  integer('int', 'a whole number'),

  /// A number, a `double`.
  decimal('double', 'a number');

  const RemoteParameterType(this.dartType, this.description);

  /// The Dart type of the value, such as `String`.
  final String dartType;

  /// How the README of the app names the type, such as `a text`.
  final String description;
}

/// A parameter of remote config that the code of its owner reads, with the
/// value that the app has while the backend gives none:
///
/// ```dart
/// remoteConfigRole.data(
///   const RemoteConfigKey.text(
///     'update_required_minimum_version',
///     defaultValue: '',
///     description: 'The lowest version of the app that may run, such as '
///         '1.4.0; empty for none',
///   ),
/// )
/// ```
///
/// The data needs no condition, since it applies only when the role is
/// present. Code reads the value as the getter [getter] of the `RemoteValues`
/// that `appRemoteConfig.value` gives.
///
/// The role has the four types of a parameter that the backends of remote
/// config have, a text, a Boolean and a number, with a number as a whole
/// number or as a decimal, so that the typed values of the app take every
/// parameter that a developer adds.
@immutable
final class RemoteConfigKey extends RemoteConfigData {
  /// The text parameter [name], whose default is [defaultValue].
  const RemoteConfigKey.text(
    this.name, {
    required String this.defaultValue,
    required this.description,
  }) : type = RemoteParameterType.text;

  /// The Boolean parameter [name], whose default is [defaultValue].
  const RemoteConfigKey.boolean(
    this.name, {
    required bool this.defaultValue,
    required this.description,
  }) : type = RemoteParameterType.boolean;

  /// The whole number parameter [name], whose default is [defaultValue].
  const RemoteConfigKey.integer(
    this.name, {
    required int this.defaultValue,
    required this.description,
  }) : type = RemoteParameterType.integer;

  /// The decimal parameter [name], whose default is [defaultValue].
  const RemoteConfigKey.decimal(
    this.name, {
    required double this.defaultValue,
    required this.description,
  }) : type = RemoteParameterType.decimal;

  /// The name of the parameter in the backend and in the app, in lower
  /// snake_case of two words or more and of at most 256 characters, such as
  /// `update_required_minimum_version`.
  ///
  /// It starts with the id of its owner and an underscore, such as
  /// `update_required_` for the module `update_required`, or the id of the
  /// role for a parameter of its template. So the parameters of two owners
  /// differ, and the backend of a developer shows whose each is. It has no
  /// dot, unlike the keys of the preferences, and a backend of remote config
  /// takes it as it is.
  final String name;

  /// The type of the parameter.
  final RemoteParameterType type;

  /// The value that the app reads while the backend gives none, of the
  /// [type] of the parameter: a `String`, a `bool`, an `int` or a `double`.
  final Object defaultValue;

  /// What the parameter is for, as one line of at most 100 characters
  /// without a backslash or an angle bracket, such as `The lowest version of
  /// the app that may run, such as 1.4.0; empty for none`.
  ///
  /// It is the doc of the getter, the line of the parameter in the README of
  /// the app, and what a developer gives the parameter as its description in
  /// the backend.
  final String description;

  /// The name of the getter of `RemoteValues` that returns the value: the
  /// name in lowerCamelCase, such as `updateRequiredMinimumVersion` for
  /// `update_required_minimum_version`.
  ///
  /// A name has two words or more, so its getter is never a reserved word of
  /// Dart, nor a static member of `RemoteValues`, whose names have one word.
  /// Names whose words are cut differently can have one getter, such as
  /// `shop1_limit` and `shop_1_limit`; the role reports two such parameters.
  String get getter => SmfNames.lowerCamelCase(name);

  /// The default as Dart code: a literal of the [type] of the parameter, such
  /// as `'Hello'`, `true`, `3` or `0.5`. A finite `double` writes itself
  /// with a point or an exponent on the Dart VM, as `1.0` or `1e+21`, never
  /// as `1`, which Dart would take for an `int`.
  String get defaultCode => switch (defaultValue) {
        final String text => SmfNames.dartString(text),
        final value => '$value',
      };

  /// Describes what is wrong with the parameter on its own, or returns an
  /// empty list. Whether its name starts with the id of its owner, and
  /// whether it differs from the other parameters, is for the role to tell.
  List<String> problems() {
    final what = 'The parameter "$name"';
    final problems = <String>[];
    if (!_parameterName.hasMatch(name)) {
      problems.add(
        '$what needs a name in lower snake_case of two words or more that '
        'starts with a letter, such as update_required_minimum_version.',
      );
    } else if (name.length > _maxParameterName) {
      problems.add(
        '$what has a name of ${name.length} characters; a backend of remote '
        'config takes at most $_maxParameterName.',
      );
    } else if (_objectMemberNames.contains(getter)) {
      problems.add(
        '$what would be read as RemoteValues.$getter, which every Dart object '
        'has already.',
      );
    }
    switch (defaultValue) {
      case final double number when !number.isFinite:
        problems.add(
          '$what has the default $number, but a decimal default is a finite '
          'number.',
        );
      case final String text
          when text.contains('\n') || text.contains('\r') || text.contains('`'):
        problems.add(
          '$what has a default that is not one line without a backtick, as '
          'the README of the app shows it in inline code.',
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
    if (description.length > _maxParameterDescription) {
      problems.add(
        '$what has a description of ${description.length} characters; at '
        'most $_maxParameterDescription fit on its line in the README of the '
        'app.',
      );
    }
    if (description.contains(r'\')) {
      problems.add(
        '$what has a backslash in its description, which mason removes '
        'before a line break and Markdown reads as an escape.',
      );
    }
    if (description.contains('<') || description.contains('>')) {
      problems.add(
        '$what has an angle bracket in its description, which the doc of its '
        'getter in the app would read as HTML.',
      );
    }
    return problems;
  }

  @override
  String toString() => 'parameter $name';
}

/// A parameter of the app: a [RemoteConfigKey] with its owner.
///
/// Obtain the parameters of an app with [RemoteConfigRole.keysIn].
@immutable
final class AppRemoteConfigKey {
  const AppRemoteConfigKey._(this.owner, this.key);

  /// Who gave the app the parameter: a module, also for a parameter of its
  /// variant, or the template of a role.
  final ContributionOrigin owner;

  /// The parameter.
  final RemoteConfigKey key;

  /// The name of the parameter; see [RemoteConfigKey.name].
  String get name => key.name;

  /// The type of the parameter; see [RemoteConfigKey.type].
  RemoteParameterType get type => key.type;

  /// The default of the parameter; see [RemoteConfigKey.defaultValue].
  Object get defaultValue => key.defaultValue;

  /// The description of the parameter; see [RemoteConfigKey.description].
  String get description => key.description;

  /// The getter of `RemoteValues` that returns the value; see
  /// [RemoteConfigKey.getter].
  String get getter => key.getter;

  @override
  String toString() => '$key of ${_parameterOwnerNamed(owner)}';
}

/// Who owns the parameters that [origin] gave: a variant of a module gives
/// the parameters of its module.
ContributionOrigin _parameterOwnerOf(ContributionOrigin origin) =>
    switch (origin) {
      ModuleOrigin(:final module) => ModuleOrigin(module),
      _ => origin,
    };

/// How a message names [owner], who gave the app a parameter or generated a
/// file that reads one.
String _parameterOwnerNamed(ContributionOrigin owner) => switch (owner) {
      ModuleOrigin(:final module) => 'the module $module',
      RoleTemplateOrigin(:final role) => 'the template of the $role',
      PipelineOrigin() => 'the $owner',
    };

/// The problems of [keys], the parameters of the module or of the template
/// of the role whose id is [owner]: those of each parameter on its own, a
/// name that does not start with that id, two parameters of one name, and two
/// parameters with one getter.
List<String> _parameterProblems(List<RemoteConfigKey> keys, String owner) {
  final prefix = '${owner}_';
  final problems = <String>[];
  final names = <String>{};
  final getters = <String, String>{};
  for (final key in keys) {
    problems.addAll(key.problems());
    final valid = _parameterName.hasMatch(key.name);
    if (valid && !key.name.startsWith(prefix)) {
      problems.add(
        'The parameter "${key.name}" does not start with $prefix, the id of '
        'its owner and an underscore.',
      );
    }
    if (!names.add(key.name)) {
      problems.add('Two parameters are named "${key.name}".');
    } else if (valid) {
      final other = getters.putIfAbsent(key.getter, () => key.name);
      if (other != key.name) {
        problems.add(
          'The parameters "$other" and "${key.name}" would both be read as '
          'RemoteValues.${key.getter}.',
        );
      }
    }
  }
  return problems;
}

/// The problems of the parameters of the module of [input], which the
/// module rule `remote_config.keys` reports.
///
/// The template of the role checks the parameters of the templates of roles,
/// and the parameters of two owners with one name or one getter.
List<SmfIssue> _checkRemoteConfigKeys(
  ModuleRuleInput<RemoteConfigData> input,
) {
  final module = input.module;
  final origin = ModuleOrigin(module.id);
  final keys = [
    for (final data in input.data)
      if (data.value case final RemoteConfigKey key) key,
  ];
  return [
    for (final problem in _parameterProblems(keys, module.id.value))
      SmfIssue(problem, origin: origin),
  ];
}

/// The problems with the service of the provider in [input]; see
/// [_checkServiceReach].
///
/// Code that reached the service would read values around
/// `appRemoteConfig`, which applies the defaults, runs the calls one after
/// another and makes new values active once they are fetched.
List<SmfIssue> _checkRemoteConfigService(
  StructuralRuleInput<RemoteConfigData> input,
) =>
    _checkServiceReach(
      input,
      factory: 'createRemoteConfigService',
      service: 'RemoteConfigService',
      serviceFile: RemoteConfigRole.serviceFile,
      controllerFile: RemoteConfigRole.controllerFile,
      hint: 'Read the values of remote config from appRemoteConfig of '
          '${RemoteConfigRole.controllerFile}, which also exports '
          'RemoteValues.',
    );

/// The problems with the start of `appRemoteConfig` in [input]; see
/// [_checkControllerStart].
List<SmfIssue> _checkRemoteConfigStart(
  StructuralRuleInput<RemoteConfigData> input,
) =>
    _checkControllerStart(
      input,
      init: 'initRemoteConfig',
      controller: 'appRemoteConfig',
      controllerFile: RemoteConfigRole.controllerFile,
      hint: 'The role starts remote config in bootstrap(), before the first '
          'frame. Read the values from appRemoteConfig.',
    );

/// Whether the rule `remote_config.key_access` looks at the files of
/// [owner], whose descriptor is [module] if it is a module of the app.
///
/// It looks at the files of a module with the role among its roles, which
/// may read its own parameters and those of the modules it depends on, at
/// the files of the template of a role, which may read its own parameters,
/// and at the files of the pipeline, which have none. The harness reports
/// the import of the files of the role by a module without the role among
/// its roles. A module whose descriptor the app lacks has no roles to tell
/// by.
bool _readsParameters(ContributionOrigin owner, ModuleDescriptor? module) =>
    switch (owner) {
      ModuleOrigin() =>
        module != null && module.roles.contains(remoteConfigRole),
      RoleTemplateOrigin() || PipelineOrigin() => true,
    };

/// The reads of the getters of parameters of the app in the files of
/// [input] by an owner that may not read them; see the rule
/// `remote_config.key_access`.
List<SmfIssue> _checkRemoteConfigKeyAccess(
  StructuralRuleInput<RemoteConfigData> input,
) {
  final byGetter = {
    for (final key in remoteConfigRole.keysIn(input.roleInput)) key.getter: key,
  };
  if (byGetter.isEmpty) return const [];
  final issues = <SmfIssue>[];
  for (final MapEntry(key: path, value: file) in input.files.entries) {
    final generatedBy = input.owners[path];
    if (generatedBy == null) continue;
    final owner = _parameterOwnerOf(generatedBy);
    final module = switch (owner) {
      ModuleOrigin(:final module) => input.module(module),
      _ => null,
    };
    if (!_readsParameters(owner, module)) continue;
    final readable = {
      owner,
      for (final dependency in module?.dependsOn ?? const <ModuleId>{})
        ModuleOrigin(dependency),
    };
    final mayRead = owner is ModuleOrigin
        ? 'its own parameters and those of the modules it depends on'
        : 'its own parameters';
    for (final access in file.memberAccesses) {
      final key = byGetter[access.name];
      if (key == null || readable.contains(key.owner)) continue;
      issues.add(
        SmfIssue(
          '$path reads ${access.target}.${access.name}, the $key, but '
          '${_parameterOwnerNamed(owner)} may only read $mayRead.',
          hint: 'Give the role a parameter of your own.',
          origin: owner,
          path: path,
        ),
      );
    }
  }
  return issues;
}

/// Who answers for [key], which clashes with [earlier], a parameter before
/// it in the order of [RemoteConfigRole.keysIn]: its owner, unless that is
/// the template of a role, whose error stops the run. Lenient mode can leave
/// out a module, which comes before every template in that order.
ContributionOrigin _parameterAtFault(
  AppRemoteConfigKey earlier,
  AppRemoteConfigKey key,
) =>
    key.owner is RoleTemplateOrigin ? earlier.owner : key.owner;

/// The section of the role in the README of the app, whichever module
/// provides the role: what `appRemoteConfig` gives and when the values come,
/// the [keys] of the app, each with its type, its default, its getter, its
/// owner and its description, how to add one, and that no secret goes there.
String _remoteConfigReadme(List<AppRemoteConfigKey> keys) {
  final buffer = StringBuffer('''
The app reads values of remote config through `appRemoteConfig` in `${RemoteConfigRole.controllerFile}`. A backend of the provider changes them without a new version of the app. `appRemoteConfig.value` is a `RemoteValues` with a getter for each parameter of the app, which returns the value that the backend gave the parameter, or its default while the backend gives none or gives a value that the type of the parameter does not take.

The values never hold the start of the app. The start makes active what the last fetch got, which the device keeps, also without the network, and waits for that at most a second. In an app with parameters, the app then asks the backend for new values in the background, at the start and each time the user comes back to the app, and makes them active at once, also while a screen shows. Where the provider tells of values that the backend publishes while the app runs, they come the same way. While the app has no parameter, it asks the backend nothing: it starts asking with its first parameter. A widget that follows a value reads it in `build` under a `ValueListenableBuilder` of `appRemoteConfig`, and code that must not change on the screen reads it once, such as in `initState`.

''');
  if (keys.isEmpty) {
    buffer.writeln('No module of the app reads a parameter yet.');
  } else {
    buffer.writeln('The parameters of the app:\n');
    for (final key in keys) {
      final defaultValue = switch (key.defaultValue) {
        '' => 'empty',
        final value => '`${value is String ? value : key.key.defaultCode}`',
      };
      buffer.writeln(
        '- `${key.name}`, ${key.type.description} read as `${key.getter}`, '
        'by default $defaultValue, from ${_readmeParameterOwner(key.owner)}: '
        '${key.description}',
      );
    }
  }
  buffer.write('''

To add a parameter of your own, give it a default in `RemoteValues.defaults` and a getter in `${RemoteConfigRole.valuesFile}`, and create it in the backend of the provider with the same name and type. The section of the module that provides remote config tells where its backend is.

Every value reaches every installation of the app that fetches it, where anyone can read it. So never put a secret into remote config, such as a key or a password.
''');
  return '$buffer';
}

/// How the README of the app names [owner], who gave the app a parameter:
/// only modules and the templates of roles give the role parameters.
String _readmeParameterOwner(ContributionOrigin owner) => switch (owner) {
      ModuleOrigin(:final module) => 'the module `$module`',
      _ => 'the ${(owner as RoleTemplateOrigin).role}',
    };

/// The template of the [RemoteConfigRole]: the files of the role, with the
/// defaults and the getters of the parameters of the app, the implementation
/// of the provider and the start of remote config in `bootstrap()`, the
/// section of the role in the README of the app and its note for coding
/// agents, and the checks of the parameters that the module rules cannot
/// make.
final class _RemoteConfigTemplate extends _ServiceTemplate<RemoteConfigData> {
  const _RemoteConfigTemplate();

  @override
  Role<RemoteConfigData> get role => remoteConfigRole;

  @override
  RoleImplementation? implementationOf(RemoteConfigData data) => switch (data) {
        RemoteConfigImplementation(:final implementation) => implementation,
        RemoteConfigKey() => null,
      };

  @override
  String get implementationClass => 'RemoteConfigImplementation';

  @override
  MasonBundle get bundle => remoteConfigRoleBundle;

  @override
  String get file => RemoteConfigRole.controllerFile;

  @override
  String get service => 'RemoteConfigService';

  @override
  String get factory => 'createRemoteConfigService';

  @override
  String get initFunction => 'initRemoteConfig';

  @override
  String get variable => '_remoteConfigService';

  @override
  SocketRef<CodeSocket> get implementations => RemoteConfigRole.implementations;

  /// The note of the role in the guide for coding agents: where the values
  /// are and how a widget follows them, when they come, how a parameter is
  /// added, that no secret goes there, and which functions of the role are
  /// not for the code of the app.
  @override
  String get agentNote => '''
- `appRemoteConfig` in `$file` holds the values of remote config, which a backend changes without a new version of the app. Its `value` is a `RemoteValues` with a getter for each parameter of the app, which returns the value that the backend gave or the default of the parameter. It is a `ValueListenable`: a widget that follows a value reads it in `build` under a `ValueListenableBuilder`, and code that must not change on the screen reads it once, such as in `initState`. The app has one controller, so create no other `AppRemoteConfigController`.
- The values never hold the start. The start makes active what the device kept from the last fetch, and an app with parameters fetches new values in the background, also each time the user comes back to it, which take effect at once. While the app has no parameter, it asks the backend nothing.
- A parameter has a default in `RemoteValues.defaults` and a getter in `${RemoteConfigRole.valuesFile}`, and the same name and type in the backend of the provider. The code of a module reads only its own parameters.
- Every value reaches every installation that fetches it, where anyone can read it: never put a secret into remote config, such as a key or a password.
- A new provider implements `$service` of `${RemoteConfigRole.serviceFile}`, and only the files of that implementation import it. The code of the app imports `$file`, which exports `RemoteValues`, and calls neither `$initFunction()` nor `$factory()` nor `appRemoteConfig.start()`. A test gives `appRemoteConfig.start()` a service of its own.
''';

  /// The brick and the note of the role. The role registers nothing in a DI
  /// container: the code of an app uses `appRemoteConfig`, not the service
  /// of the provider. The section of the README comes from the render hook,
  /// since it lists the parameters of the app.
  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(agentNote),
        ),
      ];

  /// Checks the implementation, and what the module rule
  /// `remote_config.keys` cannot see from one module: the parameters of the
  /// templates of roles, which that rule does not read, and the parameters of
  /// two owners with one name or one getter.
  @override
  List<SmfIssue> validate(RoleHookInput<RemoteConfigData> input) {
    final issues = [...super.validate(input)];
    final ofTemplates = <RoleTemplateOrigin, List<RemoteConfigKey>>{};
    for (final data in input.data) {
      if ((data.origin, data.value)
          case (final RoleTemplateOrigin template, final RemoteConfigKey key)) {
        (ofTemplates[template] ??= []).add(key);
      }
    }
    for (final MapEntry(key: template, value: keys) in ofTemplates.entries) {
      for (final problem in _parameterProblems(keys, template.role.id)) {
        issues.add(SmfIssue(problem, origin: template));
      }
    }

    // A name starts with the id of its owner, but the id of one owner can
    // start another, as `shop` starts `shop_cart`, and names whose words are
    // cut differently can have one getter.
    final byName = <String, AppRemoteConfigKey>{};
    final byGetter = <String, AppRemoteConfigKey>{};
    for (final key in remoteConfigRole.keysIn(input)) {
      final named = byName.putIfAbsent(key.name, () => key);
      final other = byGetter.putIfAbsent(key.getter, () => key);
      if (named.owner != key.owner) {
        issues.add(
          SmfIssue(
            'Both ${_parameterOwnerNamed(named.owner)} and '
            '${_parameterOwnerNamed(key.owner)} give the $remoteConfigRole '
            'the parameter ${key.name}.',
            hint: 'Rename one of the parameters.',
            origin: _parameterAtFault(named, key),
          ),
        );
      } else if (other.owner != key.owner) {
        issues.add(
          SmfIssue(
            'The $other and the $key would both be read as '
            'RemoteValues.${key.getter}.',
            hint: 'Rename one of the parameters.',
            origin: _parameterAtFault(other, key),
          ),
        );
      }
    }
    return issues;
  }

  /// The implementation and the start in `bootstrap()`, the section of the
  /// role in the README of the app, and the defaults and the getters of the
  /// parameters of the app in `RemoteValues`.
  @override
  RoleOutput render(RoleHookInput<RemoteConfigData> input) {
    final keys = remoteConfigRole.keysIn(input);
    return RoleOutput(
      fragments: [
        ...super.render(input).fragments,
        AppEntryRole.readmeSections.entry(
          RemoteConfigRole.readmeHeading,
          _remoteConfigReadme(keys),
        ),
      ],
      vars: {
        'remote_config_defaults': _defaultsCode(keys),
        'remote_config_getters': _gettersCode(keys),
      },
    );
  }

  /// The literal of the map of the defaults of [keys] in `RemoteValues`, as
  /// `dart format` writes it after [_defaultsHead]: on one line while the
  /// line fits, and an entry on each line otherwise.
  static String _defaultsCode(List<AppRemoteConfigKey> keys) {
    final entries = [
      for (final key in keys)
        '${SmfNames.dartString(key.name)}: ${key.key.defaultCode}',
    ];
    final inline = '{${entries.join(', ')}}';
    if ('$_defaultsHead$inline;'.length <= _pageWidth) return inline;
    return '{\n${[for (final entry in entries) '    $entry,\n'].join()}  }';
  }

  /// The line of the defaults in `RemoteValues` before their map.
  static const _defaultsHead = '  static const Map<String, Object> defaults = ';

  /// The width of a line that `dart format` keeps.
  static const _pageWidth = 80;

  /// The getters of [keys] in `RemoteValues`, as `dart format` writes them,
  /// each after an empty line and with its description as its doc: no code
  /// for an app without parameters, whose line in the template goes away.
  static Fragment _gettersCode(List<AppRemoteConfigKey> keys) =>
      Fragment([for (final key in keys) _getterCode(key)].join('\n'));

  /// The getter of [key] in `RemoteValues`, after an empty line: on one line
  /// while it fits, and with its body on the next line otherwise.
  static String _getterCode(AppRemoteConfigKey key) {
    final type = key.type.dartType;
    final head = '  $type get ${key.getter} =>';
    final body = '_values[${SmfNames.dartString(key.name)}]! as $type;';
    final getter = '$head $body'.length <= _pageWidth
        ? '$head $body'
        : '$head\n      $body';
    return '\n  /// ${key.description}\n$getter';
  }

  /// `bootstrap()` always awaits `initRemoteConfig()`, which starts
  /// `appRemoteConfig`.
  @override
  String bootstrap({required bool hasAsync}) => 'await $initFunction();';

  /// The service of the provider, and `initRemoteConfig()`, which creates it
  /// with the only implementation in [all] and starts `appRemoteConfig` with
  /// it.
  ///
  /// It may run again, so the variable is not final.
  @override
  String _single(
    List<_Prefixed> all,
    RoleHookInput<RemoteConfigData> input,
  ) {
    final (:implementation, :prefix) = all.single;
    final factory = implementation.factory.codeWith(prefix);
    return '''
late $service $variable;

/// Creates the service of the provider of remote config and starts
/// [appRemoteConfig] with it; `bootstrap()` awaits it before the first
/// frame, and nothing else in the app calls it. It waits at most
/// [AppRemoteConfigController.startWait] for the values that the device
/// kept.
///
/// It may run again, as a test does to see what the next launch of the app
/// finds: it creates the service anew, with what the device kept, and starts
/// [appRemoteConfig] with it.
Future<void> $initFunction() async {
  $variable = $factory();
  await appRemoteConfig.start($variable);
}''';
  }
}
