import 'package:smf_contracts/src/routing/guard/binding/binding.dart';

class AutoRouteGuard extends GuardImplementation {
  AutoRouteGuard({required this.className, required super.code, super.imports});

  final String className;
}
