// The probe of the DI role, whichever module provides it, which the start
// check runs on a device once the first screen of the app settled, and
// whose check the test of the role runs too (di_role_test.dart): each
// service that the modules of the app register resolves, a singleton and a
// lazy singleton to one instance.
//
// It calls nothing of the services, and leaves the container as it is,
// since the app goes on using it. The matrix writes registered_services.dart
// next to it, with the services of the app from the data of its DI role.
import 'registered_services.dart';

/// The probe of the start check: the problems of [problemsOfResolving]. It
/// waits for no screen, so it leaves [settle] out.
Future<List<String>> probeServices(Future<void> Function() settle) async =>
    problemsOfResolving();

/// What is wrong with the services of the app: each that does not resolve,
/// with the first line of its error, and each singleton or lazy singleton
/// that resolves to another instance the second time. A factory creates
/// the service again for each resolve, but may return the same instance,
/// such as a constant.
List<String> problemsOfResolving() {
  final problems = <String>[];
  for (final service in registeredServices) {
    final Object instance;
    try {
      instance = service.resolve();
    } on Object catch (error) {
      final message = '$error'.trim().split('\n').first.trim();
      problems.add('${service.name} does not resolve: $message');
      continue;
    }
    if (service.lifetime != 'factory' &&
        !identical(service.resolve(), instance)) {
      problems.add(
        '${service.name}, a ${service.lifetime}, resolves to another '
        'instance the second time.',
      );
    }
  }
  return problems;
}
