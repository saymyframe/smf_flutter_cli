import 'package:meta/meta.dart';
import 'package:smf_contracts/lego_core.dart';

/// What a socket accepts and how its contributions become text.
///
/// Four kinds take code [Fragment]s: [CodeSocket], [ArgsSocket],
/// [WrapperSocket] and [FactoryListSocket]. Two take plain values:
/// [KeyedSocket] and [ValueSocket]. The pipeline fills its own
/// [PipelineSocket]s. The set of kinds is closed because the pipeline handles
/// each of them; what is open are the [MergePolicy]s and renderers of keyed
/// and value sockets.
///
/// Each kind checks the shape of a contribution and renders the
/// contributions of a socket; use [SocketRef.problemsWith] and
/// [SocketRef.render].
@immutable
sealed class SocketKind {
  const SocketKind();

  /// Whether contributions to the socket carry Dart imports.
  ///
  /// The pipeline adds those imports to the file that holds the socket's
  /// tag, so such a tag must appear in exactly one file of the templates.
  /// Tags of the other sockets may appear in several places, such as a
  /// minimum iOS version used by both `project.pbxproj` and the `Podfile`.
  bool get carriesImports;

  /// Describes what is wrong with the payload of [c], a contribution to
  /// [socket], a socket of this kind.
  List<String> _payloadProblems(SocketRef socket, SocketContribution c);

  /// Renders [c], contributions already checked and in their final order,
  /// into the text of each tag of the socket whose tag is [tag].
  Map<String, String> _render(String tag, List<SocketContribution> c);
}

/// A socket for code, one [Fragment] after another in the order of their
/// contributors: statements, declarations, or, for a [CodeSocket.text],
/// lines of a non-Dart file such as XML.
final class CodeSocket extends SocketKind {
  /// Creates the kind for Dart code, whose fragments may carry imports.
  const CodeSocket() : carriesImports = true;

  /// Creates the kind for text of a non-Dart file, such as XML; its
  /// fragments carry no imports.
  const CodeSocket.text() : carriesImports = false;

  @override
  final bool carriesImports;

  @override
  List<String> _payloadProblems(SocketRef socket, SocketContribution c) => [
        ..._onlyFragment(socket, c, wrapper: false),
        if (!carriesImports && (c.fragment?.imports.isNotEmpty ?? false))
          '$socket is not Dart code and takes no imports.',
      ];

  @override
  Map<String, String> _render(String tag, List<SocketContribution> c) =>
      {tag: c.map((contribution) => contribution.fragment!.code).join('\n')};
}

/// Whether an argument of an [ArgsSocket] takes one value or a list.
enum ArgShape {
  /// One value, such as `theme:`. Two different values conflict.
  scalar,

  /// A list that unites the items of all contributions, such as
  /// `supportedLocales:`.
  list,
}

/// A socket for named arguments of a call, such as the arguments of
/// `MaterialApp`.
///
/// The socket declares which arguments it accepts, and renders them as
/// `name: value,` lines in that order. Each contribution sets one argument
/// to an expression; items of a list argument are united, dropping repeated
/// expressions, and two different values of a scalar argument conflict.
final class ArgsSocket extends SocketKind {
  /// Creates the kind for the arguments [args].
  const ArgsSocket(this.args);

  /// The accepted argument names and their shapes, in the order they are
  /// rendered.
  final Map<String, ArgShape> args;

  @override
  bool get carriesImports => true;

  @override
  List<String> _payloadProblems(SocketRef socket, SocketContribution c) {
    final problems = _onlyFragment(socket, c, wrapper: false, argument: true);
    if (!args.containsKey(c.argName)) {
      problems.add(
        '$socket has no argument "${c.argName}"; expected one of '
        '${args.keys.join(', ')}.',
      );
    }
    return problems;
  }

  @override
  Map<String, String> _render(String tag, List<SocketContribution> c) {
    final byName = <String, List<SocketContribution>>{};
    for (final contribution in c) {
      final name = contribution.argName!;
      final code = contribution.fragment!.code;
      final existing = byName.putIfAbsent(name, () => []);
      if (existing.any((other) => other.fragment!.code == code)) continue;
      if (args[name] == ArgShape.scalar && existing.isNotEmpty) {
        throw MergeConflict(
          name,
          existing.single.fragment!.code,
          code,
          'the argument takes one value',
          existingOrigin: existing.single.origin,
          incomingOrigin: contribution.origin,
        );
      }
      existing.add(contribution);
    }

    String codes(List<SocketContribution> items) =>
        items.map((item) => item.fragment!.code).join(', ');
    return {
      tag: [
        for (final MapEntry(key: name, value: shape) in args.entries)
          if (byName[name] case final items?)
            shape == ArgShape.scalar
                ? '$name: ${codes(items)},'
                : '$name: [${codes(items)}],',
      ].join('\n'),
    };
  }
}

/// A socket that wraps a piece of code, such as the root widget of the app.
///
/// It has two tags, `<tag>_open` and `<tag>_close`, around the wrapped code.
/// Each contribution is a [Fragment.wrap]: the first contribution becomes the
/// outermost wrapper.
final class WrapperSocket extends SocketKind {
  /// Creates the kind.
  const WrapperSocket();

  @override
  bool get carriesImports => true;

  @override
  List<String> _payloadProblems(SocketRef socket, SocketContribution c) =>
      _onlyFragment(socket, c, wrapper: true);

  @override
  Map<String, String> _render(String tag, List<SocketContribution> c) => {
        '${tag}_open': c.map((wrapper) => wrapper.fragment!.code).join(),
        '${tag}_close':
            c.reversed.map((wrapper) => wrapper.fragment!.closing!).join(),
      };
}

/// A socket for a list of factory expressions, such as
/// `() => MyNavigatorObserver()`, that the owner of the socket calls as many
/// times as it needs instances.
///
/// It renders the factories as list items, each followed by a comma.
final class FactoryListSocket extends SocketKind {
  /// Creates the kind.
  const FactoryListSocket();

  @override
  bool get carriesImports => true;

  @override
  List<String> _payloadProblems(SocketRef socket, SocketContribution c) =>
      _onlyFragment(socket, c, wrapper: false);

  @override
  Map<String, String> _render(String tag, List<SocketContribution> c) => {
        tag: c.map((factory) => '${factory.fragment!.code},').join('\n'),
      };
}

/// A socket for entries with a key, such as Android permissions or Gradle
/// plugins.
///
/// Entries with the same key are merged by the socket's [policy]; the
/// merged entries keep the order in which their keys were first contributed.
/// Entries carry no imports.
final class KeyedSocket<V extends Object> extends SocketKind {
  /// Creates the kind with a merge [policy] and a [renderer] of the merged
  /// entries, which gets them in the order their keys were first
  /// contributed.
  const KeyedSocket({
    required this.policy,
    required String Function(List<MapEntry<String, V>> entries) renderer,
  }) : _renderer = renderer;

  /// How two values for one key merge.
  final MergePolicy<V> policy;

  final String Function(List<MapEntry<String, V>> entries) _renderer;

  @override
  bool get carriesImports => false;

  /// Whether [value] can be contributed to the socket.
  bool accepts(Object? value) => value is V;

  @override
  List<String> _payloadProblems(SocketRef socket, SocketContribution c) {
    final key = c.entryKey;
    final value = c.entryValue;
    if (c.fragment != null || c.argName != null || key == null) {
      return ['$socket takes keyed entries.'];
    }
    if (value is! V) return ['$socket takes values of type $V, not $value.'];
    return [
      if (policy.problemWith(key, value) case final problem?) problem,
    ];
  }

  /// Merges the entries of [contributions] by key with the [policy].
  ///
  /// A [MergeConflict] names the contributors of both values. Throws an
  /// [ArgumentError] for a contribution without a key or with a value of
  /// the wrong type.
  List<MapEntry<String, V>> merge(Iterable<SocketContribution> contributions) {
    final merged = <String, V>{};
    final origins = <String, ContributionOrigin?>{};
    for (final contribution in contributions) {
      final key = contribution.entryKey ??
          (throw ArgumentError.value(contribution, 'contributions', 'No key'));
      final value = _cast<V>(contribution.entryValue);
      final existing = merged[key];
      if (existing == null) {
        merged[key] = value;
        origins[key] = contribution.origin;
        continue;
      }
      try {
        final result = policy.merge(key, existing, value);
        if (identical(result, value)) origins[key] = contribution.origin;
        merged[key] = result;
      } on MergeConflict catch (conflict) {
        throw conflict.withOrigins(
          existing: origins[key],
          incoming: contribution.origin,
        );
      }
    }
    return merged.entries.toList();
  }

  @override
  Map<String, String> _render(String tag, List<SocketContribution> c) =>
      {tag: _renderer(merge(c))};
}

/// A socket for one value merged from all contributions, such as the
/// minimum iOS version of the app.
///
/// Values carry no imports.
final class ValueSocket<V extends Object> extends SocketKind {
  /// Creates the kind with a merge [policy] and a [renderer] of the merged
  /// value; set [required] if the socket cannot render without a value.
  const ValueSocket({
    required this.policy,
    required String Function(V value) renderer,
    this.required = false,
  }) : _renderer = renderer;

  /// How two contributed values merge.
  final MergePolicy<V> policy;

  /// Whether the socket needs at least one contribution, such as a minimum
  /// version that the template cannot leave empty.
  ///
  /// The owner of the socket's template contributes the base value.
  final bool required;

  final String Function(V value) _renderer;

  @override
  bool get carriesImports => false;

  /// Whether [value] can be contributed to the socket.
  bool accepts(Object? value) => value is V;

  @override
  List<String> _payloadProblems(SocketRef socket, SocketContribution c) {
    final value = c.entryValue;
    if (c.fragment != null || c.argName != null || c.entryKey != null) {
      return ['$socket takes a single value.'];
    }
    if (value is! V) return ['$socket takes values of type $V, not $value.'];
    return [
      if (policy.problemWith(socket.tag, value) case final problem?) problem,
    ];
  }

  /// Merges the values of [contributions] with the [policy], or returns
  /// `null` if there are none.
  ///
  /// [key] names the socket in a [MergeConflict], which also names the
  /// contributors of both values. Throws an [ArgumentError] for a value of
  /// the wrong type.
  V? merge(Iterable<SocketContribution> contributions, {required String key}) {
    V? merged;
    ContributionOrigin? origin;
    for (final contribution in contributions) {
      final value = _cast<V>(contribution.entryValue);
      if (merged == null) {
        merged = value;
        origin = contribution.origin;
        continue;
      }
      try {
        final result = policy.merge(key, merged, value);
        if (identical(result, value)) origin = contribution.origin;
        merged = result;
      } on MergeConflict catch (conflict) {
        throw conflict.withOrigins(
          existing: origin,
          incoming: contribution.origin,
        );
      }
    }
    return merged;
  }

  @override
  Map<String, String> _render(String tag, List<SocketContribution> c) {
    final merged = merge(c, key: tag);
    if (merged == null && required) {
      throw StateError(
        '$tag needs a value; the owner of its template contributes the base '
        'one.',
      );
    }
    return {tag: merged == null ? '' : _renderer(merged)};
  }
}

/// A socket the pipeline fills itself, such as the dependencies section of
/// `pubspec.yaml`.
///
/// Modules cannot contribute to it directly; they contribute a
/// [PubspecContribution] instead, which the pipeline merges and renders.
final class PipelineSocket extends SocketKind {
  const PipelineSocket._();

  @override
  bool get carriesImports => false;

  @override
  List<String> _payloadProblems(SocketRef socket, SocketContribution c) =>
      ['$socket is filled by the pipeline and takes no contributions.'];

  @override
  Map<String, String> _render(String tag, List<SocketContribution> c) =>
      throw StateError('The pipeline renders $tag from the merged pubspec.');
}

/// The value of the entries of a [KeyedSocket] whose entries are only keys,
/// such as the permissions of the Android manifest.
@immutable
final class NoValue {
  /// The only value.
  const NoValue();

  @override
  bool operator ==(Object other) => other is NoValue;

  @override
  int get hashCode => (NoValue).hashCode;

  @override
  String toString() => 'NoValue';
}

List<String> _onlyFragment(
  SocketRef socket,
  SocketContribution c, {
  required bool wrapper,
  bool argument = false,
}) {
  final fragment = c.fragment;
  return [
    if (fragment == null || fragment.isWrapper != wrapper)
      '$socket takes a ${wrapper ? 'Fragment.wrap' : 'Fragment of code'}.',
    if (c.entryKey != null || c.entryValue != null)
      '$socket takes no keyed entries or values.',
    if (!argument && c.argName != null) '$socket takes no argument names.',
  ];
}

V _cast<V extends Object>(Object? value) {
  if (value is V) return value;
  throw ArgumentError.value(
    value,
    'value',
    'Expected a $V, got a ${value.runtimeType}',
  );
}

String _ownerName(Role? role, ModuleId? module) =>
    role?.id ?? module?.value ?? 'pipeline';

/// A reference to a socket: a named place in a template that receives
/// contributions of the kind [K].
///
/// A socket belongs to a role, to a module, or to the pipeline. A template
/// marks it with a tag, `{{{<tag>}}}`, and the pipeline replaces the tag
/// with the rendered contributions. Usually the owner's template holds the
/// tag; a member of a [SocketFamily] may be tagged in the files its key
/// refers to, such as the screen file of a feature. Modules refer to sockets
/// only through these typed references, never by tag, so a misspelled socket
/// does not compile.
///
/// Who may contribute to a socket:
/// - a socket of a role: modules that provide, require or use the role, and
///   the templates of the role and of the roles that require or use it;
/// - a socket of a module: modules that depend on that module directly;
/// - a socket of the pipeline: nobody, see [PipelineSocket].
///
/// The sockets of a role that is [Role.openToAllModules], such as the app
/// entry, are open to every module. See [SocketContribution] for the order
/// of contributions.
@immutable
final class SocketRef<K extends SocketKind> {
  /// Refers to the socket [name] of [role].
  const SocketRef.role(Role this.role, this.name, this.kind)
      : module = null,
        familyKey = const [];

  /// Refers to the socket [name] of the module [module].
  ///
  /// Only modules that depend on [module] directly may contribute to it.
  const SocketRef.module(ModuleId this.module, this.name, this.kind)
      : role = null,
        familyKey = const [];

  const SocketRef._pipeline(this.name, this.kind)
      : role = null,
        module = null,
        familyKey = const [];

  const SocketRef._family({
    required this.role,
    required this.module,
    required this.name,
    required this.kind,
    required this.familyKey,
  });

  /// The role that owns the socket, if a role does.
  final Role? role;

  /// The module that owns the socket, if a module does.
  final ModuleId? module;

  /// The name of the socket, in lower snake_case and unique for its owner.
  final String name;

  /// What the socket accepts.
  final K kind;

  /// The key segments of a member of a [SocketFamily], empty otherwise.
  final List<String> familyKey;

  /// Whether the pipeline owns the socket.
  bool get isPipeline => role == null && module == null;

  /// The name of the owner: the id of the role or module, or `pipeline`.
  String get ownerName => _ownerName(role, module);

  /// The name of the socket's tag in templates, such as
  /// `smf_app_entry__bootstrap_platform`.
  ///
  /// It joins `smf_`, the owner and the name, plus the key of a family
  /// member, with double underscores; names never contain one. The
  /// pipeline's own sockets have no owner part, as in
  /// `smf_pubspec_dependencies`.
  String get tag => isPipeline
      ? 'smf_$name'
      : 'smf_${[ownerName, name, ...familyKey].join('__')}';

  /// The tags of the socket: [tag], or `<tag>_open` and `<tag>_close` for a
  /// [WrapperSocket].
  List<String> get tags =>
      kind is WrapperSocket ? ['${tag}_open', '${tag}_close'] : [tag];

  /// Describes what is wrong with the name of this socket, or returns an
  /// empty list.
  ///
  /// The key of a member of a [SocketFamily] is checked when the member is
  /// created.
  List<String> problems() => [
        if (!SmfNames.isSnakeCase(name))
          'The socket name "$name" of $ownerName is not lower snake_case.',
      ];

  /// Describes what is wrong with [contribution] to this socket, or returns
  /// an empty list: a contribution for another socket, a payload of the
  /// wrong shape or type, an unknown argument, a value the merge policy
  /// rejects, or a problem of its fragment.
  List<String> problemsWith(SocketContribution contribution) {
    return [
      if (contribution.socket != this)
        'The contribution is for the ${contribution.socket}, not $this.',
      ...kind._payloadProblems(this, contribution),
      ...?contribution.fragment?.problems(),
    ];
  }

  /// Renders [contributions] to this socket, already in their final order,
  /// and returns the text of each of the socket's [tags].
  ///
  /// Throws an [ArgumentError] for a contribution this socket does not take
  /// (see [problemsWith]) or for text that mason would change (see
  /// [Fragment.hasStrippedBackslash]), a [MergeConflict] for values that
  /// cannot be merged, and a [StateError] for a [ValueSocket.required]
  /// socket without contributions or a socket of the pipeline.
  Map<String, String> render(List<SocketContribution> contributions) {
    for (final contribution in contributions) {
      final problems = problemsWith(contribution);
      if (problems.isNotEmpty) {
        throw ArgumentError.value(
          contribution,
          'contributions',
          problems.first,
        );
      }
    }
    final rendered = kind._render(tag, contributions);
    for (final MapEntry(key: name, value: text) in rendered.entries) {
      if (Fragment.hasStrippedBackslash(text)) {
        throw ArgumentError.value(
          text,
          'contributions',
          'The text of $name has a backslash that mason would remove',
        );
      }
    }
    return rendered;
  }

  @override
  bool operator ==(Object other) =>
      other is SocketRef &&
      identical(other.role, role) &&
      other.module == module &&
      other.name == name &&
      other.kind.runtimeType == kind.runtimeType &&
      _sameSegments(other.familyKey, familyKey);

  @override
  int get hashCode => Object.hash(
        identityHashCode(role),
        module,
        name,
        kind.runtimeType,
        Object.hashAll(familyKey),
      );

  static bool _sameSegments(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'socket ${[ownerName, name, ...familyKey].join('.')}';
}

/// A family of sockets of the same kind, one per key, such as the
/// annotations of every screen of the router.
///
/// A member is a [SocketRef] whose tag is [tagPrefix] followed by the key's
/// segments; calling the family with a key returns it. Roles and modules
/// declare their families next to their sockets, so the pipeline recognizes
/// the tags of members with [memberOfTag].
@immutable
final class SocketFamily<Key, K extends SocketKind> {
  /// Creates the family [name] of [role]; [keyOf] turns a key into the lower
  /// snake_case segments of a member's tag, of which there are [segments] if
  /// that is set.
  const SocketFamily.role(
    Role this.role,
    this.name,
    this.kind, {
    required List<String> Function(Key key) keyOf,
    this.segments,
  })  : module = null,
        _keyOf = keyOf;

  /// Creates the family [name] of the module [module]; [keyOf] turns a key
  /// into the lower snake_case segments of a member's tag, of which there
  /// are [segments] if that is set.
  const SocketFamily.module(
    ModuleId this.module,
    this.name,
    this.kind, {
    required List<String> Function(Key key) keyOf,
    this.segments,
  })  : role = null,
        _keyOf = keyOf;

  /// The role that owns the family, if a role does.
  final Role? role;

  /// The module that owns the family, if a module does.
  final ModuleId? module;

  /// The name of the family, in lower snake_case.
  final String name;

  /// What every member of the family accepts.
  final K kind;

  /// How many segments the key of every member has, or `null` for any
  /// number.
  ///
  /// With a fixed number, [memberOfTag] tells a member's tag from a tag
  /// that only starts like one, such as a misspelled tag.
  final int? segments;

  final List<String> Function(Key key) _keyOf;

  /// The name of the owner: the id of the role or module.
  String get ownerName => _ownerName(role, module);

  /// The start of the tag of every member, such as
  /// `smf_router__screen_annotations__`.
  String get tagPrefix => 'smf_${ownerName}__${name}__';

  /// Returns the member of the family for [key].
  ///
  /// Throws an [ArgumentError] if the key has no segments, a segment that is
  /// not lower snake_case, or a number of segments other than [segments].
  SocketRef<K> call(Key key) {
    final member = _member(_keyOf(key));
    if (member == null) {
      throw ArgumentError.value(
        key,
        'key',
        'The key of a member of $name must be '
            '${segments ?? 'one or more'} lower snake_case segments',
      );
    }
    return member;
  }

  /// Returns the member whose tag is [tag], such as a tag found in a
  /// template, or `null` if [tag] is not the tag of a member.
  ///
  /// For a [WrapperSocket], [tag] may be either of the member's tags.
  SocketRef<K>? memberOfTag(String tag) {
    var base = tag;
    if (kind is WrapperSocket) {
      for (final suffix in const ['_open', '_close']) {
        if (base.endsWith(suffix)) {
          base = base.substring(0, base.length - suffix.length);
          break;
        }
      }
    }
    if (!base.startsWith(tagPrefix)) return null;
    return _member(base.substring(tagPrefix.length).split('__'));
  }

  SocketRef<K>? _member(List<String> key) {
    if (key.isEmpty ||
        (segments != null && key.length != segments) ||
        !key.every(SmfNames.isSnakeCase)) {
      return null;
    }
    return SocketRef<K>._family(
      role: role,
      module: module,
      name: name,
      kind: kind,
      familyKey: List.unmodifiable(key),
    );
  }
}

/// The sockets of the pipeline in the templates of the app.
///
/// The owner of `pubspec.yaml` puts their tags at the start of a line, each
/// on its own line. The pipeline renders each merged section there, headed
/// by its key, such as `dependencies:`.
abstract final class PipelineSockets {
  /// The `environment:` section: the SDK constraints of all
  /// [PubspecContribution.environment]s.
  static const pubspecEnvironment =
      SocketRef<PipelineSocket>._pipeline('pubspec_environment', _kind);

  /// The `dependencies:` section.
  static const pubspecDependencies =
      SocketRef<PipelineSocket>._pipeline('pubspec_dependencies', _kind);

  /// The `dev_dependencies:` section.
  static const pubspecDevDependencies =
      SocketRef<PipelineSocket>._pipeline('pubspec_dev_dependencies', _kind);

  /// The `flutter:` section: assets, fonts and code generation flags of all
  /// [PubspecContribution.flutter]s.
  static const pubspecFlutter =
      SocketRef<PipelineSocket>._pipeline('pubspec_flutter', _kind);

  /// All sockets of the pipeline.
  static const List<SocketRef<PipelineSocket>> all = [
    pubspecEnvironment,
    pubspecDependencies,
    pubspecDevDependencies,
    pubspecFlutter,
  ];

  static const _kind = PipelineSocket._();
}
