// How the apps of the matrices of SMF get the values of their .env
// (matrixEnv), in apps whose modules give the env role keys, which no
// module of the CLI does yet.
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
      'SHOP_KEY': _Shop.id,
      'SHOP_URL': _Shop.id,
    });
    expect(matrixEnv.toolArguments(shop), [
      '--dart-define-from-file=${EnvRole.dotEnvFile}',
    ]);
    final core = apps.singleWhere((app) => app.name == 'flutter_core');
    expect(matrixEnv.keys(core), isEmpty);
    expect(matrixEnv.toolArguments(core), isEmpty);
  });
}
