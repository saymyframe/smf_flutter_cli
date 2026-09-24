import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/get_it_code_generator.dart';
import 'package:test/test.dart';

import '../../helpers/dart_code.dart';

void main() {
  group('GetItCodeGenerator', () {
    const generator = GetItCodeGenerator();

    test('registers a singleton lazily under its abstract type', () {
      expect(
        generator.generate(
          const DiDependency(
            abstractType: 'IAnalyticsService',
            implementation:
                'FirebaseAnalyticsService(FirebaseAnalytics.instance)',
            bindingType: DiBindingType.singleton,
          ),
        ),
        'getIt.registerLazySingleton<IAnalyticsService>'
        '(() => FirebaseAnalyticsService(FirebaseAnalytics.instance));',
      );
    });

    test('registers a factory under its abstract type', () {
      expect(
        generator.generate(
          const DiDependency(
            abstractType: 'IValidator',
            implementation: 'EmailValidator()',
            bindingType: DiBindingType.factory,
          ),
        ),
        'getIt.registerFactory<IValidator>(() => EmailValidator());',
      );
    });

    test('keeps dependency lookups inside the closure so they resolve lazily',
        () {
      final code = generator.generate(
        const DiDependency(
          abstractType: 'IAuthRepository',
          implementation: 'AuthRepository(getIt<IApiClient>(), getIt())',
          bindingType: DiBindingType.singleton,
        ),
      );

      expect(
        code,
        endsWith('(() => AuthRepository(getIt<IApiClient>(), getIt()));'),
      );
    });

    test('generates registrations that compile against the get_it API',
        () async {
      final registrations = [
        const DiDependency(
          abstractType: 'IApiClient',
          implementation: 'ApiClient()',
          bindingType: DiBindingType.singleton,
        ),
        const DiDependency(
          abstractType: 'ISession',
          implementation: 'Session()',
          bindingType: DiBindingType.factory,
        ),
        const DiDependency(
          abstractType: 'IAuthRepository',
          implementation: 'AuthRepository(getIt<IApiClient>(), getIt())',
          bindingType: DiBindingType.singleton,
        ),
      ].map(generator.generate).join('\n');

      expect(
        await compileErrors('''
$getItStubs
abstract class IApiClient {}
class ApiClient implements IApiClient {}
abstract class ISession {}
class Session implements ISession {}
abstract class IAuthRepository {}
class AuthRepository implements IAuthRepository {
  AuthRepository(IApiClient client, ISession session);
}

void setUpCoreDI() {
$registrations
}
'''),
        isEmpty,
      );
    });
  });
}
