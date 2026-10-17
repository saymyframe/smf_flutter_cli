import 'package:smf_contracts/core.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('ContributionOrigin', () {
    test('a module origin compares by module and variant', () {
      const home = ModuleOrigin(ModuleId('home'));
      const homeBloc =
          ModuleOrigin(ModuleId('home'), variant: ModuleId('bloc'));

      expect(home, const ModuleOrigin(ModuleId('home')));
      expect(home.hashCode, const ModuleOrigin(ModuleId('home')).hashCode);
      expect(home, isNot(homeBloc));
      expect('$home', 'home');
      expect('$homeBloc', 'home (bloc)');
    });

    test('a role template origin compares by role identity', () {
      final router = TestRole<String>('router');
      final origin = RoleTemplateOrigin(router);

      expect(origin, RoleTemplateOrigin(router));
      expect(origin.hashCode, RoleTemplateOrigin(router).hashCode);
      expect(origin, isNot(RoleTemplateOrigin(TestRole<String>('router'))));
      expect('$origin', 'role:router');
    });

    test('the pipeline origin is one value', () {
      expect(const PipelineOrigin(), const PipelineOrigin());
      expect(const PipelineOrigin().hashCode, const PipelineOrigin().hashCode);
      expect(const PipelineOrigin(), isNot(const ModuleOrigin(ModuleId('a'))));
      expect('${const PipelineOrigin()}', 'pipeline');
    });
  });

  group('SmfIssue', () {
    test('is an error by default', () {
      const issue = SmfIssue('Broken.');

      expect(issue.severity, IssueSeverity.error);
      expect(issue.isError, isTrue);
      expect(issue.category, isNull);
      expect(issue.code, isNull);
      expect(issue.hint, isNull);
      expect(issue.origin, isNull);
      expect(issue.path, isNull);
      expect('$issue', 'error: Broken.');
    });

    test('describes its origin, code, file and hint', () {
      const issue = SmfIssue.warning(
        'Unused import.',
        code: 'imports.unused',
        hint: 'Remove it.',
        origin: ModuleOrigin(ModuleId('home')),
        path: 'lib/main.dart',
      );

      expect(issue.severity, IssueSeverity.warning);
      expect(issue.isError, isFalse);
      expect(issue.category, WarningCategory.composition);
      expect(issue.code, 'imports.unused');
      expect(
        '$issue',
        'warning [home] imports.unused lib/main.dart: Unused import. '
            '(Remove it.)',
      );
      expect(
        '${const SmfIssue.warning('Late.', code: 'router.no_start')}',
        'warning router.no_start: Late.',
      );
    });

    test('is a warning about the machine without a code', () {
      const issue = SmfIssue.machineWarning(
        'Tool cli is missing.',
        hint: 'Install it.',
        origin: ModuleOrigin(ModuleId('home')),
      );

      expect(issue.severity, IssueSeverity.warning);
      expect(issue.isError, isFalse);
      expect(issue.category, WarningCategory.machine);
      expect(issue.code, isNull);
      expect(issue.path, isNull);
      expect('$issue', 'warning [home]: Tool cli is missing. (Install it.)');
    });

    test('takes as a code of a warning two names with a dot between them', () {
      for (final code in ['router.no_start', 'a.b', 'app_entry.x1_y']) {
        expect(SmfIssue.isWarningCode(code), isTrue, reason: code);
      }
      for (final code in [
        '',
        'router',
        'router.',
        '.no_start',
        'router.no.start',
        'Router.no_start',
        'router.noStart',
        'router.no-start',
        'router. no_start',
      ]) {
        expect(SmfIssue.isWarningCode(code), isFalse, reason: code);
      }
    });
  });

  test('SmfUsageException describes the problem', () {
    const exception = SmfUsageException('Pass --start.');

    expect(exception.message, 'Pass --start.');
    expect('$exception', 'SmfUsageException: Pass --start.');
  });
}
