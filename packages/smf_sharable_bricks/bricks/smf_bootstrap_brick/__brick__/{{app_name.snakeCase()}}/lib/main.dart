import 'package:flutter/material.dart';
{{#imports}}
{{{.}}}
{{/imports}}

void main() {
  {{#bootstrap}}
  {{{.}}}
  {{/bootstrap}}

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
