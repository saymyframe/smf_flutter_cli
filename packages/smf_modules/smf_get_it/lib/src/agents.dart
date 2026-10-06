import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the dependency injection: how its file registers a service.
final String agentNote = '''
With `get_it`:

- `${DiRole.registerDependencies.name}()` registers the services in `getIt`, a local name for `GetIt.instance`, with `registerLazySingleton`, `registerSingleton` or `registerFactory`. The function that creates a service gets each service it takes as `getIt<Type>()`, and one that disposes of it goes into `dispose:`.
- A singleton created asynchronously takes `registerSingletonAsync`, and one that waits for such a service `registerSingletonWithDependencies`. `await getIt.allReady()` then ends the function.
- No other file in `lib/` imports `get_it`. A test may import it to register its fakes in `GetIt.instance`.
''';
