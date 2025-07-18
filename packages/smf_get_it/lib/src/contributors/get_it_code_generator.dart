import 'package:smf_contracts/smf_contracts.dart';

class GetItCodeGenerator implements DiCodeGenerator {
  const GetItCodeGenerator();

  @override
  String generate(DiDependency dependency) {
    final binding = switch (dependency.bindingType) {
      DiBindingType.singleton => 'registerLazySingleton',
      DiBindingType.factory => 'registerFactory',
    };

    return 'getIt.$binding<${dependency.abstractType}>'
        '(() => ${dependency.implementation});';
  }
}
