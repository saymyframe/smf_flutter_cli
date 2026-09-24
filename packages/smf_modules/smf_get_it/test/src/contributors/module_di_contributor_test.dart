import 'dart:io';

import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/get_it_code_generator.dart';
import 'package:smf_get_it/src/contributors/module_di_contributor.dart';
import 'package:test/test.dart';

import '../../helpers/dart_code.dart';
import '../../helpers/project.dart';

const _authTemplate = 'lib/features/auth/di/auth_di.dart';
const _cartTemplate = 'lib/features/cart/di/cart_di.dart';

DiDependencyGroup _moduleGroup(
  String template,
  String type, {
  required String importPath,
}) {
  return DiDependencyGroup(
    scope: DiScope.module,
    pathToDiTemplate: template,
    imports: [Import.features(importPath)],
    diDependencies: [
      DiDependency(
        abstractType: 'I$type',
        implementation: '$type()',
        bindingType: DiBindingType.factory,
      ),
    ],
  );
}

void main() {
  late Directory tempDir;
  late ModuleDiContributor contributor;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smf_module_di');
    await writeModuleDiTemplate(
      tempDir.path,
      _authTemplate,
      setUpFunction: 'setUpAuthDI',
    );
    await writeModuleDiTemplate(
      tempDir.path,
      _cartTemplate,
      setUpFunction: 'setUpCartDI',
    );
    contributor = ModuleDiContributor(
      projectRoot: tempDir.path,
      codeGenerator: const GetItCodeGenerator(),
    );
  });

  tearDown(() => tempDir.delete(recursive: true));

  group('ModuleDiContributor', () {
    test('renders one file per template, combining groups that share it',
        () async {
      final files = await contributor.contribute(
        [
          _moduleGroup(
            _authTemplate,
            'AuthRepository',
            importPath: 'auth/auth_repository.dart',
          ),
          _moduleGroup(
            _cartTemplate,
            'CartRepository',
            importPath: 'cart/cart_repository.dart',
          ),
          _moduleGroup(
            _authTemplate,
            'SessionStore',
            importPath: 'auth/session_store.dart',
          ),
        ],
        mustacheVariables: {'app_name': appName},
      );

      expect(files.map((f) => f.path), [
        join(tempDir.path, _authTemplate),
        join(tempDir.path, _cartTemplate),
      ]);

      final auth = files[0].content;
      expect(auth, contains('void setUpAuthDI() {'));
      expect(
        auth,
        contains(
          "import 'package:test_app/features/auth/auth_repository.dart';",
        ),
      );
      expect(
        auth,
        contains("import 'package:test_app/features/auth/session_store.dart';"),
      );
      expect(
        auth,
        contains(
          'getIt.registerFactory<IAuthRepository>(() => AuthRepository());',
        ),
      );
      expect(
        auth,
        contains('getIt.registerFactory<ISessionStore>(() => SessionStore());'),
      );
      expect(auth, isNot(contains('Cart')));

      final cart = files[1].content;
      expect(cart, contains('void setUpCartDI() {'));
      expect(
        cart,
        contains(
          'getIt.registerFactory<ICartRepository>(() => CartRepository());',
        ),
      );
      expect(cart, isNot(contains('Auth')));
      expect(cart, isNot(contains('Session')));

      for (final file in files) {
        expect(file.content, isNot(contains('{{')), reason: file.path);
        expectParses(file.content);
      }
    });

    test('renders nothing when there are no module groups', () async {
      expect(await contributor.contribute([]), isEmpty);
    });
  });
}
