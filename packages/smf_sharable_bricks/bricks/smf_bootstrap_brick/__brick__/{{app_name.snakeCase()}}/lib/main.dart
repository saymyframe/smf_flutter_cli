import 'package:flutter/material.dart';
import 'package:{{app_name.snakeCase()}}/features/home/home_screen.dart';
{{#imports}}
{{{.}}}
{{/imports}}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  {{#bootstrap}}
  {{{.}}}
  {{/bootstrap}}

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomeScreen());
  }
}
