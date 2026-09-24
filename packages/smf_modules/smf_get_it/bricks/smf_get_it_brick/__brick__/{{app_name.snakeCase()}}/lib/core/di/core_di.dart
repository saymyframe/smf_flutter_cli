import 'package:{{app_name.snakeCase()}}/core/typedef.dart';
{{=<% %>=}}
{{#imports}}
{{{.}}}
{{/imports}}
<%={{ }}=%>

void setUpCoreDI() {
  {{=<% %>=}}
  {{#di}}
  {{{.}}}
  {{/di}}
  <%={{ }}=%>
}
