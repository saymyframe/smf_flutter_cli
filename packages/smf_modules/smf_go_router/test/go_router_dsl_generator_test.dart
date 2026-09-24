import 'dart:io';

import 'package:mason/mason.dart' hide GeneratedFile;
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_go_router/bundles/smf_go_router_bundle.dart';
import 'package:smf_go_router/src/smf_go_router_module.dart';
import 'package:test/test.dart';

const _appName = 'test_app';

void main() {
  late Directory tempDir;
  late String projectRoot;

  String shellPath() =>
      join(projectRoot, 'lib', 'core', 'widgets', 'main_tabs_shell.dart');

  Future<List<GeneratedFile>> generate({
    required List<RouteGroup> routeGroups,
    List<ShellDeclaration> shellDeclarations = const [],
  }) {
    return SmfGoRouterModule().generateFromDsl(
      DslContext(
        projectRootPath: projectRoot,
        mustacheVariables: {'app_name': _appName},
        logger: Logger(),
        initialRoute: routeGroups.first.initialRoute!,
        routeGroups: routeGroups,
        shellDeclarations: shellDeclarations,
      ),
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smf_go_router_test');
    final generator = await MasonGenerator.fromBundle(smfGoRouterBundle);
    await generator.generate(
      DirectoryGeneratorTarget(tempDir),
      vars: {'app_name': _appName},
    );
    projectRoot = join(tempDir.path, _appName);
  });

  tearDown(() => tempDir.delete(recursive: true));

  test('removes the tabs shell template when no module adds tabs', () async {
    expect(File(shellPath()).existsSync(), isTrue);

    final files = await generate(
      routeGroups: [
        RouteGroup(
          initialRoute: '/noModules',
          routes: [
            Route(
              path: '/noModules',
              screen: RouteScreen('NoModulesScreen'),
            ),
          ],
        ),
      ],
    );

    expect(File(shellPath()).existsSync(), isFalse);
    expect(files.map((f) => f.path), isNot(contains(shellPath())));
    for (final file in files) {
      expect(file.content, isNot(contains('{{')), reason: file.path);
      expect(file.content, isNot(contains('main_tabs_shell')));
    }
  });

  test('renders the tabs shell when a module adds tabs', () async {
    final files = await generate(
      routeGroups: [
        RouteGroup(
          initialRoute: '/home',
          routes: [
            NestedRoute(
              shellLink: RouteShellLink.toMainTabsShell(),
              children: [
                Route(
                  path: '/home',
                  name: 'homeScreen',
                  screen: RouteScreen('HomeScreen'),
                  meta: RouteMeta(label: 'Home', icon: 'Icons.home'),
                ),
              ],
            ),
          ],
        ),
      ],
      shellDeclarations: [ShellRegistry.resolve('main-tabs')!],
    );

    final shell = files.singleWhere((f) => f.path == shellPath());
    expect(shell.content, contains('_TabInfo(path: "/home"'));
    expect(shell.content, isNot(contains('{{')));
  });
}
