# smf_dio

The SMF module of REST requests with [dio](https://pub.dev/packages/dio). It provides the REST role of SMF: the code of the app calls `appRest.get('notes')` without knowing the package behind it.

The role generates the client, and this module sends its requests over a `Dio`. What holds with this provider, as with any other:

- A path joins the address of the API, `REST_BASE_URL` in `.env`. While that is empty, a relative path fails with `notConfigured` and names the key, and the app still builds and starts.
- A call fails only with a `RestFailure`, whose reason comes from a closed set.
- In an app with sign-in, the token of the user goes only to the origin of that address, also after a redirect.
- A 401 gets a new token once and repeats once, and requests at the same time share one refresh.
- `GET` and `HEAD` repeat after a broken connection and after 429, 502, 503 and 504, keeping to `Retry-After`. Other methods never repeat.
- A timeout covers a whole attempt and a cancel ends a call at once, and each closes the connection.
- A debug build logs the origin and the path of each attempt, and no token and no query.
- A release build for Android has the `INTERNET` permission.

`createDio()` in the app is where an interceptor goes, such as one of a tracing service.

## Use with the SMF CLI

```bash
smf create my_app -m dio
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The dio module](https://doc.saymyframe.com/modules/dio)
