import 'package:smf_contracts/smf_contracts.dart';

/// Turns a [DiDependency] into a registration statement for one DI library.
///
/// DI modules implement it to translate the library-independent DI DSL into
/// code for their container; for get_it, a singleton becomes
/// `getIt.registerLazySingleton<IService>(() => Service());`.
// ignore: one_member_abstracts, modules implement this interface.
abstract interface class DiCodeGenerator {
  /// Returns the Dart statement that registers [dependency].
  String generate(DiDependency dependency);
}
