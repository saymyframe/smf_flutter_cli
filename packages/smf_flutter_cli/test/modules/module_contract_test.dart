import 'dart:io';

import 'package:mason/mason.dart';
import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/commands/create.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:smf_flutter_cli/prompts/prompt.dart';
import 'package:smf_flutter_cli/utils/module_creator.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:test/test.dart';

import 'support/module_contract_support.dart';
import 'support/mustache_tags.dart';

const _appImportsCheck = 'Dart files import only app files its dependency '
    'closure renders';
const _packageImportsCheck = 'Dart files import only packages its dependency '
    'closure declares';

/// Contract checks that currently fail because of known bugs, by module key.
const _knownBugs = <String, Map<String, String>>{
  kFirebaseAnalytics: {
    _appImportsCheck: 'Bug: the firebase_analytics brick imports '
        'core/services/communication/base_event.dart, which only the '
        'event_bus brick renders, but the module does not depend on event_bus',
    _packageImportsCheck: 'Bug: the firebase_analytics brick imports '
        'flutter_bloc, but the module does not declare it',
  },
};

String? _knownBug(String module, String check) => _knownBugs[module]?[check];

void main() {
  late Directory tempRoot;
  final renders = <String, Future<RenderedBrick>>{};

  setUpAll(() async {
    tempRoot = await Directory.systemTemp.createTemp('smf_module_contract_');
    // MasonGenerator.fromBundle unpacks bundles into the mason cache; keep it
    // inside the temp dir instead of ~/.mason-cache.
    BricksJson.testEnvironment = {
      'MASON_CACHE': p.join(tempRoot.path, 'mason_cache'),
    };
  });

  tearDownAll(() async {
    BricksJson.testEnvironment = null;
    await tempRoot.delete(recursive: true);
  });

  group('module registry', () {
    test('every module offered by smf create is registered', () {
      expect(smfModules.keys, containsAll(CreateCommand().allowedModules));
    });

    test('every core module is registered', () {
      expect(smfModules.keys, containsAll(coreModuleKeys));
    });
  });

  for (final stateManager in StateManager.values) {
    final profile = ModuleProfile(stateManager: stateManager);
    final modules = modulesFor(profile);

    Future<RenderedBrick> render(BrickContribution brick) {
      return renders.putIfAbsent(
        '${stateManager.name}/${brick.name}/${brick.bundle.name}',
        () async {
          final profileDirectory = await Directory(
            p.join(tempRoot.path, stateManager.name),
          ).create();
          final output = await profileDirectory.createTemp('brick_');
          return renderBrick(
            brick,
            outputDirectory: output,
            coreVars: cliBrickVars(
              outputDirectory: output.path,
              modules: modules.values,
            ),
          );
        },
      );
    }

    /// Files rendered by the bricks of every module in [key]'s closure.
    Future<Map<String, String?>> closureFiles(String key) async {
      final files = <String, String?>{};
      for (final name in dependencyClosure(key, modules)) {
        for (final brick in modules[name]!.brickContributions) {
          files.addAll((await render(brick)).files);
        }
      }
      return files;
    }

    /// Packages lib/ code of a project with module [key] may import: the
    /// base pubspec dependencies plus those its dependency closure declares.
    Future<Set<String>> closurePackages(String key) async {
      final pubspec = (await closureFiles(key))['pubspec.yaml'];
      return {
        if (pubspec != null) ...pubspecDependencies(pubspec),
        for (final name in dependencyClosure(key, modules))
          for (final spec in modules[name]!.moduleDescriptor.pubDependency)
            parsePubSpec(spec).name,
      };
    }

    group('[${stateManager.name}]', () {
      test('core modules support the profile', () {
        expect(modules.keys, containsAll(coreModuleKeys));
      });

      test('descriptor names are unique', () {
        final names = modules.values.map((m) => m.moduleDescriptor.name);

        expect(names.toSet(), hasLength(names.length));
      });

      test('brick names are unique', () {
        final names = modules.values
            .expand((m) => m.brickContributions)
            .map((b) => b.name)
            .toList();

        expect(names.toSet(), hasLength(names.length));
      });

      test('module dependency graph has no cycles', () {
        final visiting = <String>[];
        final done = <String>{};
        final cycles = <String>[];

        void visit(String name) {
          if (done.contains(name) || !modules.containsKey(name)) return;
          if (visiting.contains(name)) {
            cycles.add([...visiting, name].join(' -> '));
            return;
          }
          visiting.add(name);
          modules[name]!.moduleDescriptor.dependsOn.forEach(visit);
          visiting.removeLast();
          done.add(name);
        }

        modules.keys.forEach(visit);
        expect(cycles, isEmpty);
      });

      test('ModuleCreator builds every module in strict mode', () {
        final built = ModuleCreator(
          const ModuleDependencyResolver(),
          smfModules,
          coreModuleKeys: coreModuleKeys,
        ).build(
          [
            for (final key in modules.keys)
              if (!coreModuleKeys.contains(key)) smfModules[key]!,
          ],
          profile,
          strictMode: StrictMode.strict,
        );

        final order = built.map((m) => m.moduleDescriptor.name).toList();
        expect(order, unorderedEquals(modules.keys));
        for (final module in built) {
          for (final dependency in module.moduleDescriptor.dependsOn) {
            expect(
              order.indexOf(dependency),
              lessThan(order.indexOf(module.moduleDescriptor.name)),
              reason: '${module.moduleDescriptor.name} needs $dependency',
            );
          }
        }
      });

      test('modules agree on the constraint of shared pub packages', () {
        final constraints = <String, Map<String, String>>{};
        for (final entry in modules.entries) {
          final descriptor = entry.value.moduleDescriptor;
          for (final spec in {
            ...descriptor.pubDependency,
            ...descriptor.pubDevDependency,
          }) {
            final parsed = parsePubSpec(spec);
            (constraints[parsed.name] ??= {})[entry.key] =
                parsed.constraint.toString();
          }
        }

        final conflicts = {
          for (final entry in constraints.entries)
            if (entry.value.values.toSet().length > 1) entry.key: entry.value,
        };
        expect(conflicts, isEmpty);
      });

      test('no package is both a dependency and a dev dependency', () {
        Set<String> names(Set<String> Function(ModuleDescriptor) specs) => {
              for (final module in modules.values)
                for (final spec in specs(module.moduleDescriptor))
                  parsePubSpec(spec).name,
            };

        expect(
          names((d) => d.pubDependency)
              .intersection(names((d) => d.pubDevDependency)),
          isEmpty,
        );
      });

      for (final MapEntry(key: key, value: module) in modules.entries) {
        final descriptor = module.moduleDescriptor;

        group(key, () {
          test('descriptor name is non-empty and matches its registry key', () {
            // ModuleCreator looks dependencies up by name in the registry.
            expect(descriptor.name.trim(), isNotEmpty);
            expect(descriptor.name, key);
          });

          test('depends only on other registered modules', () {
            expect(descriptor.dependsOn, isNot(contains(key)));
            for (final dependency in descriptor.dependsOn) {
              expect(smfModules.keys, contains(dependency));
            }
          });

          test('declares pub dependencies as "package: constraint"', () {
            for (final spec in {
              ...descriptor.pubDependency,
              ...descriptor.pubDevDependency,
            }) {
              expect(() => parsePubSpec(spec), returnsNormally, reason: spec);
            }
          });

          test('brick bundles decode and hold no machine-local files', () {
            for (final brick in module.brickContributions) {
              final paths = [
                ...decodeBundleFiles(brick.bundle.files).keys,
                for (final hook in decodeBundleFiles(brick.bundle.hooks).keys)
                  'hooks/$hook',
              ];

              expect(
                paths.where(isMachineLocalPath),
                isEmpty,
                reason: brick.name,
              );
            }
          });

          for (final brick in module.brickContributions) {
            final label = 'brick "${brick.name}"';

            test('$label uses only variables the CLI provides', () {
              final provided = {
                ...cliBrickVars(outputDirectory: '', modules: modules.values)
                    .keys,
                ...?brick.vars?.keys,
              };
              final files = decodeBundleFiles(brick.bundle.files);
              final referenced = {
                for (final entry in files.entries) ...[
                  ...referencedVariables(entry.key),
                  if (entry.value != null) ...referencedVariables(entry.value!),
                ],
              };

              expect(referenced.difference(provided), isEmpty);
            });

            test('$label renders every file inside the app directory',
                () async {
              final rendered = await render(brick);

              expect(rendered.outsideAppRoot, isEmpty);
              expect(rendered.files, hasLength(brick.bundle.files.length));
            });

            test('$label leaves only DSL slots unrendered', () async {
              final rendered = await render(brick);

              for (final MapEntry(key: path, value: content)
                  in rendered.files.entries) {
                expect(path, isNot(contains('{{')));
                if (content == null) continue;
                expect(unexpectedLeftoverTags(content), isEmpty, reason: path);
              }
            });
          }

          test(
            _appImportsCheck,
            () async {
              final available = (await closureFiles(key)).keys.toSet();
              final unresolved = <String>[];
              for (final brick in module.brickContributions) {
                final rendered = await render(brick);
                for (final MapEntry(key: path, value: content)
                    in rendered.files.entries) {
                  if (!path.endsWith('.dart') || content == null) continue;
                  for (final uri in directiveUris(content)) {
                    final target = resolveUri(uri, fromFile: path).appFile;
                    if (target != null && !available.contains(target)) {
                      unresolved.add('$path -> $uri');
                    }
                  }
                }
              }

              expect(unresolved, isEmpty);
            },
            skip: _knownBug(key, _appImportsCheck),
          );

          test(
            _packageImportsCheck,
            () async {
              final packages = await closurePackages(key);
              final undeclared = <String>[];
              for (final brick in module.brickContributions) {
                final rendered = await render(brick);
                for (final MapEntry(key: path, value: content)
                    in rendered.files.entries) {
                  if (!path.startsWith('lib/') || content == null) continue;
                  for (final uri in directiveUris(content)) {
                    final package = resolveUri(uri, fromFile: path).package;
                    if (package != null && !packages.contains(package)) {
                      undeclared.add('$path -> $uri');
                    }
                  }
                }
              }

              expect(undeclared, isEmpty);
            },
            skip: _knownBug(key, _packageImportsCheck),
          );

          test('DI, route and patch imports resolve within its closure',
              () async {
            final available = (await closureFiles(key)).keys.toSet();
            final packages = await closurePackages(key);
            final unresolved = <String>[];
            for (final statement in [
              ...dslImportStatements(module),
              ...contributionImportStatements(module),
            ]) {
              final target = resolveUri(statementUri(statement));
              if ((target.appFile != null &&
                      !available.contains(target.appFile)) ||
                  (target.package != null &&
                      !packages.contains(target.package))) {
                unresolved.add(statement);
              }
            }

            expect(unresolved, isEmpty);
          });

          test('shared file patches target files its closure renders',
              () async {
            final available = (await closureFiles(key)).keys.toSet();

            for (final contribution in module.sharedFileContributions) {
              expect(
                available,
                contains(contribution.file),
                reason: '${contribution.runtimeType}',
              );
            }
          });

          test('nested routes link to shells its closure renders', () async {
            final available = (await closureFiles(key)).keys.toSet();

            for (final route in module.routes.routes.whereType<NestedRoute>()) {
              final shell = ShellRegistry.resolve(route.shellLink.id);
              expect(shell, isNotNull, reason: route.shellLink.id);
              expect(available, contains('lib/${shell!.widgetFilePath}'));
              if (shell.type == ShellType.tabBar) {
                for (final child in route.children) {
                  expect(child.meta, isNotNull, reason: child.path);
                }
              }
            }
          });

          test('initial route is one of its routes', () {
            final initialRoute = module.routes.initialRoute;
            if (initialRoute == null) return;

            expect(
              allRoutes(module.routes).map((r) => r.path),
              contains(initialRoute),
            );
          });
        });
      }
    });
  }

  group('contract helpers', () {
    test('flag every kind of machine-local file', () {
      const paths = [
        '{{app}}/android/local.properties',
        '{{app}}/ios/Flutter/Generated.xcconfig',
        '{{app}}/ios/Flutter/flutter_export_environment.sh',
        '{{app}}/ios/Runner.xcodeproj/xcuserdata/me.xcuserdatad/x.plist',
        'hooks/.dart_tool/package_config.json',
        '{{app}}/ios/Runner/GeneratedPluginRegistrant.m',
        '{{app}}/linux/flutter/ephemeral/x.h',
        '{{app}}/lib/.DS_Store',
        '{{app}}/build/app.dill',
        'hooks/pubspec.lock',
      ];

      expect(paths.where((path) => !isMachineLocalPath(path)), isEmpty);
      expect(isMachineLocalPath('{{app}}/android/build.gradle.kts'), isFalse);
      expect(isMachineLocalPath('hooks/pubspec.yaml'), isFalse);
    });

    test('scan tags like mustache and skip delimiter-escaped slots', () {
      const template = 'final a = {{app_name.snakeCase()}};\n'
          '{{=<% %>=}}\n{{#imports}}\n{{{.}}}\n{{/imports}}\n<%={{ }}=%>\n'
          '{{#modules}} {{{.}}} {{/modules}}';

      expect(referencedVariables(template), {'app_name', 'modules'});
      expect(
        unexpectedLeftoverTags('{{#imports}}\n{{{.}}}\n{{/imports}}'),
        isEmpty,
      );
      expect(
        unexpectedLeftoverTags('{{app_name}} {{#modules}}{{/modules}}'),
        ['{{app_name}}', '{{#modules}}', '{{/modules}}'],
      );
    });

    test('parse pub dependency specs', () {
      expect(parsePubSpec('go_router: ^16.0.0').name, 'go_router');
      expect(() => parsePubSpec('go_router ^16.0.0'), throwsFormatException);
      expect(() => parsePubSpec('Go-Router: ^16.0.0'), throwsFormatException);
      expect(() => parsePubSpec('go_router: ^16.x'), throwsFormatException);
    });
  });
}
