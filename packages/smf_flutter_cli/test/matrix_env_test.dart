// How the apps of the matrices of SMF get the values of their .env
// (matrixEnv), in apps whose modules, or the templates of whose roles, give
// the env role keys.
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_dart_define/smf_dart_define.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_env.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:test/test.dart';

/// A module of the test that requires the env role and gives it two keys.
final class _Shop extends SmfModule {
  const _Shop();

  static const id = ModuleId('shop');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The keys of a shop (test)',
        kind: ModuleKinds.infrastructure,
        requires: {envRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        envRole.data(
          const EnvKey('SHOP_KEY', description: 'The key of the shop'),
        ),
        envRole.data(
          const EnvKey('SHOP_URL', description: 'The address of the shop'),
        ),
      ];
}

/// A role of the test that requires the env role, whose template gives it a
/// key.
final class _BoardRole extends Role<NoDsl> {
  const _BoardRole();

  @override
  String get id => 'board';

  @override
  String get description => 'Board';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  Set<Role> get requires => const {envRole};

  @override
  RoleTemplate<NoDsl> get template => const _BoardTemplate();
}

final class _BoardTemplate extends RoleTemplate<NoDsl> {
  const _BoardTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        envRole.data(
          const EnvKey('BOARD_TOKEN', description: 'The token of the board'),
        ),
      ];
}

/// A module of the test that provides the role of the test.
final class _Boards extends SmfModule {
  const _Boards();

  static const id = ModuleId('boards');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'The boards (test)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(_BoardRole())],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [];
}

void main() {
  test(
      'gives the keys of an app with the module that gives each, and the '
      'arguments of the provider of the role, as the role has them', () async {
    final (:apps, :failed) = await matrixOf(const [
      FlutterCoreModule(),
      DartDefineModule(),
      _Shop(),
    ]);

    expect(failed, isEmpty);
    final shop = apps.singleWhere((app) => app.modules.contains(_Shop.id));
    expect(matrixEnv.file, EnvRole.dotEnvFile);
    expect(matrixEnv.keys(shop), {
      'SHOP_KEY': const MatrixEnvKeyOwner.module(_Shop.id),
      'SHOP_URL': const MatrixEnvKeyOwner.module(_Shop.id),
    });
    expect(matrixEnv.toolArguments(shop), [
      '--dart-define-from-file=${EnvRole.dotEnvFile}',
    ]);
    final core = apps.singleWhere((app) => app.name == 'flutter_core');
    expect(matrixEnv.keys(core), isEmpty);
    expect(matrixEnv.toolArguments(core), isEmpty);
  });

  test(
      'gives a key of the template of a role with the id of the role, next '
      'to the key of a module', () async {
    final (:apps, :failed) = await matrixOf(const [
      FlutterCoreModule(),
      DartDefineModule(),
      _Shop(),
      _Boards(),
    ]);

    expect(failed, isEmpty);
    final boards = apps.firstWhere(
      (app) =>
          app.modules.contains(_Boards.id) && app.modules.contains(_Shop.id),
    );
    expect(matrixEnv.keys(boards), {
      'SHOP_KEY': const MatrixEnvKeyOwner.module(_Shop.id),
      'SHOP_URL': const MatrixEnvKeyOwner.module(_Shop.id),
      'BOARD_TOKEN': const MatrixEnvKeyOwner.role('board'),
    });
    // A failure of a test names the owner.
    expect('${matrixEnv.keys(boards)['BOARD_TOKEN']}', 'role board');
    expect('${matrixEnv.keys(boards)['SHOP_KEY']}', 'module shop');
  });
}
