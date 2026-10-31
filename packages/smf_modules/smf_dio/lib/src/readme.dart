import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'dio';

/// The path in the app of the file with the transport of the module.
const transportFile = 'lib/core/rest/dio_rest_transport.dart';

/// The section of the module in the README of the app, next to the section of
/// the REST role: where the `Dio` of the app is created, what an interceptor
/// may do, and what another adapter needs.
const readmeSection = '''
`$transportFile` sends the requests of `appRest` with [dio](https://pub.dev/packages/dio), as the section "${RestRole.readmeHeading}" tells. `createDio()` in that file creates the `Dio` of the app, which keeps its connections open between requests. An interceptor goes there, such as one of a tracing service:

```dart
Dio createDio() => Dio()..interceptors.add(TracingInterceptor());
```

An interceptor that logs leaves out the header `authorization` and the query of the address, where a token or a key may be. None repeats a request or follows a redirect: `appRest` does both, since it knows which header may go where.

Dio sends over `dart:io`, which reaches an `http://` address with no key in the Android manifest or in `Info.plist`. Another adapter, such as one of [native_dio_adapter](https://pub.dev/packages/native_dio_adapter) for the stack of the platform, goes into `httpClientAdapter` in `createDio()`. It then needs those keys for an `http://` address.
''';
