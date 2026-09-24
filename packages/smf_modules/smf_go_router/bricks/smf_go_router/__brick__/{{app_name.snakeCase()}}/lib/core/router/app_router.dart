import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:{{app_name.snakeCase()}}/core/router/app_routes.dart';
{{=<% %>=}}
{{#imports}}
{{{.}}}
{{/imports}}
<%={{ }}=%>

final router =
{{=<% %>=}}
{{#router}}
{{{.}}}
{{/router}}
<%={{ }}=%>
