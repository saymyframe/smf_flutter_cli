# smf_contribution_engine

Patches existing Dart files: adds imports and statements, inserts list elements, replaces widgets and edits their arguments. Each change is a `Contribution` that finds its target in the parsed file. `PatchEngine` applies contributions to a project and renders the Mustache placeholders in the text they insert with the values it is given, where a suffix picks a case, as `{{app_name_sc}}` does for `app_name` in snake_case. It never renders the code that is already in the files.

The modules of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) do not use it: they put their code into the sockets of roles, which the generation pipeline fills when it renders an app.
