import 'package:smf_contracts/smf_contracts.dart';

/// A tag found in a mustache template.
class MustacheTag {
  const MustacheTag(this.kind, this.name);

  /// The tag sigil: '' (variable), '{' or '&' (unescaped variable), '#', '^',
  /// '/', '!', '>', '=' (set delimiters) or '?' (unclosed tag).
  final String kind;

  final String name;

  bool get opensSection => kind == '#' || kind == '^';

  bool get closesSection => kind == '/';

  bool get isVariable => kind == '' || kind == '{' || kind == '&';

  @override
  String toString() => kind == '{' ? '{{{$name}}}' : '{{$kind$name}}';
}

/// Lambdas mason adds to every render, as in `{{app_name.snakeCase()}}`.
const masonLambdas = {
  'camelCase',
  'constantCase',
  'dotCase',
  'headerCase',
  'lowerCase',
  'mustacheCase',
  'pascalCase',
  'pascalDotCase',
  'paramCase',
  'pathCase',
  'sentenceCase',
  'snakeCase',
  'titleCase',
  'upperCase',
};

const _masonBuiltInVars = {'__LEFT_CURLY_BRACKET__', '__RIGHT_CURLY_BRACKET__'};

const _sigils = {'#', '^', '/', '&', '!', '>'};

/// Scans [template] the way mustache tokenizes it, honouring set-delimiter
/// tags: text inside a `{{=<% %>=}}` region is not reported as tags.
List<MustacheTag> scanMustacheTags(String template) {
  final tags = <MustacheTag>[];
  var open = '{{';
  var close = '}}';
  var index = 0;

  while (true) {
    final start = template.indexOf(open, index);
    if (start == -1) break;

    final isTriple = open == '{{' && template.startsWith('{{{', start);
    final bodyStart = start + open.length + (isTriple ? 1 : 0);
    final closer = isTriple ? '}}}' : close;
    final end = template.indexOf(closer, bodyStart);
    if (end == -1) {
      tags.add(MustacheTag('?', template.substring(start).trim()));
      break;
    }

    final body = template.substring(bodyStart, end).trim();
    index = end + closer.length;

    if (isTriple) {
      tags.add(MustacheTag('{', body));
    } else if (body.length > 1 && body.startsWith('=') && body.endsWith('=')) {
      tags.add(MustacheTag('=', body));
      final delimiters =
          body.substring(1, body.length - 1).trim().split(RegExp(r'\s+'));
      if (delimiters.length == 2) {
        open = delimiters.first;
        close = delimiters.last;
      }
    } else if (body.isNotEmpty && _sigils.contains(body[0])) {
      tags.add(MustacheTag(body[0], body.substring(1).trim()));
    } else {
      tags.add(MustacheTag('', body));
    }
  }

  return tags;
}

/// Root names of the variables a mason template reads, e.g. `app_name` for
/// `{{app_name.snakeCase()}}`.
///
/// Names inside a section that iterates a value are skipped, since they may
/// refer to the iterated item rather than to a top-level variable.
Set<String> referencedVariables(String template) {
  final names = <String>{};
  final sections = <String>[];

  for (final tag in scanMustacheTags(template)) {
    if (tag.closesSection) {
      if (sections.isNotEmpty) sections.removeLast();
      continue;
    }
    if (!tag.opensSection && !tag.isVariable) continue;

    final root = tag.name == '.' ? '.' : tag.name.split('.').first;
    final inItemScope = sections.any((s) => !masonLambdas.contains(s));
    final isBuiltIn = root == '.' ||
        masonLambdas.contains(root) ||
        _masonBuiltInVars.contains(root);
    if (!inItemScope && !isBuiltIn) names.add(root);

    if (tag.opensSection) sections.add(root);
  }

  return names;
}

/// Tags left in rendered brick output that are not deliberate DSL slots.
///
/// Bricks escape DSL slots with set-delimiter tags so that mason leaves
/// `{{#slot}}{{{.}}}{{/slot}}` in place for the DSL generators. Any other tag
/// in the output is one mason failed to render.
List<String> unexpectedLeftoverTags(String rendered) {
  final slots = MustacheSlots.values.map((s) => s.slot).toSet();
  final problems = <String>[];
  final openSlots = <String>[];

  for (final tag in scanMustacheTags(rendered)) {
    if (tag.opensSection || tag.closesSection) {
      if (!slots.contains(tag.name)) problems.add('$tag');
      if (tag.opensSection) {
        openSlots.add(tag.name);
      } else if (openSlots.isNotEmpty) {
        openSlots.removeLast();
      }
    } else if (!(tag.isVariable && tag.name == '.' && openSlots.isNotEmpty)) {
      problems.add('$tag');
    }
  }

  if (openSlots.isNotEmpty) problems.add('unclosed sections $openSlots');
  return problems;
}
