# Example

Activate the CLI, then generate an app with a start screen, tabs at the bottom, get_it and BLoC:

```bash
dart pub global activate smf_flutter_cli
smf create my_app --org com.example -m home,bottom_tabs,get_it,bloc --no-input
cd my_app
flutter run
```

Without `-m` and `--no-input`, `smf create` asks for the modules in the terminal. `smf create --help` lists the options.
