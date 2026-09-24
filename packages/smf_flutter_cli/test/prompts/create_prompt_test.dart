import 'package:args/args.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/commands/create.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:smf_flutter_cli/prompts/prompt.dart';
import 'package:smf_flutter_cli/utils/module_creator.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:test/test.dart';

import '../helpers/io_capture.dart';
import '../helpers/mock_logger.dart';
import '../helpers/test_modules.dart';

/// `create` arguments with the project name, --org, --modules and
/// --state-manager always present, so none of the interactive prompts (which
/// would block on stdin) is reached. Pass `route: null` to omit --route.
List<String> _args({
  String modules = 'get_it',
  String? route = '/',
  String stateManager = 'bloc',
}) {
  return [
    'my_app',
    '--org',
    'com.acme',
    '--modules',
    modules,
    if (route != null) ...['--route', route],
    '--state-manager',
    stateManager,
  ];
}

void main() {
  group('CreatePrompt', () {
    final allowedModules = CreateCommand().allowedModules;
    late MockLogger logger;
    late ProbeFactory probe;
    late ModuleCreator creator;

    setUp(() {
      logger = MockLogger();
      // The probe is created as an extra core module and records the profile.
      probe = ProbeFactory('probe');
      creator = ModuleCreator(
        const ModuleDependencyResolver(),
        {...smfModules, 'probe': probe},
        coreModuleKeys: const [kFlutterCoreModule, kContractsModule, 'probe'],
      );
    });

    ArgResults parse(List<String> args) =>
        CreateCommand().argParser.parse(args);

    Future<ProjectPreferences> prompt(
      List<String> args, {
      List<String>? allowed,
      StrictMode strictMode = StrictMode.lenient,
      ModuleCreator? moduleCreator,
    }) async {
      late ProjectPreferences preferences;
      await captureOutput(() {
        preferences = CreatePrompt(creator: moduleCreator ?? creator).prompt(
          parse(args),
          allowedModules: allowed ?? allowedModules,
          strictMode: strictMode,
          logger: logger,
        );
      });
      return preferences;
    }

    List<String> namesOf(ProjectPreferences preferences) => [
          for (final module in preferences.selectedModules)
            module.moduleDescriptor.name,
        ];

    test('collects every value from the arguments', () async {
      final preferences = await prompt(_args(route: '/start'));

      expect(preferences.name, 'my_app');
      expect(preferences.packageName, 'com.acme');
      expect(preferences.initialRoute, '/start');
      expect(
        namesOf(preferences),
        unorderedEquals(
          [kFlutterCoreModule, kContractsModule, 'probe', kGetItModule],
        ),
      );
    });

    test('accepts the short option names', () async {
      final preferences = await prompt(
        ['my_app', '--org', 'o', '-m', 'get_it', '-r', '/a', '-s', 'bloc'],
      );

      expect(namesOf(preferences), contains(kGetItModule));
      expect(preferences.initialRoute, '/a');
    });

    test('greets the user on stdout', () async {
      final output = await captureOutput(() {
        CreatePrompt(creator: creator).prompt(
          parse(_args()),
          allowedModules: allowedModules,
          strictMode: StrictMode.lenient,
          logger: logger,
        );
      });

      expect(output.stdout, contains("Let's create a flutter project"));
    });

    test('builds modules for the chosen state manager', () async {
      await prompt(_args(stateManager: 'riverpod'));
      await prompt(_args());

      expect(
        probe.profiles.map((profile) => profile.stateManager),
        [StateManager.riverpod, StateManager.bloc],
      );
    });

    test('adds transitive dependencies of the selected modules', () async {
      final names = namesOf(await prompt(_args(modules: 'home')));

      expect(names, containsAll([kHomeFeatureModule, kGoRouterModule]));
      expect(
        names.indexOf(kGoRouterModule),
        lessThan(names.indexOf(kHomeFeatureModule)),
      );
    });

    test('trims module names and ignores duplicates and empty entries',
        () async {
      final names = namesOf(
        await prompt(_args(modules: ' get_it , event_bus,get_it,, ')),
      );

      expect(names.where((name) => name == kGetItModule), hasLength(1));
      expect(names, contains(kCommunicationModule));
    });

    group('without --route', () {
      test('uses the initial route of the only feature module that has one',
          () async {
        final preferences = await prompt(_args(modules: 'home', route: null));

        expect(preferences.initialRoute, '/home');
      });

      test('ignores the initial route of core modules', () async {
        final preferences = await prompt(_args(route: null));

        expect(preferences.initialRoute, isNull);
      });
    });

    group('validation', () {
      test('rejects module names that are not allowed', () async {
        await expectLater(
          prompt(_args(modules: 'home,unknown,other')),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Invalid modules: unknown, other'),
                contains('Allowed modules: ${allowedModules.join(', ')}'),
              ),
            ),
          ),
        );
      });

      test('rejects allowed modules that are missing from the registry',
          () async {
        await expectLater(
          prompt(
            _args(modules: kFirebaseAuthModule),
            allowed: [...allowedModules, kFirebaseAuthModule],
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Module "$kFirebaseAuthModule" is not registered'),
            ),
          ),
        );
      });

      test('rejects a state manager that is not supported', () {
        expect(
          () => parse(_args(stateManager: 'mobx')),
          throwsA(isA<ArgParserException>()),
        );
      });

      test('forwards strict mode to the module creator', () async {
        // go_router, a dependency of home, is missing from this registry.
        final registry = {...smfModules}..remove(kGoRouterModule);
        final partialCreator = ModuleCreator(
          const ModuleDependencyResolver(),
          registry,
        );

        await expectLater(
          prompt(
            _args(modules: 'home'),
            strictMode: StrictMode.strict,
            moduleCreator: partialCreator,
          ),
          throwsA(isA<StateError>()),
        );

        final lenient = await prompt(
          _args(modules: 'home'),
          moduleCreator: partialCreator,
        );
        expect(namesOf(lenient), isNot(contains(kHomeFeatureModule)));
      });
    });
  });
}
