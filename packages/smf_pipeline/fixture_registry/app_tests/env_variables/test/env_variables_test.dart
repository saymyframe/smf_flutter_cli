// A test that continuous integration runs in the apps with every fixture
// module, which have the module that reads values of .env (fake_env_user)
// and a provider of the env role: the module reads the value of each of its
// keys through the variable of the key, which in an app with the role is
// the getter of AppEnv of that key, whichever module provides the role.
//
// Its tests give the keys of the module values in .env, as the tests of a
// module give values for its keys (MatrixAppTest.envValues): the first a
// value in double quotes, since it has white space and a #, the second an
// empty one, and the third none, so that the matrix removes its line, as of
// a key that .env lacks. The test of the env role, which only reads, checks
// against .env what AppEnv returns for each of them.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/fixture_values/fixture_values.dart';

void main() {
  test(
      'the module reads each of its values from AppEnv, under the getter of '
      'its key', () {
    expect(
      [FixtureValues.first, FixtureValues.second, FixtureValues.third],
      [
        AppEnv.fakeEnvUserFirst,
        AppEnv.fakeEnvUserSecond,
        AppEnv.fakeEnvUserThird
      ],
      reason: 'The variable of each key of the module reads the getter of '
          'AppEnv of that key.',
    );
    // The value that its tests give the first key reaches the module.
    expect(FixtureValues.first, isNotNull);
  });
}
