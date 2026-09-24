import 'package:smf_contracts/smf_contracts.dart';

/// Writes a get_it registration for a [DiDependency], such as
/// `getIt.registerLazySingleton<IApi>(() => Api());`.
///
/// Singletons are registered lazily, factories with `registerFactory`.
class GetItCodeGenerator implements DiCodeGenerator {
  /// Creates a get_it code generator.
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
