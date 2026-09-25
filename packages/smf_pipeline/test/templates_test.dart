import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/src/registry.dart';
import 'package:smf_pipeline/src/templates.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('scanTemplate', () {
    test('finds socket tags with their line and sections', () {
      const text = '''
import 'a.dart';
{{{smf_app_entry__top_level}}}
{{#has_router}}
  {{{smf_router__observers}}}
  {{^has_layout}}{{smf_layout__x}}{{/has_layout}}
{{/has_router}}
{{app_name}} {{{facade}}} {{! {{{smf_in_comment}}} }}
void f() {{{{smf_after__brace}}}
''';

      final tags = scanTemplate('lib/main.dart', text);

      expect(
        [
          for (final tag in tags)
            [tag.name, tag.line, tag.triple, tag.sections, tag.afterBrace]
                .join(':'),
        ],
        [
          'smf_app_entry__top_level:2:true:[]:false',
          'smf_router__observers:4:true:[has_router]:false',
          'smf_layout__x:5:false:[has_router, has_layout]:false',
          'smf_after__brace:8:true:[]:true',
        ],
      );
      expect(tags.first.path, 'lib/main.dart');
      expect(tags.first.offset, text.indexOf('{{{smf_app'));
      expect('${tags.first}', 'smf_app_entry__top_level (lib/main.dart:2)');
    });

    test('stops at unclosed tags', () {
      expect(scanTemplate('a', '{{{smf_a}}} {{{smf_b'), hasLength(1));
      expect(scanTemplate('a', ''), isEmpty);
    });
  });

  group('checkTemplateTags', () {
    List<String> check(List<SmfModule> modules) {
      final resolution = resolutionOf(modules);
      return [
        for (final issue in checkTemplateTags(
          registry: ModuleRegistry(modules),
          resolution: resolution,
          collection: collect(resolution, testContext),
        ))
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
      families.add(
        SocketFamily<String, CodeSocket>.role(
          nav,
          'screens',
          const CodeSocket(),
          keyOf: (key) => [key],
        ),
      );
      const parent = SocketRef<WrapperSocket>.module(
        ModuleId('parent'),
        'wrap',
        WrapperSocket(),
      );

      expect(
        check([
          scaffold(
            contributions: [
              entryBrick(),
              brick({
                'pubspec.yaml': '{{{smf_pubspec_dependencies}}}\n',
                'ios/Podfile': '{{{smf_app_entry__ios_deployment_target}}}',
                'ios/project': '{{{smf_app_entry__ios_deployment_target}}}',
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
              brick({'lib/home.dart': '{{{smf_nav__screens__home}}}'}),
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
        check([
          scaffold(
            contributions: [
              brick({
                'lib/a.dart': '{{smf_app_entry__top_level}}\n'
                    '{{#x}}{{{smf_app_entry__bootstrap_late}}}{{/x}}\n'
                    'f() {{{{smf_app_entry__bootstrap_early}}}\n'
                    '{{{smf_app_entry__boostrap_di}}}\n',
              }),
            ],
          ),
        ]),
        [
          contains('smf_app_entry__top_level in lib/a.dart:1 of scaffold '
              'must have three braces'),
          contains('inside the mustache section x'),
          contains('comes right after a {'),
          contains('smf_app_entry__boostrap_di in lib/a.dart:4 of scaffold '
              'names no socket'),
        ].followedBy([
          // The other sockets of the app entry have no tags.
          for (var i = 0; i < appEntryRole.sockets.length - 3; i++)
            contains('No template of the app_entry'),
        ]).toList(),
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
          scaffold(contributions: [entryBrick()]),
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

    test('tags with imports and pipeline tags appear once', () {
      expect(
        check([
          scaffold(
            contributions: [
              entryBrick(),
              brick({
                'lib/a.dart': '{{{smf_app_entry__bootstrap_late}}}',
                'lib/b.dart': '{{{smf_app_entry__bootstrap_late}}}',
                'pubspec.yaml': '{{{smf_pubspec_flutter}}}'
                    '{{{smf_pubspec_flutter}}}',
              }),
            ],
          ),
        ]),
        [
          contains('smf_app_entry__bootstrap_late of the socket '
              'app_entry.bootstrap_late appears 3 times'),
          contains('smf_pubspec_flutter of the socket pipeline.pubspec_flutter '
              'appears 2 times'),
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
          scaffold(contributions: [entryBrick()]),
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

    test('every socket of a present role and module has its tag', () {
      final sockets = <SocketRef>[];
      final nav = TestRole<NoDsl>('nav', sockets: sockets);
      sockets.add(SocketRef<CodeSocket>.role(nav, 'a', const CodeSocket()));
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
          scaffold(),
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
        ],
      );
    });
  });
}
