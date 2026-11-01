/// The note of the module in the guide for coding agents of the app, in the
/// section of the REST role: where the transport is, and what an interceptor
/// may do.
const agentNote = '''
With `dio`:

- `DioRestTransport` in `lib/core/rest/dio_rest_transport.dart` implements `RestTransport` on `Dio`. In `lib/`, only that file imports the package: other code makes requests through `appRest`.
- `createDio()` in that file creates the `Dio` of the app, and an interceptor goes there. One that logs leaves out the header `authorization` and the query of the address, and none repeats a request or follows a redirect, which `appRest` does.
- What `createDio()` adds to a request goes to every address, also after a redirect and to a full address such as a presigned upload. A credential goes through the token of the session or `headers:` of the call.
''';
