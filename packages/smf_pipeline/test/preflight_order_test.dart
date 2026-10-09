import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The check of a tool that the machine lacks until the check installs it.
TestCheck _tool(String id) => TestCheck(
      id,
      status: PreflightMissing(
        instructions: 'Install the tool $id.',
        installable: true,
      ),
      afterInstall: const PreflightPassed(),
    );

/// A check that builds on [tool], the check of a module that the module of
/// this check depends on: it passes once the machine has the tool, as a
/// check of the version of the tool does, and installs nothing itself.
final class _BuildsOn extends PreflightCheck {
  _BuildsOn(this.id, this.tool, {this.required = false});

  @override
  final String id;

  /// The check that installs what this one looks for.
  final TestCheck tool;

  @override
  final bool required;

  /// How often the pipeline ran the check.
  int checks = 0;

  @override
  String get description => 'Tool $id';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    checks++;
    return tool.status is PreflightPassed
        ? const PreflightPassed()
        : PreflightMissing(instructions: 'Install ${tool.description}.');
  }
}

void main() {
  CreatePipeline pipeline(List<SmfModule> modules, FakeHost host) =>
      CreatePipeline(registry: ModuleRegistry(modules), host: host.host);

  CreateRequest request(
    List<String> modules, {
    bool strict = false,
    bool explain = false,
  }) =>
      CreateRequest(
        appName: 'my_app',
        org: 'com.example',
        modules: [for (final id in modules) ModuleId(id)],
        strict: strict,
        explain: explain,
      );

  /// The checks of [plan] in the order they ran, each as `module/check`.
  List<String> ran(GenerationPlan plan) =>
      [for (final result in plan.preflight.results) result.planned.key];

  /// The lines of the checks of the modules under `Machine` in the report
  /// of `--explain` that [host] printed.
  List<String> machine(FakeHost host) => [
        for (final line in host.logger.infos.skipWhile((l) => l != 'Machine'))
          if (line.contains(' (for ')) line,
      ];

  group('a module that depends on another, whose check installs a tool', () {
    late TestCheck cli;
    late _BuildsOn version;

    /// The module `core`, whose check installs the tool, and `rules`, which
    /// depends on it and has a check that needs the tool; that check is
    /// [required] if set, and [more] are further checks of `rules`.
    List<SmfModule> modules({
      bool required = false,
      List<PreflightCheck> more = const [],
    }) {
      cli = _tool('cli');
      version = _BuildsOn('version', cli, required: required);
      return [
        scaffold(),
        TestModule(
          'core',
          contributions: [
            Preflight([cli]),
          ],
        ),
        TestModule(
          'rules',
          dependsOn: {'core'},
          contributions: [
            Preflight([version, ...more]),
          ],
        ),
      ];
    }

    // The user names the module alone, and the pipeline adds the one it
    // depends on after it; or names it before that one; or after it.
    for (final named in [
      ['rules'],
      ['rules', 'core'],
      ['core', 'rules'],
    ]) {
      group('with the modules ${named.join(', ')}', () {
        test('has its check run again after the installation', () async {
          final host = FakeHost(answers: [true], terminal: true);

          final plan = (await pipeline(modules(), host).plan(request(named)))!;

          // Nothing is reported missing that the run installed.
          expect(host.logger.warnings, isEmpty);
          expect(
            [for (final result in plan.preflight.results) result.passed],
            everyElement(isTrue),
          );
          expect(ran(plan), [
            'pipeline/flutter_sdk',
            'core/cli',
            'rules/version',
          ]);
          // One question, of the check that can install the tool.
          expect(
            host.prompter.asked.single.message,
            'Tool cli is missing (needed by core). Install the tool cli. Set '
            'it up now?',
          );
          expect(cli.installs, 1);
          // Once before anything is installed, and once after.
          expect(version.checks, 2);
          expect(
            host.logger.progresses.where((e) => e.startsWith('start: ')),
            [
              'start: Checking the machine',
              'start: Checking Tool cli again',
              'start: Checking Tool version again',
            ],
          );
          await plan.environment.dispose();
        });

        test('is asked about what it lacks after that module', () async {
          final host = FakeHost(answers: [true, true], terminal: true);
          final own = _tool('own');

          final plan = (await pipeline(modules(more: [own]), host)
              .plan(request(named)))!;

          expect(
            host.prompter.asked.map((prompt) => prompt.message),
            [
              startsWith('Tool cli is missing (needed by core).'),
              startsWith('Tool own is missing (needed by rules).'),
            ],
          );
          expect(host.logger.warnings, isEmpty);
          await plan.environment.dispose();
        });

        test('has its warnings after those of that module', () async {
          // Without a terminal nothing is installed.
          final host = FakeHost();

          final plan = (await pipeline(modules(), host).plan(request(named)))!;

          expect(host.logger.warnings, [
            '[core]: Tool cli is missing. Install the tool cli.',
            '[rules]: Tool version is missing. Install Tool cli.',
          ]);
          await plan.environment.dispose();
        });

        test('has its checks after those of that module in --explain',
            () async {
          final host = FakeHost(terminal: true);

          final plan = await pipeline(modules(), host)
              .plan(request(named, explain: true));

          expect(plan, isNull);
          expect(machine(host), [
            '  ✗ Tool cli (for core): missing',
            '  ✗ Tool version (for rules): missing',
          ]);
          expect(host.prompter.asked, isEmpty);
        });

        test(
            'is not left out for a required check that the installation '
            'fixes', () async {
          final host = FakeHost(answers: [true], terminal: true);

          final plan = (await pipeline(modules(required: true), host)
              .plan(request(named)))!;

          expect(plan.leftOut, isEmpty);
          expect(
            plan.resolution.modules.map((module) => module.id.value),
            containsAll(['core', 'rules']),
          );
          expect(cli.installs, 1);
          expect(host.logger.warnings, isEmpty);
          await plan.environment.dispose();
        });

        test(
            'does not stop a strict run for a required check that the '
            'installation fixes', () async {
          final host = FakeHost(answers: [true], terminal: true);

          final plan = (await pipeline(modules(required: true), host)
              .plan(request(named, strict: true)))!;

          expect(cli.installs, 1);
          expect(
            [for (final result in plan.preflight.results) result.passed],
            everyElement(isTrue),
          );
          await plan.environment.dispose();
        });
      });
    }
  });

  group('the checks of the modules run', () {
    /// A module [id] that depends on [dependsOn], with the check `tool`.
    TestModule checked(String id, {Set<String> dependsOn = const {}}) =>
        TestModule(
          id,
          dependsOn: dependsOn,
          contributions: [
            Preflight([TestCheck('tool', status: const PreflightPassed())]),
          ],
        );

    /// The modules, of [registry], whose checks ran for an app of the
    /// modules [named], in the order of the checks.
    Future<List<String>> order(
      List<SmfModule> registry,
      List<String> named,
    ) async {
      final plan = (await pipeline([scaffold(), ...registry], FakeHost())
          .plan(request(named)))!;
      await plan.environment.dispose();
      return [
        for (final result in plan.preflight.results)
          if (result.planned.origin is ModuleOrigin) '${result.planned.origin}',
      ];
    }

    test('through a chain of dependencies', () async {
      final registry = [
        checked('base'),
        checked('middle', dependsOn: {'base'}),
        checked('top', dependsOn: {'middle'}),
      ];

      // The pipeline adds middle for top, and then base for middle.
      expect(await order(registry, ['top']), ['base', 'middle', 'top']);
      expect(
        await order(registry, ['top', 'base', 'middle']),
        ['base', 'middle', 'top'],
      );
    });

    test('after a module that is depended on through one without checks',
        () async {
      final host = FakeHost(answers: [true], terminal: true);
      final cli = _tool('cli');
      final version = _BuildsOn('version', cli);
      final registry = [
        scaffold(),
        TestModule(
          'base',
          contributions: [
            Preflight([cli]),
          ],
        ),
        TestModule('middle', dependsOn: {'base'}),
        TestModule(
          'top',
          dependsOn: {'middle'},
          contributions: [
            Preflight([version]),
          ],
        ),
      ];

      final plan = (await pipeline(registry, host).plan(request(['top'])))!;

      expect(ran(plan), ['pipeline/flutter_sdk', 'base/cli', 'top/version']);
      expect(plan.preflight.results.last.passed, isTrue);
      expect(host.logger.warnings, isEmpty);
      await plan.environment.dispose();
    });

    test('once each for two modules that depend on the same two', () async {
      final registry = [
        checked('first', dependsOn: {'left', 'right'}),
        checked('second', dependsOn: {'right', 'left'}),
        checked('left'),
        checked('right'),
      ];

      expect(
        await order(registry, ['first', 'second']),
        ['left', 'right', 'first', 'second'],
      );
      // The two that they depend on keep the order they were named in.
      expect(
        await order(registry, ['second', 'right', 'left', 'first']),
        ['right', 'left', 'second', 'first'],
      );
    });

    test(
        'in the order of the modules otherwise, with what a module depends '
        'on right before it', () async {
      final registry = [
        checked('zeta'),
        checked('rules', dependsOn: {'core'}),
        checked('alpha'),
        checked('core'),
      ];

      expect(
        await order(registry, ['zeta', 'rules', 'alpha']),
        ['zeta', 'core', 'rules', 'alpha'],
      );
    });

    test('in the order of the modules when none depends on another', () async {
      final registry = [
        checked('alpha'),
        checked('middle'),
        checked('zeta'),
      ];

      // As they were named, not by their names.
      expect(
        await order(registry, ['zeta', 'alpha', 'middle']),
        ['zeta', 'alpha', 'middle'],
      );
      expect(
        await order(registry, ['middle', 'zeta', 'alpha']),
        ['middle', 'zeta', 'alpha'],
      );
    });
  });
}
