# smf_get_it

The SMF module of dependency injection with [get_it](https://pub.dev/packages/get_it). It provides the DI role of the SMF module model: the other modules of the app declare the services they generate, and this module registers them in get_it.

It adds `get_it` to the dependencies of the app and generates `lib/core/di/dependencies.dart`:

- `createServiceLocator()`, whose `resolve` and `resolveWith` find the services in the global instance of get_it, `GetIt.instance`;
- `registerDependencies()`, which the app runs before its first frame, and which registers the services in the form of get_it for what each needs:

| A module declares | `registerDependencies()` calls |
|---|---|
| a singleton | `registerSingleton` |
| a singleton that waits for services created asynchronously, or waiting themselves | `registerSingletonWithDependencies` with `dependsOn` |
| a singleton created asynchronously | `registerSingletonAsync`, with `dependsOn` if it waits |
| a lazy singleton | `registerLazySingleton` |
| a factory | `registerFactory` |
| a factory that takes one or two parameters | `registerFactoryParam`, with `void` for a second parameter it does not take |
| a name for one of several services of a type | `instanceName`, and `InitDependency` to wait for it |
| a function that disposes of a service | `dispose` |

The factory function of each service gets the services it declares from get_it, then the parameters of the call. get_it creates a singleton while it registers it, so every service is registered after the services it takes or waits for, and a singleton waits for the services it takes that are created asynchronously or wait themselves, directly or through lazy singletons and factories, without declaring it. When some services are created asynchronously, `registerDependencies()` completes once all of them are ready.

`GetIt.instance.reset()`, as tests may call it, disposes of the services that were created, in the reverse order of their registration, so each goes before the services it takes.

The code that creates what the screens of a feature need, such as a Cubit, takes its services with `resolve` of `lib/core/di/service_locator.dart` in the composition file of the feature. Everything else gets its services as parameters of its factory function.

## Use with SMF CLI

`smf create` asks which module provides dependency injection, and offers none as well. To choose this one without the question, name it with `-m`:

```bash
smf create my_app -m get_it
```

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_get_it) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
