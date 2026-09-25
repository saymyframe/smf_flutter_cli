import 'package:flutter/material.dart';

{{#has_router}}
import 'core/router/app_router.dart';
{{/has_router}}
{{^has_router}}
import 'core/app/fallback_start_screen.dart';
{{/has_router}}

/// The root widget of the app.
class App extends StatelessWidget {
  /// Creates the app.
  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp{{#has_router}}.router{{/has_router}}(
{{{smf_app_entry__app_args}}}
        builder: (context, child) =>
            {{{smf_app_entry__app_builder_open}}}child!{{{smf_app_entry__app_builder_close}}},
{{#has_router}}
        routerConfig: appRouter.config,
{{/has_router}}
{{^has_router}}
        home: const FallbackStartScreen(),
{{/has_router}}
      );
}
