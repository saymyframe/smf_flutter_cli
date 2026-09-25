import 'package:smf_contracts/lego_core.dart';
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
      expect(issue.hint, isNull);
      expect(issue.origin, isNull);
      expect(issue.path, isNull);
      expect('$issue', 'error: Broken.');
    });

    test('describes its origin, file and hint', () {
      const issue = SmfIssue.warning(
        'Unused import.',
        hint: 'Remove it.',
        origin: ModuleOrigin(ModuleId('home')),
        path: 'lib/main.dart',
      );

      expect(issue.isError, isFalse);
      expect(
        '$issue',
        'warning [home] lib/main.dart: Unused import. (Remove it.)',
      );
    });
  });

  test('SmfUsageException describes the problem', () {
    const exception = SmfUsageException('Pass --start.');

    expect(exception.message, 'Pass --start.');
    expect('$exception', 'SmfUsageException: Pass --start.');
  });
}
