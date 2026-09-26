import 'package:args/args.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final role = TestRole<NoDsl>(
    'nav',
    options: const [
      RoleOption(name: 'start', help: 'The start.', valueHelp: 'path'),
      RoleOption(name: 'mode', help: 'The mode.', allowed: ['a', 'b']),
    ],
  );

  CreateRequest parse(List<String> args) {
    final parser = ArgParser();
    CreateOptions.addTo(parser, [role]);
    return CreateRequest.fromArgs(parser.parse(args), [role]);
  }

  test('has defaults', () {
    final request = parse([]);

    expect(request.appName, isNull);
    expect(request.org, isNull);
    expect(request.outputDirectory, '.');
    expect(request.onConflict, OnConflict.prompt);
    expect(request.strict, isFalse);
    expect(request.explain, isFalse);
    expect(request.skipExternalSetup, isFalse);
    expect(request.input, isTrue);
    expect(request.dartFix, isTrue);
    expect(request.modules, isNull);
    expect(request.roleOptions, isEmpty);
  });

  test('reads every option', () {
    final request = parse([
      'my_app',
      '-m',
      ' home , go_router,,home',
      '--org',
      'com.acme',
      '-o',
      '/tmp/out',
      '--on-conflict',
      'replace',
      '--strict',
      '--explain',
      '--skip-external-setup',
      '--no-input',
      '--no-dart-fix',
      '--start',
      '/home',
    ]);

    expect(request.appName, 'my_app');
    expect(request.org, 'com.acme');
    expect(request.outputDirectory, '/tmp/out');
    expect(request.onConflict, OnConflict.replace);
    expect(request.strict, isTrue);
    expect(request.explain, isTrue);
    expect(request.skipExternalSetup, isTrue);
    expect(request.input, isFalse);
    expect(request.dartFix, isFalse);
    expect(
      request.modules,
      [const ModuleId('home'), const ModuleId('go_router')],
    );
    expect(request.roleOptions, {'start': '/home'});
  });

  test('an empty -m asks for no modules', () {
    expect(parse(['-m', '']).modules, isEmpty);
  });

  test('rejects invalid module names and several app names', () {
    expect(() => parse(['-m', 'Home']), throwsA(isA<SmfUsageException>()));
    expect(
      () => parse(['a', 'b']),
      throwsA(
        isA<SmfUsageException>()
            .having((e) => e.message, 'message', contains('not 2')),
      ),
    );
  });

  test('role options keep their help and allowed values', () {
    final parser = ArgParser();
    CreateOptions.addTo(parser, [role]);

    expect(parser.options['start']!.valueHelp, 'path');
    expect(parser.options['mode']!.allowed, ['a', 'b']);
    expect(parser.options['dart-fix']!.hide, isTrue);
    expect(CreateOptions.names, contains('on-conflict'));
  });
}
