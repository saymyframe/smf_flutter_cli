part of '../contributions.dart';

/// Code or a value for a socket.
///
/// Each way of creating one takes a socket of one kind, so a contribution
/// cannot target a socket that does not take it:
/// - [SocketContribution.code] for a [CodeSocket];
/// - [SocketContribution.arg] for an [ArgsSocket];
/// - [SocketContribution.wrap] for a [WrapperSocket];
/// - [SocketContribution.item] for a [FactoryListSocket];
/// - `socket.entry(key, value)` and `socket.key(key)` for a [KeyedSocket]
///   (see [KeyedSocketContributions]);
/// - `socket.value(value)` for a [ValueSocket] (see
///   [ValueSocketContributions]).
///
/// See [SocketRef] for who may contribute to which sockets.
///
/// ## Order
///
/// The pipeline renders the contributions of a socket, and runs every
/// [PostGenStep], in an order given by edges between all modules of the app
/// and the templates of its roles:
/// 1. A module comes after the modules it depends on.
/// 2. If a module requires a role, or has it in [Contribution.when], it
///    comes after the role's providers and the role's template.
/// 3. A role's template comes after the role's providers, and after the
///    providers and templates of the roles its role requires or has in its
///    [Contribution.when].
///
/// Two contributors with edges both ways ignore both edges, unless one
/// depends on the other, which then comes after it. A contributor
/// comes after every contributor it reaches through the edges, also through
/// modules that do not contribute to the socket: a module that requires a
/// role comes after the modules the role's provider depends on. Otherwise
/// contributors are ordered by id. A cycle of edges is an error. Phases,
/// such as the start-up phases of the app entry, are separate sockets.
final class SocketContribution extends Contribution {
  /// Adds [fragment] to a [CodeSocket].
  const SocketContribution.code(
    SocketRef<CodeSocket> this.socket,
    Fragment this.fragment, {
    super.when,
  })  : argName = null,
        entryKey = null,
        entryValue = null,
        origin = null;

  /// Sets the argument [argName] of an [ArgsSocket] to the expression
  /// [fragment], or adds it to a list argument.
  const SocketContribution.arg(
    SocketRef<ArgsSocket> this.socket,
    String this.argName,
    Fragment this.fragment, {
    super.when,
  })  : entryKey = null,
        entryValue = null,
        origin = null;

  /// Adds the wrapper [fragment], created with [Fragment.wrap], to a
  /// [WrapperSocket].
  const SocketContribution.wrap(
    SocketRef<WrapperSocket> this.socket,
    Fragment this.fragment, {
    super.when,
  })  : argName = null,
        entryKey = null,
        entryValue = null,
        origin = null;

  /// Adds the factory expression [fragment] to a [FactoryListSocket].
  const SocketContribution.item(
    SocketRef<FactoryListSocket> this.socket,
    Fragment this.fragment, {
    super.when,
  })  : argName = null,
        entryKey = null,
        entryValue = null,
        origin = null;

  const SocketContribution._({
    required this.socket,
    required this.fragment,
    required this.argName,
    required this.entryKey,
    required this.entryValue,
    required this.origin,
    required super.when,
  });

  /// The socket the contribution is for.
  final SocketRef socket;

  /// The code, for sockets that take fragments.
  final Fragment? fragment;

  /// The argument name, for an [ArgsSocket].
  final String? argName;

  /// The key, for a [KeyedSocket].
  final String? entryKey;

  /// The value, for a [KeyedSocket] or [ValueSocket].
  final Object? entryValue;

  /// Who contributed it.
  ///
  /// The pipeline sets it with [withOrigin] when it collects contributions,
  /// so that a [MergeConflict] names the contributors. It is `null` in a
  /// contribution a module has just created.
  final ContributionOrigin? origin;

  /// Returns a copy of this contribution contributed by [origin].
  SocketContribution withOrigin(ContributionOrigin origin) =>
      SocketContribution._(
        socket: socket,
        fragment: fragment,
        argName: argName,
        entryKey: entryKey,
        entryValue: entryValue,
        origin: origin,
        when: when,
      );
}

/// Contributions to a [KeyedSocket].
///
/// The value type comes from the socket, so a value of another type does not
/// compile.
extension KeyedSocketContributions<V extends Object>
    on SocketRef<KeyedSocket<V>> {
  /// Adds the entry [key] with [value] to this socket.
  SocketContribution entry(
    String key,
    V value, {
    Set<Role> when = const {},
  }) =>
      SocketContribution._(
        socket: this,
        fragment: null,
        argName: null,
        entryKey: key,
        entryValue: value,
        origin: null,
        when: when,
      );
}

/// Contributions to a [KeyedSocket] whose entries are only keys.
extension KeySocketContributions on SocketRef<KeyedSocket<NoValue>> {
  /// Adds [key] to this socket.
  SocketContribution key(String key, {Set<Role> when = const {}}) =>
      entry(key, const NoValue(), when: when);
}

/// Contributions to a [ValueSocket].
///
/// The value type comes from the socket, so a value of another type does not
/// compile.
extension ValueSocketContributions<V extends Object>
    on SocketRef<ValueSocket<V>> {
  /// Contributes [value] to this socket.
  SocketContribution value(V value, {Set<Role> when = const {}}) =>
      SocketContribution._(
        socket: this,
        fragment: null,
        argName: null,
        entryKey: null,
        entryValue: value,
        origin: null,
        when: when,
      );
}
