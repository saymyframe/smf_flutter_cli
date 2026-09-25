import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/templates.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('scanTemplate', () {
    test('finds the variables with their line, column and sections', () {
      const text = '''
import 'a.dart';
{{{smf_app_entry__top_level}}}
{{#has_router}}
  {{{smf_router__observers}}}
  {{^has_layout}}{{smf_layout__x}}{{/has_layout}}
{{/has_router}}
{{app_name}} {{{facade}}} {{! {{{smf_in_comment}}} }} {{> partial}}
void f() {{{{smf_after__brace}}}
{{& smf_unescaped}}
''';

      final scan = scanTemplate('lib/main.dart', text);
      final tags = scan.tags;

      expect(
        [
          for (final tag in tags)
            [
              tag.name,
              tag.line,
              tag.column,
              tag.triple,
              tag.sections,
              tag.afterBrace,
              tag.isSocketTag,
            ].join(':'),
        ],
        [
          'smf_app_entry__top_level:2:0:true:[]:false:true',
          'smf_router__observers:4:2:true:[has_router]:false:true',
          'smf_layout__x:5:17:false:[has_router, has_layout]:false:true',
          'app_name:7:0:false:[]:false:false',
          'facade:7:13:true:[]:false:false',
          'smf_after__brace:8:10:true:[]:true:true',
          'smf_unescaped:9:0:false:[]:false:true',
        ],
      );
      expect(scan.delimiterLine, isNull);
      expect(scan.sections.map((section) => '$section'), [
        '#has_router (lib/main.dart:3)',
        '^has_layout (lib/main.dart:5)',
      ]);
      expect(scan.sections.last.inverted, isTrue);
      expect(scan.partialLines, [7]);
      expect(tags.first.path, 'lib/main.dart');
      expect(tags.first.offset, text.indexOf('{{{smf_app'));
      expect('${tags.first}', 'smf_app_entry__top_level (lib/main.dart:2)');
    });

    test('stops at unclosed tags and at a change of delimiters', () {
      expect(scanTemplate('a', '{{{smf_a}}} {{{smf_b').tags, hasLength(1));
      expect(scanTemplate('a', '').tags, isEmpty);
      expect(scanTemplate('a', '{{}}').tags, isEmpty);

      final changed = scanTemplate(
        'a',
        '{{{smf_a}}}\n{{=<% %>=}}\n<%{smf_b}%>{{{smf_c}}}',
      );
      expect(changed.tags.single.name, 'smf_a');
      expect(changed.delimiterLine, 2);
    });
  });

  group('checkTemplateTags', () {
    List<String> check(List<SmfModule> modules, {bool complete = true}) {
      final resolution = resolutionOf(modules);
      final registry = ModuleRegistry(modules);
      final collection = collect(resolution, testContext);
      return [
        for (final issue in [
          ...checkTemplateTags(
            registry: registry,
            resolution: resolution,
            collection: collection,
          ),
          if (complete)
            ...missingTemplateTags(
              registry: registry,
              resolution: resolution,
              collection: collection,
            ),
        ])
          '${issue.origin}: ${issue.message}',
      ];
    }

    BrickContribution brick(Map<String, String> files) =>
        BrickContribution(bundle('b', files: files));

    test('accepts the tags of the sockets in their places', () {
      final roleSockets = <SocketRef>[];
      final families = <SocketFamily<Object?, SocketKind>>[];
      final nav = TestRole<NoDsl>(
        'nav',
        sockets: roleSockets,
        socketFamilies: families,
        template: TestTemplate(
          contributions: [
            BrickContribution(
              bundle('nav', files: {'lib/nav.dart': '{{{smf_nav__a}}}\n'}),
            ),
          ],
        ),
      );
      roleSockets.addAll([
        SocketRef<CodeSocket>.role(nav, 'a', const CodeSocket()),
        SocketRef<FactoryListSocket>.role(nav, 'b', const FactoryListSocket()),
      ]);
      final screens = SocketFamily<String, CodeSocket>.role(
        nav,
        'screens',
        const CodeSocket(),
        keyOf: (key) => [key],
      );
      families.add(screens);
      const parent = SocketRef<WrapperSocket>.module(
        ModuleId('parent'),
        'wrap',
        WrapperSocket(),
      );

      const target = '{{{smf_app_entry__ios_deployment_target}}}';

      expect(
        check([
          scaffold(
            contributions: [
              brick({
                'ios/Podfile': "platform :ios, '$target'",
                'ios/project': target,
              }),
            ],
          ),
          TestModule(
            'go',
            providers: [RoleProvider.plain(nav)],
            contributions: [
              brick({'lib/go.dart': '{{{smf_nav__b}}}'}),
            ],
          ),
          TestModule(
            'home',
            requires: {nav},
            contributions: [
              brick({
                'lib/home.dart': '{{{smf_nav__screens__home}}}\n'
                    'f() {{{app_name.snakeCase()}}}',
              }),
              SocketContribution.code(screens('home'), const Fragment('@A()')),
            ],
          ),
          TestModule(
            'parent',
            sockets: const [parent],
            contributions: [
              brick({
                'lib/p.dart': 'a{{{smf_parent__wrap_open}}}b'
                    '{{{smf_parent__wrap_close}}}',
              }),
            ],
          ),
        ]),
        isEmpty,
      );
    });

    test('rejects malformed and unknown tags', () {
      expect(
        check(
          [
            scaffold(
              bricks: false,
              contributions: [
                brick({
                  'lib/a.dart': '{{smf_app_entry__top_level}}\n'
                      '{{#x}}{{{smf_app_entry__bootstrap_late}}}{{/x}}\n'
                      'f() {{{{smf_app_entry__bootstrap_early}}}\n'
                      '{{{smf_app_entry__boostrap_di}}}\n'
                      '{{{smf_X}}}\n'
                      'g() {{{{labels}}}\n'
                      '{{& smf_app_entry__bootstrap_platform}}\n',
                  'lib/b.dart': '{{=<% %>=}}\n',
                }),
              ],
            ),
          ],
          complete: false,
        ),
        [
          contains('smf_app_entry__top_level in lib/a.dart:1 of scaffold '
              'must have three braces'),
          contains('inside the mustache section x'),
          contains('smf_app_entry__bootstrap_early in lib/a.dart:3 of '
              'scaffold comes right after a {'),
          contains('smf_app_entry__boostrap_di in lib/a.dart:4 of scaffold '
              'names no socket'),
          contains('smf_X in lib/a.dart:5 of scaffold is not a tag of a '
              'socket'),
          contains('labels in lib/a.dart:6 of scaffold comes right after'),
          contains('smf_app_entry__bootstrap_platform in lib/a.dart:7 of '
              'scaffold must have three braces'),
          equals(
            'scaffold: The template lib/b.dart:1 of scaffold changes the '
            'mustache delimiters, which the pipeline does not support.',
          ),
        ],
      );
    });

    test('a template that is not valid mustache is an error', () {
      final issues = check(
        [
          scaffold(
            contributions: [
              brick({
                'lib/a.dart':
                    '{{#open}}never closed {{{smf_app_entry__top_level}}}',
                'lib/b.dart': 'only {{a,b}}, which mason copies',
              }),
            ],
          ),
        ],
        complete: false,
      );

      expect(
        issues.single,
        startsWith(
          'scaffold: The template lib/a.dart of scaffold is not valid '
          'mustache:',
        ),
      );
    });

    test('paths use only variables, and templates no partials', () {
      expect(
        check(
          [
            scaffold(
              contributions: [
                brick({
                  'lib/{{app_name}}.dart': '',
                  '{{#has_router}}lib/r.dart{{/has_router}}': '',
                  '{{~ header }}': 'partial',
                  r'lib\{{% url %}}': '',
                  'lib/a.dart': 'a\n{{> header}}\n',
                }),
              ],
            ),
          ],
          complete: false,
        ),
        [
          contains('The path {{#has_router}}lib/r.dart{{/has_router}} in the '
              'brick b of scaffold has a mustache section'),
          contains('The path {{~ header }} in the brick b'),
          contains('The path lib/{{% url %}} in the brick b'),
          equals(
            'scaffold: The template lib/a.dart:2 of scaffold includes a '
            'partial, which the pipeline does not support.',
          ),
        ],
      );
    });

    test("presence flags are of the roles of the brick's owner", () {
      final nav = TestRole<NoDsl>('nav');
      final other = TestRole<NoDsl>('other');
      expect(
        check(
          [
            scaffold(),
            TestModule('go', providers: [RoleProvider.plain(nav)]),
            TestModule('elsewhere', providers: [RoleProvider.plain(other)]),
            TestModule(
              'home',
              uses: {nav},
              contributions: [
                brick({
                  'lib/home.dart': '{{#has_nav}}a{{/has_nav}}\n'
                      '{{^has_app_entry}}b{{/has_app_entry}}\n'
                      '{{#has_other}}c{{/has_other}}\n'
                      '{{has_nothing}}\n',
                }),
              ],
            ),
          ],
          complete: false,
        ),
        [
          equals(
            'home: The section has_other in lib/home.dart:3 of home is the '
            'flag of the other, which home does not provide, require or use, '
            'so the pipeline does not set it.',
          ),
          equals(
            'home: The tag has_nothing in lib/home.dart:4 of home names no '
            'role.',
          ),
        ],
      );
    });

    test('only owners hold the tags of their sockets', () {
      final sockets = <SocketRef>[];
      final nav = TestRole<NoDsl>('nav', sockets: sockets);
      sockets.add(SocketRef<CodeSocket>.role(nav, 'a', const CodeSocket()));
      const parent = SocketRef<CodeSocket>.module(
        ModuleId('parent'),
        'hook',
        CodeSocket(),
      );

      expect(
        check([
          scaffold(),
          TestModule(
            'go',
            providers: [RoleProvider.plain(nav)],
            contributions: [
              brick({'lib/go.dart': '{{{smf_nav__a}}}'}),
            ],
          ),
          TestModule(
            'parent',
            sockets: const [parent],
            contributions: [
              brick({'lib/p.dart': '{{{smf_parent__hook}}}'}),
            ],
          ),
          TestModule(
            'home',
            uses: {nav},
            dependsOn: {'parent'},
            contributions: [
              brick({'lib/h.dart': '{{{smf_nav__a}}}{{{smf_parent__hook}}}'}),
            ],
          ),
        ]),
        [
          contains('smf_nav__a in lib/h.dart:1 of home is a tag of the '
              'socket nav.a, which home may not hold'),
          contains('is a tag of the socket parent.hook, which home may not'),
        ],
      );
    });

    test('only tags of sockets for one value appear more than once', () {
      expect(
        check(
          [
            scaffold(
              bricks: false,
              contributions: [
                brick({
                  'lib/a.dart': '{{{smf_app_entry__bootstrap_late}}}',
                  'lib/b.dart': '{{{smf_app_entry__bootstrap_late}}}',
                  'android/a.xml':
                      '{{{smf_app_entry__android_manifest_permissions}}}\n'
                          '{{{smf_app_entry__android_manifest_permissions}}}',
                  'ios/a': '{{{smf_app_entry__ios_deployment_target}}}',
                  'ios/b': '{{{smf_app_entry__ios_deployment_target}}}',
                  'pubspec.yaml': '{{{smf_pubspec_flutter}}}\n'
                      '{{{smf_pubspec_flutter}}}',
                }),
              ],
            ),
          ],
          complete: false,
        ),
        [
          contains('smf_app_entry__bootstrap_late of the socket '
              'app_entry.bootstrap_late appears 2 times'),
          contains('smf_app_entry__android_manifest_permissions of the socket '
              'app_entry.android_manifest_permissions appears 2 times'),
          contains('smf_pubspec_flutter of the socket pipeline.pubspec_flutter '
              'appears 2 times'),
        ],
      );
    });

    test('sockets with imports are in Dart, and of the pipeline in pubspec',
        () {
      expect(
        check(
          [
            scaffold(
              bricks: false,
              contributions: [
                brick({
                  'lib/a.txt': '{{{smf_app_entry__bootstrap_late}}}',
                  'pubspec.yaml': 'x: {{{smf_pubspec_flutter}}}\n'
                      '{{{smf_pubspec_dependencies}}}',
                  'other.yaml': '{{{smf_pubspec_environment}}}',
                  'sub/pubspec.yaml': '{{{smf_pubspec_dev_dependencies}}}',
                }),
              ],
            ),
          ],
          complete: false,
        ),
        [
          contains('smf_app_entry__bootstrap_late in lib/a.txt:1 of scaffold '
              'is in a file that is not Dart'),
          contains('smf_pubspec_flutter in pubspec.yaml:1 of scaffold must be '
              'at the start of a line of the pubspec.yaml at the root of the '
              'app'),
          contains('smf_pubspec_environment in other.yaml:1 of scaffold must '
              'be at the start'),
          contains('smf_pubspec_dev_dependencies in sub/pubspec.yaml:1 of '
              'scaffold must be at the start'),
        ],
      );
    });

    test('wrappers need both tags in order and in one file', () {
      const one = SocketRef<WrapperSocket>.module(
        ModuleId('m'),
        'one',
        WrapperSocket(),
      );
      const two = SocketRef<WrapperSocket>.module(
        ModuleId('m'),
        'two',
        WrapperSocket(),
      );
      const three = SocketRef<WrapperSocket>.module(
        ModuleId('m'),
        'three',
        WrapperSocket(),
      );

      expect(
        check([
          scaffold(),
          TestModule(
            'm',
            sockets: const [one, two, three],
            contributions: [
              brick({
                'lib/a.dart': '{{{smf_m__one_open}}}'
                    '{{{smf_m__two_close}}}{{{smf_m__two_open}}}'
                    '{{{smf_m__three_open}}}',
                'lib/b.dart': '{{{smf_m__three_close}}}',
              }),
            ],
          ),
        ]),
        [
          contains('The socket m.one has only its tag smf_m__one_open'),
          contains('The tag smf_m__two_close of the socket m.two comes '
              'before smf_m__two_open'),
          contains('The tags of the socket m.three are in different files'),
        ],
      );
    });

    test('every socket that must have a tag has it', () {
      final sockets = <SocketRef>[];
      final families = <SocketFamily<Object?, SocketKind>>[];
      final nav = TestRole<NoDsl>(
        'nav',
        sockets: sockets,
        socketFamilies: families,
      );
      sockets.add(SocketRef<CodeSocket>.role(nav, 'a', const CodeSocket()));
      final screens = SocketFamily<String, CodeSocket>.role(
        nav,
        'screens',
        const CodeSocket(),
        keyOf: (key) => [key],
      );
      families.add(screens);
      final templated = <SocketRef>[];
      final service = TestRole<NoDsl>(
        'service',
        sockets: templated,
        template: TestTemplate(),
      );
      templated.add(
        SocketRef<CodeSocket>.role(service, 'impl', const CodeSocket()),
      );

      expect(
        check([
          scaffold(bricks: false),
          TestModule('go', providers: [RoleProvider.plain(nav)]),
          TestModule('prov', providers: [RoleProvider.plain(service)]),
          TestModule(
            'parent',
            sockets: const [
              SocketRef<CodeSocket>.module(
                ModuleId('parent'),
                'hook',
                CodeSocket(),
              ),
            ],
          ),
          TestModule(
            'home',
            requires: {nav},
            contributions: [
              SocketContribution.code(screens('home'), const Fragment('@A()')),
            ],
          ),
        ]),
        [
          // The test scaffold has no bricks, so the app entry misses all.
          for (final socket in appEntryRole.sockets)
            equals(
              'scaffold: No template of the app_entry or of its providers '
              'has the tag of the $socket (${socket.tags.join(', ')}).',
            ),
          equals(
            'go: No template of the nav or of its providers has the tag of '
            'the socket nav.a (smf_nav__a).',
          ),
          equals(
            'role:service: No template of the service or of its providers '
            'has the tag of the socket service.impl (smf_service__impl).',
          ),
          equals(
            'parent: The bricks of parent lack the tag of its socket '
            'parent.hook (smf_parent__hook).',
          ),
          for (final socket in PipelineSockets.all)
            equals(
              'null: No brick has the tag ${socket.tag} of the pipeline; the '
              'owner of pubspec.yaml puts it at the start of a line.',
            ),
        ],
      );
    });
  });
}
