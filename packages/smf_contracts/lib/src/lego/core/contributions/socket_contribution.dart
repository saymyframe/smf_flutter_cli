part of '../contributions.dart';

/// Code or a value for a socket.
///
/// Each constructor takes a socket of one kind, so a contribution cannot
/// target a socket that does not take it:
/// - [SocketContribution.code] for a [CodeSocket];
/// - [SocketContribution.arg] for an [ArgsSocket];
/// - [SocketContribution.wrap] for a [WrapperSocket];
/// - [SocketContribution.item] for a [FactoryListSocket];
/// - [SocketContribution.entry] and [SocketContribution.key] for a
///   [KeyedSocket];
/// - [SocketContribution.value] for a [ValueSocket].
///
/// See [SocketRef] for who may contribute to which sockets, and how the
/// pipeline orders the contributions of a socket.
final class SocketContribution extends Contribution {
  /// Adds [fragment] to a [CodeSocket].
  const SocketContribution.code(
    SocketRef<CodeSocket> this.socket,
    Fragment this.fragment, {
    super.when,
  })  : argName = null,
        entryKey = null,
        entryValue = null;

  /// Sets the argument [argName] of an [ArgsSocket] to the expression
  /// [fragment], or adds it to a list argument.
  const SocketContribution.arg(
    SocketRef<ArgsSocket> this.socket,
    String this.argName,
    Fragment this.fragment, {
    super.when,
  })  : entryKey = null,
        entryValue = null;

  /// Adds the wrapper [fragment], created with [Fragment.wrap], to a
  /// [WrapperSocket].
  const SocketContribution.wrap(
    SocketRef<WrapperSocket> this.socket,
    Fragment this.fragment, {
    super.when,
  })  : argName = null,
        entryKey = null,
        entryValue = null;

  /// Adds the factory expression [fragment] to a [FactoryListSocket].
  const SocketContribution.item(
    SocketRef<FactoryListSocket> this.socket,
    Fragment this.fragment, {
    super.when,
  })  : argName = null,
        entryKey = null,
        entryValue = null;

  const SocketContribution._value(
    this.socket, {
    required this.entryValue,
    this.entryKey,
    super.when,
  })  : fragment = null,
        argName = null;

  /// Adds the entry [key] with [value] to a [KeyedSocket].
  static SocketContribution entry<V extends Object>(
    SocketRef<KeyedSocket<V>> socket,
    String key,
    V value, {
    Set<Role> when = const {},
  }) =>
      SocketContribution._value(
        socket,
        entryKey: key,
        entryValue: value,
        when: when,
      );

  /// Adds [key] to a [KeyedSocket] whose entries are only keys.
  static SocketContribution key(
    SocketRef<KeyedSocket<NoValue>> socket,
    String key, {
    Set<Role> when = const {},
  }) =>
      entry(socket, key, const NoValue(), when: when);

  /// Contributes [value] to a [ValueSocket].
  static SocketContribution value<V extends Object>(
    SocketRef<ValueSocket<V>> socket,
    V value, {
    Set<Role> when = const {},
  }) =>
      SocketContribution._value(socket, entryValue: value, when: when);

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
}
