# Generate a Flutter app with a REST client on dio

`dio` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that sends the requests of the REST client of the app. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m dio --no-input
```

The module adds dio to the `pubspec.yaml` of the app, and `lib/core/rest/dio_rest_transport.dart`, which sends each request over a `Dio`. The rest of the app uses the client of the REST role, `appRest` in `lib/core/rest/app_rest.dart`:

```dart
final class Note {
  const Note(this.text);

  factory Note.fromJson(Map<String, dynamic> json) =>
      Note(json['text'] as String);

  final String text;
}

Future<Note> firstNote() async {
  final response = await appRest.get('notes/1');
  return response.decoded(Note.fromJson);
}
```

The path joins `REST_BASE_URL` in `.env`, the address of your API. A call fails only with a `RestFailure`, so the state of a screen shows a text of the app for its `reason`.

In an app with a provider of sign-in, each request to that address carries the token of the user, and a 401 gets a new token once and repeats once.

The documentation has more on [the dio module](https://doc.saymyframe.com/modules/dio).
