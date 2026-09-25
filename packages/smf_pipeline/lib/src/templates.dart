import 'dart:convert';

import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/access.dart';
import 'package:smf_pipeline/src/collector.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/resolver.dart';

/// A mustache variable in a template file, as the scan found it: the tag of
/// a socket, whose name starts with `smf`, or another variable, such as a
/// variable of a role's render hook.
final class TemplateTag {
  /// Creates the variable [name] found at [offset] of the file at [path].
  const TemplateTag({
    required this.name,
    required this.path,
    required this.offset,
    required this.line,
    required this.triple,
    this.column = 0,
    this.sections = const [],
    this.afterBrace = false,
  });

  /// The name of the variable, such as `smf_app_entry__bootstrap_platform`.
  final String name;

  /// The path of the template file in its brick.
  final String path;

  /// The offset of the variable's opening braces in the file.
  final int offset;

  /// The line of the variable, from 1.
  final int line;

  /// The column of the variable's opening braces in its line, from 0.
  final int column;

  /// Whether the variable has three braces, which mustache does not escape.
  /// `{{& name}}`, which mustache does not escape either, counts as two.
  final bool triple;

  /// The names of the mustache sections the variable is in, outermost
  /// first.
  final List<String> sections;

  /// Whether a `{` comes right before the variable, which mustache reads as
  /// part of the variable's braces.
  final bool afterBrace;

  /// Whether the name is meant as the tag of a socket: it starts with
  /// `smf`.
  bool get isSocketTag => name.startsWith('smf');

  @override
  String toString() => '$name ($path:$line)';
}

/// A mustache section in a template file, `{{#name}}` or `{{^name}}`, as
/// the scan found it.
final class TemplateSection {
  /// Creates the section [name] that opens at [line] of the file at [path].
  const TemplateSection({
    required this.name,
    required this.path,
    required this.line,
    this.inverted = false,
  });

  /// The name of the section, such as `has_router`.
  final String name;

  /// The path of the template file in its brick.
  final String path;

  /// The line where the section opens, from 1.
  final int line;

  /// Whether it is an inverted section, `{{^name}}`.
  final bool inverted;

  @override
  String toString() => '${inverted ? '^' : '#'}$name ($path:$line)';
}

/// What [scanTemplate] found in a template file.
final class TemplateScan {
  /// Creates the result of a scan.
  const TemplateScan(
    this.tags, {
    this.sections = const [],
    this.partialLines = const [],
    this.delimiterLine,
  });

  /// The variables, in the order of the file.
  final List<TemplateTag> tags;

  /// The sections, in the order they open.
  final List<TemplateSection> sections;

  /// The lines of the partials the file includes, `{{> name}}`.
  final List<int> partialLines;

  /// The line of a `{{=… …=}}` tag that changes the delimiters, after which
  /// the scan stops, or `null` if the file has none.
  final int? delimiterLine;
}

/// The text files of [brick], by path with forward slashes, decoded from
/// its bundle.
Map<String, String> templateFilesOf(BrickContribution brick) => {
      for (final file in brick.bundle.files)
        if (file.type == 'text')
          file.path.replaceAll(r'\', '/'):
              utf8.decode(base64.decode(file.data), allowMalformed: true),
    };

final RegExp _tagName = RegExp(r'^smf_[a-z0-9_]+$');

/// Finds the variables and sections in [text], the template file at
/// [path].
///
/// It follows mustache: `{{{name}}}`, `{{name}}` and `{{& name}}` are
/// variables, `{{#name}}` and `{{^name}}` open sections that `{{/name}}`
/// closes, `{{!` starts a comment and `{{>` includes a partial. Four opening
/// braces are a `{` followed by a variable. A delimiter change, `{{=… …=}}`,
/// ends the scan, since the pipeline does not support it.
TemplateScan scanTemplate(String path, String text) {
  final tags = <TemplateTag>[];
  final opened = <TemplateSection>[];
  final partialLines = <int>[];
  final sections = <String>[];
  var index = 0;
  int lineOf(int offset) => '\n'.allMatches(text.substring(0, offset)).length;
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
    var content = text.substring(contentStart, end).trim();
    if (!triple && content.isNotEmpty) {
      final marker = content[0];
      final name = content.substring(1).trim();
      switch (marker) {
        case '#' || '^':
          sections.add(name);
          opened.add(
            TemplateSection(
              name: name,
              path: path,
              line: lineOf(start) + 1,
              inverted: marker == '^',
            ),
          );
          continue;
        case '/':
          final open = sections.lastIndexOf(name);
          if (open >= 0) sections.removeRange(open, sections.length);
          continue;
        case '!':
          continue;
        case '>':
          partialLines.add(lineOf(start) + 1);
          continue;
        case '=':
          return TemplateScan(
            tags,
            sections: opened,
            partialLines: partialLines,
            delimiterLine: lineOf(start) + 1,
          );
        case '&':
          content = name;
      }
    }
    if (content.isEmpty) continue;
    final lineStart = text.lastIndexOf('\n', start) + 1;
    tags.add(
      TemplateTag(
        name: content,
        path: path,
        offset: start,
        line: lineOf(start) + 1,
        column: start - lineStart,
        triple: triple,
        sections: List.unmodifiable(sections),
        afterBrace: afterBrace,
      ),
    );
  }
  return TemplateScan(tags, sections: opened, partialLines: partialLines);
}

/// A socket whose tag a template holds, and the family it is a member of.
final class _KnownSocket {
  const _KnownSocket(this.socket, {this.family});

  final SocketRef socket;

  /// The family the socket is a member of, if it is one.
  final SocketFamily<Object?, SocketKind>? family;
}

/// A place of the tag of a socket: the tag in a template file and the owner
/// of the file's brick.
typedef TagPlace = (TemplateTag, ContributionOrigin);

/// The tags of sockets that the bricks of an app hold, and the problems
/// with them and with the bricks' templates; see [scanBricks].
final class BrickTags {
  /// Creates the result of a scan.
  const BrickTags(this.found, this.issues);

  /// The places of the tags of every socket that has any, by socket and then
  /// by tag name.
  final Map<SocketRef, Map<String, List<TagPlace>>> found;

  /// The problems found; see [checkTemplateTags].
  final List<SmfIssue> issues;

  /// The first place of a tag of [socket], or `null` if no template holds
  /// one.
  ///
  /// A socket whose contributions carry imports has its tags in one file,
  /// which this gives.
  TagPlace? placeOf(SocketRef socket) =>
      found[socket]?.values.firstOrNull?.firstOrNull;
}

/// Mustache that a path of a brick file may not have: a section, a
/// partial, an include or a delimiter change. Variables are fine.
final RegExp _pathSyntax = RegExp(r'\{\{\s*[#^/~%>=!]');

/// Scans the templates of the bricks among [collection]'s contributions
/// that apply for the tags of sockets, and checks them and the templates;
/// see [checkTemplateTags].
///
/// Stage 8 finds with it the files that get the imports of each socket.
BrickTags scanBricks({
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
  final rolesById = {for (final role in registry.roles) role.id: role};

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
  final found = <SocketRef, Map<String, List<TagPlace>>>{};

  for (final collected in collection.applyingOf<BrickContribution>()) {
    final origin = collected.origin;
    final brick = collected.contribution as BrickContribution;
    final name = brick.bundle.name;
    for (final file in brick.bundle.files) {
      final path = file.path.replaceAll(r'\', '/');
      if (_pathSyntax.hasMatch(path)) {
        issues.add(
          SmfIssue(
            'The path $path in the brick $name of $origin has a mustache '
            'section, partial or include; a path may only use variables.',
            hint: 'Put the files that only some apps have into a brick of '
                'their own, contributed with when.',
            origin: origin,
            path: path,
          ),
        );
      }
    }

    // The presence flags the pipeline sets for the brick.
    final flagged = rolesOf(origin, registry, resolution).access;
    String? flagProblem(String flag) {
      if (!flag.startsWith('has_')) return null;
      final role = rolesById[flag.substring('has_'.length)];
      if (role == null) return 'names no role';
      if (flagged.contains(role)) return null;
      return 'is the flag of the ${role.id}, which $origin does not '
          'provide, require or use, so the pipeline does not set it';
    }

    for (final MapEntry(key: path, value: text)
        in templateFilesOf(brick).entries) {
      final scan = scanTemplate(path, text);
      if (scan.delimiterLine case final line?) {
        issues.add(
          SmfIssue(
            'The template $path:$line of $origin changes the mustache '
            'delimiters, which the pipeline does not support.',
            origin: origin,
            path: path,
          ),
        );
      }
      for (final line in scan.partialLines) {
        issues.add(
          SmfIssue(
            'The template $path:$line of $origin includes a partial, which '
            'the pipeline does not support.',
            origin: origin,
            path: path,
          ),
        );
      }
      for (final section in scan.sections) {
        if (flagProblem(section.name) case final problem?) {
          issues.add(
            SmfIssue(
              'The section ${section.name} in $path:${section.line} of '
              '$origin $problem.',
              hint: 'Add the role to the uses of the module.',
              origin: origin,
              path: path,
            ),
          );
        }
      }
      for (final tag in scan.tags) {
        final problems = <String>[
          if (flagProblem(tag.name) case final problem?) problem,
        ];
        if (tag.afterBrace) {
          problems.add(
            'comes right after a {, which mustache reads as part of the '
            'tag; start a new line',
          );
        }
        if (tag.isSocketTag) {
          problems.addAll(_socketTagProblems(tag));
          final known = socketOf(tag.name);
          if (known == null) {
            if (_tagName.hasMatch(tag.name)) problems.add('names no socket');
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
    issues.addAll(_placeIssues(socket, tags));
  }
  return BrickTags(found, issues);
}

/// Checks the tags of the sockets in the bricks among [collection]'s
/// contributions that apply:
/// - every tag is `{{{smf_…}}}` with a valid name, outside mustache
///   sections, and names a socket that its brick's owner may hold: the
///   template or a provider of the socket's role, a module whose roles
///   include the role of a family member, the module that owns a socket of
///   a module, or anyone for a socket of the pipeline;
/// - no variable, a tag or not, comes right after a `{`, no template
///   changes the mustache delimiters or includes a partial, and the path of
///   every file uses no mustache but variables;
/// - a presence flag, `has_<role>`, is of a role that the brick's owner
///   provides, requires or uses, or of a role open to all modules: the
///   pipeline sets no other;
/// - only the tag of a socket for one value, such as a minimum version, may
///   appear several times; a socket whose contributions carry imports has
///   its tag in a Dart file, and a socket of the pipeline at the start of a
///   line of `pubspec.yaml`; both tags of a wrapper are in the same file,
///   the opening one first.
///
/// Stage 5 runs it; the contract harness adds [missingTemplateTags].
List<SmfIssue> checkTemplateTags({
  required ModuleRegistry registry,
  required Resolution resolution,
  required Collection collection,
}) =>
    scanBricks(
      registry: registry,
      resolution: resolution,
      collection: collection,
    ).issues;

/// Checks that the bricks among [collection]'s contributions that apply hold
/// every tag they must: of every socket of a present role, in the bricks of
/// the role's template or providers; of every socket of a module, in its
/// bricks; of every socket of the pipeline; and of every member of a socket
/// family that something contributes to.
///
/// The contract harness runs it; the pipeline leaves it to the contract
/// tests of the modules.
List<SmfIssue> missingTemplateTags({
  required ModuleRegistry registry,
  required Resolution resolution,
  required Collection collection,
}) =>
    _missingTagIssues(
      resolution,
      collection,
      scanBricks(
        registry: registry,
        resolution: resolution,
        collection: collection,
      ).found,
    ).toList();

/// The problems with the form of [tag], the tag of a socket.
Iterable<String> _socketTagProblems(TemplateTag tag) sync* {
  if (!_tagName.hasMatch(tag.name)) {
    yield 'is not a tag of a socket, which is smf_ followed by lowercase '
        'letters, digits and underscores';
  }
  if (!tag.triple) {
    yield 'must have three braces, {{{${tag.name}}}}, or mustache escapes '
        'its code';
  }
  if (tag.sections.isNotEmpty) {
    yield 'is inside the mustache section ${tag.sections.last}; put the '
        'section around the contributions instead';
  }
}

/// The problems with where the tags of [socket] are: [tags], by tag name,
/// with who holds each.
Iterable<SmfIssue> _placeIssues(
  SocketRef socket,
  Map<String, List<(TemplateTag, ContributionOrigin)>> tags,
) sync* {
  for (final MapEntry(key: name, value: places) in tags.entries) {
    final (last, lastOrigin) = places.last;
    if (places.length > 1 && socket.kind is! ValueSocket) {
      yield SmfIssue(
        'The tag $name of the $socket appears ${places.length} times '
        '(${places.map((p) => p.$1).join(', ')}); only the tag of a '
        'socket for one value may appear more than once.',
        origin: lastOrigin,
        path: last.path,
      );
    }
    for (final (tag, origin) in places) {
      if (socket.isPipeline &&
          (tag.path.split('/').last != 'pubspec.yaml' || tag.column != 0)) {
        yield SmfIssue(
          'The tag $name in ${tag.path}:${tag.line} of $origin must be at '
          'the start of a line of pubspec.yaml.',
          origin: origin,
          path: tag.path,
        );
      } else if (socket.kind.carriesImports &&
          !socket.isPipeline &&
          !tag.path.endsWith('.dart')) {
        yield SmfIssue(
          'The tag $name in ${tag.path}:${tag.line} of $origin is in a file '
          'that is not Dart, but the contributions to the $socket carry '
          'imports.',
          origin: origin,
          path: tag.path,
        );
      }
    }
  }
  if (socket.kind is! WrapperSocket) return;
  final [open, close] = socket.tags;
  final opening = tags[open];
  final closing = tags[close];
  if (opening == null || closing == null) {
    final (tag, origin) = (opening ?? closing)!.first;
    yield SmfIssue(
      'The $socket has only its tag ${tag.name} in ${tag.path}; a wrapper '
      'needs both $open and $close.',
      origin: origin,
      path: tag.path,
    );
  } else if (opening.first.$1.path != closing.first.$1.path) {
    yield SmfIssue(
      'The tags of the $socket are in different files: '
      '${opening.first.$1.path} and ${closing.first.$1.path}.',
      origin: opening.first.$2,
    );
  } else if (opening.first.$1.offset > closing.first.$1.offset) {
    yield SmfIssue(
      'The tag $close of the $socket comes before $open in '
      '${opening.first.$1.path}.',
      origin: opening.first.$2,
      path: opening.first.$1.path,
    );
  }
}

/// The problems of sockets whose tags the bricks lack; see
/// [missingTemplateTags].
Iterable<SmfIssue> _missingTagIssues(
  Resolution resolution,
  Collection collection,
  Map<SocketRef, Object> found,
) sync* {
  for (final role in resolution.presentRoles) {
    for (final socket in role.sockets) {
      if (found.containsKey(socket)) continue;
      yield SmfIssue(
        'No template of the ${role.id} or of its providers has the tag of '
        'the $socket (${socket.tags.join(', ')}).',
        origin: role.template == null
            ? resolution.providersOf(role).firstOrNull?.origin
            : RoleTemplateOrigin(role),
      );
    }
  }
  for (final module in resolution.modules) {
    for (final socket in module.descriptor.sockets) {
      if (found.containsKey(socket)) continue;
      yield SmfIssue(
        'The bricks of ${module.id} lack the tag of its $socket '
        '(${socket.tags.join(', ')}).',
        origin: module.origin,
      );
    }
  }
  for (final socket in PipelineSockets.all) {
    if (found.containsKey(socket)) continue;
    yield SmfIssue(
      'No brick has the tag ${socket.tag} of the pipeline; the owner of '
      'pubspec.yaml puts it at the start of a line.',
    );
  }
  final reported = <SocketRef>{};
  for (final collected in collection.applyingOf<SocketContribution>()) {
    final socket = (collected.contribution as SocketContribution).socket;
    if (socket.familyKey.isEmpty ||
        found.containsKey(socket) ||
        !reported.add(socket)) {
      continue;
    }
    yield SmfIssue(
      '${collected.origin} contributes to the $socket, but no brick has its '
      'tag ${socket.tag}.',
      origin: collected.origin,
    );
  }
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
