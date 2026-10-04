import 'package:mason/mason.dart' show MasonBundle;
import 'package:meta/meta.dart';
import 'package:smf_contracts/bundles/analytics_role_bundle.dart';
import 'package:smf_contracts/bundles/crash_reporting_role_bundle.dart';
import 'package:smf_contracts/bundles/events_role_bundle.dart';
import 'package:smf_contracts/bundles/preferences_role_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contracts/src/roles/symbol_uses.dart';

part 'services/analytics.dart';
part 'services/crash_reporting.dart';
part 'services/events.dart';
part 'services/preferences.dart';

/// The implementation of a service role that a provider contributes as its
/// data, such as the Firebase implementation of `AnalyticsService`.
///
/// The service roles are [eventsRole], [preferencesRole], [analyticsRole]
/// and [crashReportingRole]. Each generates the interface of its service
/// and a factory that returns the implementation, or, for a role with many
/// providers, one service that forwards every call to all of them. Every
/// provider contributes exactly one implementation:
///
/// ```dart
/// analyticsRole.data(
///   const RoleImplementation(
///     type: TypeRef('FirebaseAnalyticsService', import: file),
///     create: FactoryRef('createFirebaseAnalyticsService', import: file),
///   ),
/// )
/// ```
///
/// The factory takes no services: the services work without a DI
/// container. The role registers its service in the DI container when one
/// is present.
///
/// A role that an app can have several providers of creates each
/// implementation on its own: one whose factory throws, or whose
/// asynchronous start fails, is left out, so that the app starts and the
/// other implementations work without it, and in debug mode its error is
/// printed with the name of its factory.
@immutable
final class RoleImplementation {
  /// An implementation of [type] that [create] returns.
  const RoleImplementation({
    required this.type,
    required FactoryRef this.create,
  }) : init = null;

  /// An implementation of [type] created asynchronously: [init] returns a
  /// `Future` of it, which the role awaits in the platform phase of
  /// `bootstrap()`.
  const RoleImplementation.async({
    required this.type,
    required FactoryRef this.init,
  }) : create = null;

  /// The class of the implementation.
  final TypeRef type;

  /// The function that returns the implementation, if it is created
  /// synchronously.
  final FactoryRef? create;

  /// The function that returns a `Future` of the implementation, if it is
  /// created asynchronously.
  final FactoryRef? init;

  /// Whether the implementation is created asynchronously.
  bool get isAsync => init != null;

  /// The function that creates the implementation: [create] or [init].
  FactoryRef get factory => create ?? init!;

  /// Describes what is wrong with the implementation, or returns an empty
  /// list.
  List<String> problems() => [
        ...type.problems(),
        ...factory.problems(),
        if (factory.deps.isNotEmpty)
          'The factory ${factory.name} of $type must take no services.',
      ];

  @override
  String toString() => 'implementation $type';
}

List<SmfIssue> _checkImplementations(
  ModuleRuleInput<RoleImplementation> input,
) {
  final role = input.roleInput.role;
  final provides = input.module.provides.contains(role);
  final origin = ModuleOrigin(input.module.id);
  // The rule is of the service roles, whose templates render the
  // implementations into a socket of their own. The other sockets of such a
  // role are for the modules, such as the restorers of the preferences.
  final implementations = (role.template! as _ServiceTemplate).implementations;
  return [
    for (final contribution in input.contributions)
      if (contribution is SocketContribution &&
          contribution.socket == implementations)
        SmfIssue(
          'The module contributes code to the ${contribution.socket}, which '
          'the template of the role fills from the implementations.',
          hint: 'Contribute a RoleImplementation instead.',
          origin: origin,
        ),
    if (!provides && input.data.isNotEmpty)
      SmfIssue(
        'The module contributes an implementation to the $role, which only '
        'its providers do.',
        origin: origin,
      ),
    if (provides && input.data.length != 1)
      SmfIssue(
        'A provider of the $role contributes exactly one implementation, but '
        'the module contributes ${input.data.length}.',
        origin: origin,
      ),
  ];
}

const _implementationsRule = ModuleRule<RoleImplementation>(
  id: 'services.implementations',
  description: 'Every provider of a service role, and only a provider, '
      'contributes one implementation, and no module contributes code to the '
      'socket of the implementations of the role.',
  check: _checkImplementations,
);

/// The problems of files of modules in [input] that call or tear off
/// [factory], the function in the role's [file] that returns the service of
/// a service role, unless the module provides the DI role.
///
/// Only the DI container creates the service; other code receives it through
/// `resolve` in a composition file or through the dependencies of its own
/// factory, so there is one way to get a service. [hint] tells the owner of
/// a file what to do instead.
///
/// With [templates], the files of the templates of other roles are checked
/// too: for a role that gives them its service in a way of its own, as the
/// preferences do with their restorers.
List<SmfIssue> _checkFactoryCalls(
  StructuralRuleInput<RoleImplementation> input,
  String factory,
  String file, {
  String hint = 'Resolve the service in the composition file of a feature, '
      'or take it as a dependency of your own factory.',
  bool templates = false,
}) {
  final issues = <SmfIssue>[];
  for (final MapEntry(key: path, value: index) in input.files.entries) {
    final owner = input.owners[path];
    final mayCall = switch (owner) {
      ModuleOrigin(:final module) =>
        input.module(module)?.provides.contains(diRole) ?? false,
      // The template of the role itself declares the factory.
      RoleTemplateOrigin(:final role) =>
        !templates || identical(role, input.roleInput.role),
      _ => true,
    };
    if (mayCall || !usesSymbols(index, {factory}, file)) continue;
    issues.add(
      SmfIssue(
        '$path calls $factory(), which only the DI container calls.',
        hint: hint,
        origin: owner,
        path: path,
      ),
    );
  }
  return issues;
}

/// The problems with the functions that the implementations of the role in
/// [input] name: a function missing from its file of the app, or one that
/// needs arguments, since the template calls it without any.
///
/// Functions from other packages are left to the compiler.
List<SmfIssue> _checkImplementationFactories(
  StructuralRuleInput<RoleImplementation> input,
) {
  final issues = <SmfIssue>[];
  for (final data in input.roleInput.data) {
    final factory = data.value.factory;
    if (!factory.import.isAppFile) continue;
    final symbol = RequiredFunction(
      factory.name,
      path: 'lib/${factory.import.uri}',
    );
    for (final issue in symbol.checkIn(input.files)) {
      issues.add(
        SmfIssue(
          issue.message,
          hint: 'The template of the role calls it without arguments.',
          origin: data.origin,
          path: issue.path,
        ),
      );
    }
  }
  return issues;
}

/// The template shared by the service roles: the brick with the service's
/// interface, the implementations in the socket [implementations], and the
/// registration of the service in the DI container.
abstract base class _ServiceTemplate extends RoleTemplate<RoleImplementation> {
  const _ServiceTemplate();

  Role<RoleImplementation> get role;

  MasonBundle get bundle;

  /// The path of the file of the brick, relative to the project root.
  String get file;

  /// The interface of the service, such as `AnalyticsService`.
  String get service;

  /// The function that returns the service, such as
  /// `createAnalyticsService`.
  String get factory;

  /// The function that creates the implementations created asynchronously,
  /// such as `initAnalytics`.
  String get initFunction;

  /// The name of the private variable with the implementations, or with the
  /// only implementation for a role with at most one provider.
  String get variable;

  SocketRef<CodeSocket> get implementations;

  ImportRef get import => ImportRef.app(file.substring('lib/'.length));

  bool get single => !role.cardinality.allowsMany;

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        diRole.data(
          DiRegistration(
            type: TypeRef(service, import: import),
            create: FactoryRef(factory, import: import),
          ),
        ),
      ];

  /// Checks each implementation; the module rule of the role checks that
  /// every provider contributes exactly one.
  @override
  List<SmfIssue> validate(RoleHookInput<RoleImplementation> input) => [
        for (final data in input.data)
          for (final problem in data.value.problems())
            SmfIssue(problem, origin: data.origin),
      ];

  /// Renders the implementations into [implementations].
  ///
  /// The file of each implementation is imported with a prefix of the
  /// template's own, `impl0`, `impl1` and so on, so that no factory can hide
  /// or be hidden by a name of the template or of another implementation.
  ///
  /// [input] has an implementation from every provider, as the rule of the
  /// role makes sure before an app renders, so a role that has one provider
  /// has one implementation.
  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) {
    final all = [
      for (final (index, data) in input.data.indexed)
        (implementation: data.value, prefix: 'impl$index'),
    ];
    final asynchronous = [
      for (final entry in all)
        if (entry.implementation.isAsync) entry,
    ];
    return RoleOutput(
      fragments: [
        SocketContribution.code(
          implementations,
          Fragment(
            single ? _single(all) : _many(all),
            imports: [
              for (final entry in all)
                entry.implementation.factory.import.withPrefix(entry.prefix),
              if (!single) _foundation,
            ],
          ),
        ),
        if (bootstrap(hasAsync: asynchronous.isNotEmpty) case final code?)
          SocketContribution.code(
            AppEntryRole.bootstrapPlatform,
            Fragment(code, imports: [import]),
          ),
      ],
    );
  }

  /// The code of the platform phase of `bootstrap()`, or `null` if the role
  /// needs none.
  String? bootstrap({required bool hasAsync}) =>
      hasAsync ? 'await $initFunction();' : null;

  /// The code of the only implementation in [all]; see [render]. A role
  /// that does more with its implementation than create it, such as the
  /// preferences, renders it otherwise.
  String _single(List<_Prefixed> all) {
    final (:implementation, :prefix) = all.single;
    final factory = implementation.factory.codeWith(prefix);
    if (!implementation.isAsync) {
      return 'final $service $variable = $factory();';
    }
    return '''
late final $service $variable;

/// Creates the $service of the app, which starts asynchronously;
/// `bootstrap()` awaits it.
Future<void> $initFunction() async {
  $variable = await $factory();
}''';
  }

  /// The code of the implementations in [all], for a role that an app can
  /// have several providers of; see [render].
  ///
  /// Each implementation is created on its own: one whose factory throws,
  /// or whose asynchronous start fails, is left out, so that the app starts
  /// and the others work without it, and in debug mode its error is
  /// printed with the name of its factory. The functions that do so,
  /// `_createAlone` and `_startAlone`, come with the implementations that
  /// need them.
  String _many(List<_Prefixed> all) {
    final synchronous = [
      for (final entry in all)
        if (!entry.implementation.isAsync) entry,
    ];
    final asynchronous = [
      for (final entry in all)
        if (entry.implementation.isAsync) entry,
    ];
    final buffer = StringBuffer('final List<$service> $variable = [\n');
    for (final (:implementation, :prefix) in synchronous) {
      final factory = implementation.factory;
      buffer.writeln(
        "  ?_createAlone('${factory.name}', ${factory.codeWith(prefix)}),",
      );
    }
    buffer.write('];');
    if (asynchronous.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('/// Creates the implementations of $service that start')
        ..writeln('/// asynchronously; `bootstrap()` awaits it.')
        ..writeln('Future<void> $initFunction() async {')
        ..writeln('  final started = await Future.wait([');
      for (final (:implementation, :prefix) in asynchronous) {
        final factory = implementation.factory;
        buffer.writeln(
          "    _startAlone('${factory.name}', ${factory.codeWith(prefix)}),",
        );
      }
      buffer
        ..writeln('  ]);')
        ..writeln('  $variable.addAll(started.nonNulls);')
        ..write('}');
    }
    if (synchronous.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..write(_createAlone);
    }
    if (asynchronous.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..write(_startAlone);
    }
    return '$buffer';
  }

  /// The function of [_many] that creates an implementation on its own.
  String get _createAlone => '''
/// Calls [create], the function [name], on its own: returns what it
/// creates, or `null` if it throws, so that the app works without it, and
/// in debug mode prints the error.
$service? _createAlone(String name, $service Function() create) {
  try {
    return create();
  } on Object catch (error) {
    if (kDebugMode) {
      debugPrint('\$name() failed, so the app works without it: \$error');
    }
    return null;
  }
}''';

  /// The function of [_many] that starts an implementation on its own.
  String get _startAlone => '''
/// Calls [start], the function [name], on its own: returns what it starts,
/// or `null` if it throws or its future fails, so that the app starts and
/// works without it, and in debug mode prints the error.
Future<$service?> _startAlone(
  String name,
  Future<$service> Function() start,
) async {
  try {
    return await start();
  } on Object catch (error) {
    if (kDebugMode) {
      debugPrint('\$name() failed, so the app works without it: \$error');
    }
    return null;
  }
}''';
}

/// An implementation and the prefix of the import of its file.
typedef _Prefixed = ({RoleImplementation implementation, String prefix});

/// The library of `kDebugMode` and `debugPrint`, which the code of the
/// implementations of a role that an app can have several providers of
/// uses; see `_ServiceTemplate._many`.
const _foundation = ImportRef('package:flutter/foundation.dart');
