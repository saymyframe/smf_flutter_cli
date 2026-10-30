@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

/// A role of images, with the rule of its step, the images that its providers
/// generate and the heading of its section.
typedef _ImageRole = ({
  Role<NoDsl> role,
  String rule,
  List<String> sources,
  String heading,
});

/// The two roles, which have one shape, each of them.
const List<_ImageRole> _roles = [
  (
    role: appIconRole,
    rule: 'app_icon.step',
    sources: [AppIconRole.imageFile, AppIconRole.foregroundFile],
    heading: AppIconRole.readmeHeading,
  ),
  (
    role: splashRole,
    rule: 'splash.step',
    sources: [SplashRole.lightImageFile, SplashRole.darkImageFile],
    heading: SplashRole.readmeHeading,
  ),
];

const _standIn = ModuleId('stand_in');
const _ofStandIn = ModuleOrigin(_standIn);

/// A step that draws the images with a tool of its own, which the machine
/// may lack, as a provider without any package of pub.dev could.
const _drawImages = PostGenStep(
  ToolRef('draw_images'),
  ['--all'],
  needs: ['draw_images'],
);

/// A small provider of [role], under the id [_standIn].
ModuleDescriptor _providerOf(Role<NoDsl> role) => ModuleDescriptor(
      id: _standIn,
      description: 'A provider of a test',
      kind: plainKind,
      providers: [RoleProvider<NoDsl>.plain(role)],
    );

/// The issues of the rule of [role] for [module] with [contributions], in an
/// app with [role] and the roles in [present].
List<SmfIssue> _stepIssues(
  Role<NoDsl> role,
  ModuleDescriptor module,
  List<Contribution> contributions, {
  Set<Role> present = const {},
}) =>
    role.checkModule(
      ModuleRuleRequest(
        hook: appWith({role, ...present}),
        module: module,
        contributions: contributions,
      ),
    );

/// The issues of [role] in an app with [modules], whose files have [owners].
List<SmfIssue> _sourceIssues(
  Role<NoDsl> role,
  Map<String, ContributionOrigin> owners, {
  List<ModuleDescriptor>? modules,
}) =>
    role.checkStructure(
      StructuralRuleRequest(
        hook: appWith({role}),
        files: const {},
        owners: owners,
        modules: modules ?? [_providerOf(role)],
      ),
    );

void main() {
  for (final (:role, :rule, :sources, :heading) in _roles) {
    group('the ${role.id} role', () {
      test('has no data, no sockets and no symbols, and its one rule', () {
        expect(role.sockets, isEmpty);
        expect(role.socketFamilies, isEmpty);
        expect(role.options, isEmpty);
        expect(role.structuralRules, isEmpty);
        expect(role.interface.files, isEmpty);
        expect(role.interface.symbols, isEmpty);
        expect(role.interface.providerFiles, sources);
        expect([for (final rule in role.moduleRules) rule.id], [rule]);
      });

      group('its rule of the step', () {
        test(
            'passes a provider with a step of any tool, also one that the '
            'machine may lack', () {
          expect(
            _stepIssues(role, _providerOf(role), const [_drawImages]),
            isEmpty,
          );
        });

        test('reports a provider without a step, as a problem of the provider',
            () {
          final issue = _stepIssues(role, _providerOf(role), const []).single;

          expect(issue.origin, _ofStandIn);
          expect(issue.severity, IssueSeverity.error);
          expect(
            issue.message,
            'The module stand_in provides the $role, which needs a step after '
            'generation that a run without a terminal runs too, but it has no '
            'step.',
          );
          expect(issue.hint, contains('PostGenStep'));
        });

        const leftOut = {
          'needs something outside the app': PostGenStep(
            ToolRef('draw_images'),
            ['--all'],
            external: true,
          ),
          'talks to the user': PostGenStep(
            ToolRef('draw_images'),
            ['--all'],
            interactive: true,
          ),
          'has a notice': PostGenStep(
            ToolRef('draw_images'),
            ['--all'],
            notice: 'It changes the Xcode project.',
            skippable: true,
          ),
          'runs only on some systems': PostGenStep(
            ToolRef('draw_images'),
            ['--all'],
            hosts: {HostOperatingSystem.macos},
          ),
          'continues another step': PostGenStep(
            ToolRef('draw_images'),
            ['--all'],
            followUpOf: PostGenStepId(ModuleId('other'), 'configure'),
          ),
        };

        for (final MapEntry(key: why, value: step) in leftOut.entries) {
          test('reports a provider whose only step $why', () {
            final issue = _stepIssues(role, _providerOf(role), [step]).single;

            expect(issue.origin, _ofStandIn);
            expect(issue.message, endsWith('but "draw_images --all" $why.'));
          });

          test('passes a provider with another step, besides one that $why',
              () {
            expect(
              _stepIssues(role, _providerOf(role), [step, _drawImages]),
              isEmpty,
            );
          });
        }

        test('names each step that a run without a terminal leaves out', () {
          final issue = _stepIssues(role, _providerOf(role), [
            leftOut['has a notice']!,
            leftOut['needs something outside the app']!,
          ]).single;

          expect(
            issue.message,
            endsWith(
              'but "draw_images --all" has a notice, and "draw_images --all" '
              'needs something outside the app.',
            ),
          );
        });

        test('counts a step under a role only in an app with that role', () {
          const step = PostGenStep(
            ToolRef('draw_images'),
            ['--all'],
            when: {themeRole},
          );

          expect(
            _stepIssues(role, _providerOf(role), const [step]),
            hasLength(1),
          );
          expect(
            _stepIssues(
              role,
              _providerOf(role),
              const [step],
              present: {themeRole},
            ),
            isEmpty,
          );
        });

        test('holds only a provider to it', () {
          final user = ModuleDescriptor(
            id: const ModuleId('user'),
            description: 'A module that only uses the role',
            kind: plainKind,
            uses: {role},
          );

          expect(_stepIssues(role, user, const []), isEmpty);
        });
      });

      group('the images that every provider generates', () {
        final all = {for (final path in sources) path: _ofStandIn};

        test('are in an app whose provider generates them', () {
          expect(_sourceIssues(role, all), isEmpty);
        });

        test('are reported one by one, as problems of the provider', () {
          for (final path in sources) {
            final issue = _sourceIssues(role, {...all}..remove(path)).single;

            expect(issue.origin, _ofStandIn);
            expect(issue.path, path);
            expect(issue.severity, IssueSeverity.error);
            expect(
              issue.message,
              'The module stand_in provides the $role, whose every provider '
              'generates $path, but the app has no such file.',
            );
          }
        });

        test(
            'may come from a variant of the provider, but from no other '
            'module and from no template', () {
          const ofVariant = ModuleOrigin(_standIn, variant: ModuleId('bloc'));
          expect(
            _sourceIssues(role, {for (final path in sources) path: ofVariant}),
            isEmpty,
          );

          for (final other in [
            const ModuleOrigin(ModuleId('other')),
            RoleTemplateOrigin(role),
          ]) {
            final issue = _sourceIssues(role, {
              ...all,
              sources.first: other,
            }).single;

            expect(issue.origin, _ofStandIn);
            expect(issue.message, endsWith('but $other has it.'));
          }
        });

        test('are asked of no module but a provider', () {
          final user = ModuleDescriptor(
            id: const ModuleId('user'),
            description: 'A module that only uses the role',
            kind: plainKind,
            uses: {role},
          );

          expect(_sourceIssues(role, const {}, modules: [user]), isEmpty);
        });
      });

      group('its template', () {
        final contributions = role.template!.contribute(testContext);
        final sockets = contributions.whereType<SocketContribution>();

        test('generates no file', () {
          expect(contributions.whereType<BrickContribution>(), isEmpty);
          expect(
            role.template!.render(inputOf(role)).files,
            isEmpty,
          );
        });

        test('writes the section of the role, which names the images', () {
          const socket = AppEntryRole.readmeSections;
          final section = sockets.singleWhere((c) => c.socket == socket);

          expect(section.entryKey, heading);
          expect(socket.problemsWith(section), isEmpty);
          expect(
            codeSpansOf(section.entryValue! as String),
            containsAll(sources),
          );
        });

        test('writes the note of the role, which names the images', () {
          expect(codeSpansOf(agentNoteOf(role).text), containsAll(sources));
        });
      });
    });
  }

  test('an image of one role is no image of the other', () {
    expect(
      appIconRole.interface.providerFiles.toSet().intersection(
            splashRole.interface.providerFiles.toSet(),
          ),
      isEmpty,
    );
  });

  // What a provider draws with and what its images show is up to the
  // provider: a second one, such as a company's own module with its own
  // logo, has to find these texts true.
  test('the roles name no tool, and no art of a provider', () {
    const names = [
      'launcher_icons',
      'launcher icons',
      'native_splash',
      'native splash',
      'flutter_launcher',
      'flutter_native',
      'Say My Frame',
      'dart run',
    ];
    for (final path in ['app_icon', 'splash', 'image_steps']) {
      final text = File('lib/src/roles/$path.dart').readAsStringSync();

      for (final name in names) {
        expect(text, isNot(contains(name)), reason: path);
      }
    }
  });
}
