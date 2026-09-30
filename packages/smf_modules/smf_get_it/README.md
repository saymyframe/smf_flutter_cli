# smf_get_it

The SMF module of dependency injection with [get_it](https://pub.dev/packages/get_it) 9. It provides the dependency injection role of SMF: the other modules of the app declare the services they generate, and this module registers them in get_it.

It adds `get_it` to the app and generates `registerDependencies()`, which the app runs before its first frame, in the form of get_it for what each service needs: singletons, lazy singletons, factories, services created asynchronously, and the services each waits for. The code that creates what the screens of a feature need takes its services with `resolve` in the composition file of the feature.

## Use with the SMF CLI

`smf create` asks which module provides dependency injection, and offers none as well. When a module you chose needs dependency injection, `smf create` adds this one by itself if it is the only module that provides it, and asks otherwise. To choose it without the question:

```bash
smf create my_app -m get_it
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The get_it module](https://doc.saymyframe.com/modules/get-it)
- [Services and state](https://doc.saymyframe.com/guides/services)
