import 'package:args/args.dart';
import 'package:smf_flutter_cli/commands/create.dart';
import 'package:smf_flutter_cli/commands/smf_command_runner.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:smf_flutter_cli/constants/smf_options.dart';
import 'package:test/test.dart';

import '../helpers/io_capture.dart';

void main() {
  group('CreateCommand', () {
    test('is named create', () {
      final command = CreateCommand();

      expect(command.name, 'create');
      expect(command.description, 'Create flutter app');
    });

    test('only allows modules that are registered', () {
      expect(smfModules.keys, containsAll(CreateCommand().allowedModules));
    });

    group('arguments', () {
      ArgResults parse(List<String> args) =>
          CreateCommand().argParser.parse(args);

      test('output defaults to the current directory', () {
        expect(parse([])['output'], './');
      });

      test('the project name is taken from the first positional argument', () {
        expect(parse(['my_app', '-o', '/tmp/out']).rest, ['my_app']);
      });

      test('state-manager only allows the supported state managers', () {
        expect(
          CreateCommand().argParser.options['state-manager']!.allowed,
          smfStateManagers,
        );
      });

      test('module, route, org and state-manager have no defaults', () {
        final results = parse([]);

        expect(results['modules'], isNull);
        expect(results['route'], isNull);
        expect(results['org'], isNull);
        expect(results['state-manager'], isNull);
      });
    });

    test('run rejects unknown modules before prompting or generating',
        () async {
      await expectLater(
        captureOutput(
          () => SMFCommandRunner().run([
            'create',
            'my_app',
            '--org',
            'com.acme',
            '--modules',
            'bogus',
            '--route',
            '/',
            '--state-manager',
            'bloc',
          ]),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid modules: bogus'),
          ),
        ),
      );
    });
  });
}
