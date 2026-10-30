part of '../env.dart';

/// What the guide for coding agents of the app says of the run configurations
/// of the template.
final String _runConfigurationsNote = '''
- `${EnvRole.vscodeLaunchFile}` and `.run/<flavor>.run.xml` are the run configurations of VS Code and Android Studio, one for each flavor. Each passes the flavor and the arguments that the values need. In VS Code, F5 starts the selected configuration, while the links above `main()` and above a test and the Testing view always use `${AppEntryRole.defaultFlavor.name}`, whose configuration alone has `templateFor`. In Android Studio, a test gets none of these arguments.
''';

/// What the section of the role in the README of the app says of the run
/// configurations of the template.
final String _runConfigurationsReadme = '''
The app has a run configuration for each flavor, which passes the flavor and the arguments that the values need:

- In VS Code, `${EnvRole.vscodeLaunchFile}` has them. Run and Debug (F5) starts the one that you select in the Run and Debug view. The Run and Debug links above `main()` and above a test, and the Testing view, always use the configuration of `${AppEntryRole.defaultFlavor.name}`, since it alone is the template of those launches (`templateFor`).
- In Android Studio, `.run/<flavor>.run.xml` has the one of each flavor. A test that you run there gets none of these arguments.
''';

/// The run configurations of the IDEs of an app named [appName], by their
/// paths: one for each flavor of the app, each with the flavor and then
/// [toolArguments], the arguments of the provider of the role.
Map<String, String> _runConfigurationsOf(
  String appName,
  List<String> toolArguments,
) {
  List<String> argumentsOf(AppFlavor flavor) =>
      ['--flavor', flavor.name, ...toolArguments];
  return {
    EnvRole.vscodeLaunchFile: _vscodeLaunch(appName, argumentsOf),
    for (final flavor in AppEntryRole.flavors)
      EnvRole.androidStudioRunFileOf(flavor):
          _androidStudioRun('$appName ${flavor.name}', argumentsOf(flavor)),
  };
}

/// The text of [EnvRole.vscodeLaunchFile].
///
/// Dart-Code takes the first configuration with `templateFor` that holds for
/// a file as the template of every launch of that file that names no
/// configuration, with the file in place of `program`: a link above `main()`
/// or above a test, and the Testing view. An empty `templateFor` holds for
/// every file of the app. Only the configuration of the default flavor has it,
/// so those launches run the flavor of a command without `--flavor`, whichever
/// configuration the developer selected for F5. The default flavor comes
/// first, as VS Code selects the first configuration until the developer
/// selects another.
String _vscodeLaunch(
  String appName,
  List<String> Function(AppFlavor flavor) argumentsOf,
) {
  final launch = {
    'version': '0.2.0',
    'configurations': [
      for (final flavor in AppEntryRole.flavors)
        {
          'name': '$appName ${flavor.name}',
          'request': 'launch',
          'type': 'dart',
          'program': AppEntryRole.mainFile,
          'toolArgs': argumentsOf(flavor),
          if (flavor == AppEntryRole.defaultFlavor) 'templateFor': '',
        },
    ],
  };
  return '${const JsonEncoder.withIndent('  ').convert(launch)}\n';
}

/// The text of [EnvRole.androidStudioRunFileOf] for the configuration [name]
/// with [arguments].
///
/// The option `additionalArgs` holds one text, which the Flutter plugin
/// splits into arguments at its spaces.
String _androidStudioRun(String name, List<String> arguments) => '''
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="${_xmlAttribute(name)}" type="FlutterRunConfigurationType" factoryName="Flutter">
    <option name="additionalArgs" value="${_xmlAttribute(arguments.map(_quotedArgument).join(' '))}" />
    <option name="filePath" value="\$PROJECT_DIR\$/${AppEntryRole.mainFile}" />
    <method v="2" />
  </configuration>
</component>
''';

/// [argument] as one argument of the option `additionalArgs`: in double
/// quotes, with a backslash before each of its own, when it has a space or a
/// quote.
String _quotedArgument(String argument) => argument.contains(RegExp(r'[\s"]'))
    ? '"${argument.replaceAll('"', r'\"')}"'
    : argument;

/// [text] as the value of an attribute of XML in double quotes.
String _xmlAttribute(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('"', '&quot;');
