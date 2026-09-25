import 'dart:convert';

import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// The tag of a socket in a template file, as the scan found it.
final class TemplateTag {
  /// Creates the tag [name] found at [offset] of the file at [path].
  const TemplateTag({
    required this.name,
    required this.path,
    required this.offset,
    required this.line,
    required this.triple,
    this.sections = const [],
    this.afterBrace = false,
  });

  /// The name of the tag, such as `smf_app_entry__bootstrap_platform`.
  final String name;

  /// The path of the template file in its brick.
  final String path;

  /// The offset of the tag's opening braces in the file.
  final int offset;

  /// The line of the tag, from 1.
  final int line;

  /// Whether the tag has three braces, which mustache does not escape.
  final bool triple;

  /// The names of the mustache sections the tag is in, outermost first.
  final List<String> sections;

  /// Whether a `{` comes right before the tag, which mustache reads as part
  /// of the tag's braces.
  final bool afterBrace;

  @override
  String toString() => '$name ($path:$line)';
}

/// The text files of [brick], by path, decoded from its bundle.
Map<String, String> templateFilesOf(BrickContribution brick) => {
      for (final file in brick.bundle.files)
        if (file.type == 'text')
          file.path:
              utf8.decode(base64.decode(file.data), allowMalformed: true),
    };

final RegExp _tagName = RegExp(r'^smf_[a-z0-9_]+$');

/// Finds the tags of sockets, the mustache tags whose names start with
/// `smf_`, in [text], the template file at [path].
///
/// It follows mustache: `{{{name}}}` and `{{name}}` are variables, `{{#name}}`
/// and `{{^name}}` open sections that `{{/name}}` closes, and `{{!` starts a
/// comment. Four opening braces are a `{` followed by a tag.
List<TemplateTag> scanTemplate(String path, String text) {
  final tags = <TemplateTag>[];
  final sections = <String>[];
  var index = 0;
  while (true) {
    var start = text.indexOf('{{', index);
    if (start < 0) break;
    var afterBrace = false;
    while (text.startsWith('{{{{', start)) {
      start++;
      afterBrace = true;
    }
    final triple = text.startsWith('{{{', start);
    final closing = triple ? '}}}' : '}}';
    final contentStart = start + (triple ? 3 : 2);
    final end = text.indexOf(closing, contentStart);
    if (end < 0) break;
    index = end + closing.length;
    final content = text.substring(contentStart, end).trim();
    if (!triple && content.isNotEmpty) {
      final marker = content[0];
      final name = content.substring(1).trim();
      if (marker == '#' || marker == '^') {
        sections.add(name);
        continue;
      }
      if (marker == '/') {
        final open = sections.lastIndexOf(name);
        if (open >= 0) sections.removeRange(open, sections.length);
        continue;
      }
      if (marker == '!' || marker == '>' || marker == '=') continue;
    }
    if (!_tagName.hasMatch(content)) continue;
    tags.add(
      TemplateTag(
        name: content,
        path: path,
        offset: start,
        line: '\n'.allMatches(text.substring(0, start)).length + 1,
        triple: triple,
        sections: List.unmodifiable(sections),
        afterBrace: afterBrace,
      ),
    );
  }
  return tags;
}

/// A socket whose tag a template holds, and who may hold it.
final class _KnownSocket {
  const _KnownSocket(this.socket, {this.family});

  final SocketRef socket;

  /// The family the socket is a member of, if it is one.
  final SocketFamily<Object?, SocketKind>? family;
}

/// Checks the tags of the sockets in the bricks among [collection]'s
/// contributions that apply, both ways:
/// - every tag is `{{{smf_…}}}`, outside mustache sections, not right
///   after a `{`, and names a socket that its brick's owner may hold: the
///   template or a provider of the socket's role, a module whose roles
///   include the role of a family member, the module that owns a socket of
///   a module, or anyone for a socket of the pipeline;
/// - a socket whose contributions carry imports, or a socket of the
///   pipeline, has its tag in exactly one file; both tags of a wrapper are
///   in the same file, the opening one first;
/// - every socket of a present role has its tag in the bricks of the role's
///   template or providers, and every socket of a module in the bricks of
///   that module.
List<SmfIssue> checkTemplateTags({
  required ModuleRegistry registry,
  required Resolution resolution,
  required Collection collection,
}) {
  final issues = <SmfIssue>[];
  final byTag = <String, _KnownSocket>{};
  final families = <SocketFamily<Object?, SocketKind>>[];
  void know(SocketRef socket) {
    for (final tag in socket.tags) {
      byTag[tag] = _KnownSocket(socket);
    }
  }

  PipelineSockets.all.forEach(know);
  for (final role in registry.roles) {
    role.sockets.forEach(know);
    families.addAll(role.socketFamilies);
  }
  for (final module in registry.modules) {
    module.descriptor.sockets.forEach(know);
    families.addAll(module.descriptor.socketFamilies);
  }

  _KnownSocket? socketOf(String tag) {
    final known = byTag[tag];
    if (known != null) return known;
    for (final family in families) {
      final member = family.memberOfTag(tag);
      if (member != null) return _KnownSocket(member, family: family);
    }
    return null;
  }

  // Where each socket's tags are, by socket, then by tag name.
  final found =
      <SocketRef, Map<String, List<(TemplateTag, ContributionOrigin)>>>{};

  for (final collected in collection.applyingOf<BrickContribution>()) {
    final origin = collected.origin;
    final brick = collected.contribution as BrickContribution;
    for (final MapEntry(key: path, value: text)
        in templateFilesOf(brick).entries) {
      for (final tag in scanTemplate(path, text)) {
        final problems = <String>[];
        if (!tag.triple) {
          problems.add(
            'must have three braces, {{{${tag.name}}}}, or mustache escapes '
            'its code',
          );
        }
        if (tag.sections.isNotEmpty) {
          problems.add(
            'is inside the mustache section ${tag.sections.last}; put the '
            'section around the contributions instead',
          );
        }
        if (tag.afterBrace) {
          problems.add(
            'comes right after a {, which mustache reads as part of the '
            'tag; start a new line',
          );
        }
        final known = socketOf(tag.name);
        if (known == null) {
          problems.add('names no socket');
        } else if (!_mayHold(origin, known, resolution)) {
          problems.add(
            'is a tag of the ${known.socket}, which $origin may not hold',
          );
        } else {
          found
              .putIfAbsent(known.socket, () => {})
              .putIfAbsent(tag.name, () => [])
              .add((tag, origin));
        }
        for (final problem in problems) {
          issues.add(
            SmfIssue(
              'The tag ${tag.name} in ${tag.path}:${tag.line} of $origin '
              '$problem.',
              origin: origin,
              path: tag.path,
            ),
          );
        }
      }
    }
  }

  for (final MapEntry(key: socket, value: tags) in found.entries) {
    final once = socket.kind.carriesImports || socket.isPipeline;
    for (final MapEntry(key: name, value: places) in tags.entries) {
      if (once && places.length > 1) {
        issues.add(
          SmfIssue(
            'The tag $name of the $socket appears '
            '${places.length} times (${places.map((p) => p.$1).join(', ')}); '
            'its contributions carry imports into one file, so it must '
            'appear once.',
            origin: places.last.$2,
            path: places.last.$1.path,
          ),
        );
      }
    }
    if (socket.kind is WrapperSocket) {
      final [open, close] = socket.tags;
      final opening = tags[open];
      final closing = tags[close];
      if (opening == null || closing == null) {
        final (tag, origin) = (opening ?? closing)!.first;
        issues.add(
          SmfIssue(
            'The $socket has only its tag ${tag.name} in ${tag.path}; a '
            'wrapper needs both $open and $close.',
            origin: origin,
            path: tag.path,
          ),
        );
      } else if (opening.first.$1.path != closing.first.$1.path) {
        issues.add(
          SmfIssue(
            'The tags of the $socket are in different files: '
            '${opening.first.$1.path} and ${closing.first.$1.path}.',
            origin: opening.first.$2,
          ),
        );
      } else if (opening.first.$1.offset > closing.first.$1.offset) {
        issues.add(
          SmfIssue(
            'The tag $close of the $socket comes before $open in '
            '${opening.first.$1.path}.',
            origin: opening.first.$2,
            path: opening.first.$1.path,
          ),
        );
      }
    }
  }

  for (final role in resolution.presentRoles) {
    for (final socket in role.sockets) {
      if (found.containsKey(socket)) continue;
      issues.add(
        SmfIssue(
          'No template of the ${role.id} or of its providers has the tag of '
          'the $socket (${socket.tags.join(', ')}).',
          origin: role.template == null
              ? resolution.providersOf(role).firstOrNull?.origin
              : RoleTemplateOrigin(role),
        ),
      );
    }
  }
  for (final module in resolution.modules) {
    for (final socket in module.descriptor.sockets) {
      if (found.containsKey(socket)) continue;
      issues.add(
        SmfIssue(
          'The bricks of ${module.id} lack the tag of its $socket '
          '(${socket.tags.join(', ')}).',
          origin: module.origin,
        ),
      );
    }
  }
  return issues;
}

/// Whether the owner of a brick, [origin], may hold the tag of [known].
bool _mayHold(
  ContributionOrigin origin,
  _KnownSocket known,
  Resolution resolution,
) {
  final socket = known.socket;
  if (socket.isPipeline) return true;
  final role = socket.role;
  final module = switch (origin) {
    ModuleOrigin(:final module) => resolution.module(module),
    _ => null,
  };
  if (role != null) {
    if (origin case RoleTemplateOrigin(role: final owner)) {
      return identical(owner, role) ||
          (known.family != null && owner.visibleRoles.contains(role));
    }
    if (module == null) return false;
    final descriptor = module.descriptor;
    return descriptor.provides.contains(role) ||
        (known.family != null && descriptor.roles.contains(role));
  }
  return module != null && module.id == socket.module;
}
