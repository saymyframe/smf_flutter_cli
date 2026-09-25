import 'package:meta/meta.dart';
import 'package:smf_contracts/lego_core.dart';

/// What a socket accepts and how its contributions become text.
///
/// Four kinds take code [Fragment]s, which carry imports: [CodeSocket],
/// [ArgsSocket], [WrapperSocket] and [FactoryListSocket]. Two take plain
/// values, which do not: [KeyedSocket] and [ValueSocket]. The pipeline fills
/// its own [PipelineSocket]s. The set of kinds is closed because the pipeline
/// handles each of them; what is open are the [MergePolicy]s and renderers
/// of keyed and value sockets.
@immutable
sealed class SocketKind {
  const SocketKind();

  /// Whether contributions to the socket carry imports.
  ///
  /// The pipeline adds those imports to the file that holds the socket's
  /// tag, so such a tag must appear in exactly one file of the templates.
  /// Tags of the other kinds may appear in several places, such as a minimum
  /// iOS version used by both `project.pbxproj` and the `Podfile`.
  bool get carriesImports;
}

/// A socket for statements or declarations, one [Fragment] after another in
/// the order of their contributors.
final class CodeSocket extends SocketKind {
  /// Creates the kind.
  const CodeSocket();

  @override
  bool get carriesImports => true;

  /// Renders [fragments], in order, one per line.
  String render(List<Fragment> fragments) =>
      fragments.map((fragment) => fragment.code).join('\n');
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
/// The socket declares which arguments it accepts. Each contribution sets one
/// argument to an expression.
final class ArgsSocket extends SocketKind {
  /// Creates the kind for the arguments [args].
  const ArgsSocket(this.args);

  /// The accepted argument names and their shapes, in the order they are
  /// rendered.
  final Map<String, ArgShape> args;

  @override
  bool get carriesImports => true;

  /// Renders the arguments set by [values], pairs of an argument name and
  /// its expression, as `name: value,` lines in the order of [args].
  ///
  /// Items of a list argument are united, dropping repeated expressions.
  /// Throws an [ArgumentError] for an argument not in [args] and a
  /// [MergeConflict] for two different values of a scalar argument.
  String render(List<(String, Fragment)> values) {
    final byName = <String, List<String>>{};
    for (final (name, value) in values) {
      final shape = args[name];
      if (shape == null) {
        throw ArgumentError.value(
          name,
          'name',
          'Unknown argument; expected one of ${args.keys.join(', ')}',
        );
      }
      final existing = byName.putIfAbsent(name, () => []);
      if (existing.contains(value.code)) continue;
      if (shape == ArgShape.scalar && existing.isNotEmpty) {
        throw MergeConflict(
          name,
          existing.single,
          value.code,
          'the argument takes one value',
        );
      }
      existing.add(value.code);
    }

    return [
      for (final MapEntry(key: name, value: shape) in args.entries)
        if (byName[name] case final items?)
          shape == ArgShape.scalar
              ? '$name: ${items.single},'
              : '$name: [${items.join(', ')}],',
    ].join('\n');
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

  /// Renders the opening parts of [wrappers], outermost first.
  String renderOpening(List<Fragment> wrappers) =>
      wrappers.map((wrapper) => wrapper.code).join();

  /// Renders the closing parts of [wrappers], innermost first.
  String renderClosing(List<Fragment> wrappers) =>
      wrappers.reversed.map((wrapper) => wrapper.closing ?? '').join();
}

/// A socket for a list of factory expressions, such as
/// `() => MyNavigatorObserver()`, that the owner of the socket calls as many
/// times as it needs instances.
final class FactoryListSocket extends SocketKind {
  /// Creates the kind.
  const FactoryListSocket();

  @override
  bool get carriesImports => true;

  /// Renders [factories] as list items, each followed by a comma.
  String render(List<Fragment> factories) =>
      factories.map((factory) => '${factory.code},').join('\n');
}

/// A socket for entries with a key, such as Android permissions or Gradle
/// plugins.
///
/// Entries with the same key are merged by the socket's [policy]; the
/// merged entries keep the order in which their keys were first contributed.
/// Entries carry no imports.
final class KeyedSocket<V extends Object> extends SocketKind {
  /// Creates the kind with a merge [policy] and a [renderer] of the merged
  /// entries.
  const KeyedSocket({required this.policy, required this.renderer});

  /// How two values for one key merge.
  final MergePolicy<V> policy;

  /// Renders the merged entries, in the order their keys were first
  /// contributed.
  final String Function(List<MapEntry<String, V>> entries) renderer;

  @override
  bool get carriesImports => false;

  /// Whether [value] can be contributed to the socket.
  bool accepts(Object? value) => value is V;

  /// Merges [entries], pairs of a key and a value, by key.
  ///
  /// Throws an [ArgumentError] for a value of the wrong type and a
  /// [MergeConflict] for values the [policy] cannot merge.
  List<MapEntry<String, V>> merge(Iterable<(String, Object)> entries) {
    final merged = <String, V>{};
    for (final (key, value) in entries) {
      final typed = _cast<V>(value);
      final existing = merged[key];
      merged[key] =
          existing == null ? typed : policy.merge(key, existing, typed);
    }
    return merged.entries.toList();
  }

  /// Merges [entries] and renders the result.
  String render(Iterable<(String, Object)> entries) => renderer(merge(entries));
}

/// A socket for one value merged from all contributions, such as the
/// minimum iOS version of the app.
///
/// Values carry no imports.
final class ValueSocket<V extends Object> extends SocketKind {
  /// Creates the kind with a merge [policy] and a [renderer] of the merged
  /// value.
  const ValueSocket({required this.policy, required this.renderer});

  /// How two contributed values merge.
  final MergePolicy<V> policy;

  /// Renders the merged value.
  final String Function(V value) renderer;

  @override
  bool get carriesImports => false;

  /// Whether [value] can be contributed to the socket.
  bool accepts(Object? value) => value is V;

  /// Merges [values], or returns `null` if there are none.
  ///
  /// [key] names the socket in a [MergeConflict]. Throws an [ArgumentError]
  /// for a value of the wrong type.
  V? merge(Iterable<Object> values, {required String key}) {
    V? merged;
    for (final value in values) {
      final typed = _cast<V>(value);
      merged = merged == null ? typed : policy.merge(key, merged, typed);
    }
    return merged;
  }

  /// Merges [values] and renders the result, or returns an empty string if
  /// there are none.
  String render(Iterable<Object> values, {required String key}) {
    final merged = merge(values, key: key);
    return merged == null ? '' : renderer(merged);
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

V _cast<V extends Object>(Object value) {
  if (value is V) return value;
  throw ArgumentError.value(
    value,
    'value',
    'Expected a $V, got a ${value.runtimeType}',
  );
}

/// A reference to a socket: a named place in a template that receives
/// contributions of the kind [K].
///
/// A socket belongs to a role, to a module, or to the pipeline. The owner's
/// template marks the socket with a tag, `{{{<tag>}}}`, and the pipeline
/// replaces the tag with the rendered contributions. Modules refer to sockets
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
/// entry, are open to every module.
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

  /// The key segments of a socket of a [SocketFamily], empty otherwise.
  final List<String> familyKey;

  /// Whether the pipeline owns the socket.
  bool get isPipeline => role == null && module == null;

  /// The name of the owner: the id of the role or module, or `pipeline`.
  String get ownerName => role?.id ?? module?.value ?? 'pipeline';

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
  /// an empty list: a payload of the wrong kind, an unknown argument, or a
  /// problem of its fragment.
  List<String> problemsWith(SocketContribution contribution) {
    final fragment = contribution.fragment;
    final kind = this.kind;
    return [
      if (contribution.socket != this)
        'The contribution is for the socket ${contribution.socket}, not $this.',
      ...switch (kind) {
        CodeSocket() || FactoryListSocket() => [
            if (fragment == null || fragment.isWrapper)
              '$this takes a Fragment of code.',
          ],
        WrapperSocket() => [
            if (fragment == null || !fragment.isWrapper)
              '$this takes a Fragment.wrap.',
          ],
        ArgsSocket(:final args) => [
            if (fragment == null || fragment.isWrapper)
              '$this takes a Fragment of code.',
            if (!args.containsKey(contribution.argName))
              _unknownArgument(contribution.argName, args.keys),
          ],
        KeyedSocket() => [
            if (contribution.entryKey == null ||
                !kind.accepts(contribution.entryValue))
              '$this takes keyed entries of the right type.',
          ],
        ValueSocket() => [
            if (contribution.entryKey != null ||
                !kind.accepts(contribution.entryValue))
              '$this takes a value of the right type.',
          ],
        PipelineSocket() => [
            '$this is filled by the pipeline and takes no contributions.',
          ],
      },
      if (fragment != null) ...fragment.problems(),
    ];
  }

  String _unknownArgument(String? name, Iterable<String> expected) =>
      '$this has no argument "$name"; expected one of ${expected.join(', ')}.';

  /// Renders [contributions] to this socket, already in their final order,
  /// and returns the text of each of the socket's [tags].
  ///
  /// Throws an [ArgumentError] for a contribution this socket does not take
  /// (see [problemsWith]) and a [MergeConflict] for values that cannot be
  /// merged.
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
    List<Fragment> fragments() => [for (final c in contributions) c.fragment!];
    final kind = this.kind;
    return switch (kind) {
      CodeSocket() => {tag: kind.render(fragments())},
      FactoryListSocket() => {tag: kind.render(fragments())},
      WrapperSocket() => {
          '${tag}_open': kind.renderOpening(fragments()),
          '${tag}_close': kind.renderClosing(fragments()),
        },
      ArgsSocket() => {
          tag: kind.render([
            for (final c in contributions) (c.argName!, c.fragment!),
          ]),
        },
      KeyedSocket() => {
          tag: kind.render([
            for (final c in contributions) (c.entryKey!, c.entryValue!),
          ]),
        },
      ValueSocket() => {
          tag: kind
              .render([for (final c in contributions) c.entryValue!], key: tag),
        },
      PipelineSocket() => throw StateError(
          'The pipeline renders $this from the merged pubspec itself.',
        ),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is SocketRef &&
      identical(other.role, role) &&
      other.module == module &&
      other.name == name &&
      _sameSegments(other.familyKey, familyKey);

  @override
  int get hashCode => Object.hash(
        identityHashCode(role),
        module,
        name,
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
/// A member is a [SocketRef] whose tag ends with the key's segments; calling
/// the family with a key returns it.
@immutable
final class SocketFamily<Key, K extends SocketKind> {
  /// Creates the family [name] of [role]; [keyOf] turns a key into the lower
  /// snake_case segments of a member's tag.
  const SocketFamily.role(
    Role this.role,
    this.name,
    this.kind, {
    required this.keyOf,
  }) : module = null;

  /// Creates the family [name] of the module [module]; [keyOf] turns a key
  /// into the lower snake_case segments of a member's tag.
  const SocketFamily.module(
    ModuleId this.module,
    this.name,
    this.kind, {
    required this.keyOf,
  }) : role = null;

  /// The role that owns the family, if a role does.
  final Role? role;

  /// The module that owns the family, if a module does.
  final ModuleId? module;

  /// The name of the family, in lower snake_case.
  final String name;

  /// What every member of the family accepts.
  final K kind;

  /// Turns a key into the segments of a member's tag.
  final List<String> Function(Key key) keyOf;

  /// Returns the member of the family for [key].
  ///
  /// Throws an [ArgumentError] if [keyOf] returns no segments or a segment
  /// that is not lower snake_case.
  SocketRef<K> call(Key key) {
    final segments = keyOf(key);
    if (segments.isEmpty || !segments.every(SmfNames.isSnakeCase)) {
      throw ArgumentError.value(
        segments,
        'key',
        'The key of a member of $name must be non-empty lower snake_case '
            'segments',
      );
    }
    return SocketRef<K>._family(
      role: role,
      module: module,
      name: name,
      kind: kind,
      familyKey: List.unmodifiable(segments),
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
