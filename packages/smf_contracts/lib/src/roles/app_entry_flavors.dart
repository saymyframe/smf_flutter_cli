part of 'app_entry.dart';

/// The modes of a build, each of which has an Xcode build configuration for
/// each flavor.
const _xcodeModes = ['Debug', 'Profile', 'Release'];

/// A native flavor of the app, one of [AppEntryRole.flavors].
///
/// The flavors of an app install next to each other on a device, each under
/// an id of its own. The role publishes them, so modules, other roles and
/// tools read their names and ids from here and know nothing of the native
/// projects of the provider.
@immutable
final class AppFlavor {
  const AppFlavor._(this.name, {this.idSuffix = ''});

  /// The name that `--flavor` of the `flutter` tool takes, such as `dev`,
  /// which is also the name of the Xcode scheme of the flavor.
  ///
  /// It has no hyphen, since Flutter splits the name of a build configuration
  /// on it to find the flavor.
  final String name;

  /// What the id of the flavor adds to the id of the app, such as `.dev`,
  /// and empty for the flavor that has the id of the app itself.
  final String idSuffix;

  /// The Android application id of this flavor of the app with [identity].
  String applicationIdIn(AppIdentity identity) =>
      '${identity.androidApplicationId}$idSuffix';

  /// The iOS bundle id of this flavor of the app with [identity].
  String bundleIdIn(AppIdentity identity) => '${identity.iosBundleId}$idSuffix';

  /// The Xcode build configurations of this flavor, one for each mode of a
  /// build, such as `Debug-dev`. Flutter finds the configuration of a build
  /// by this form of the name.
  List<String> get xcodeConfigurations => [
        for (final mode in _xcodeModes) '$mode-$name',
      ];

  /// The path of the shared Xcode scheme of this flavor, which
  /// `flutter build ios --flavor` selects by its name.
  String get xcodeSchemeFile =>
      'ios/Runner.xcodeproj/xcshareddata/xcschemes/$name.xcscheme';
}

/// The flavor for development; see [AppEntryRole.defaultFlavor].
const _devFlavor = AppFlavor._('dev', idSuffix: '.dev');

/// The flavor for testing a build before it reaches the stores.
const _stagingFlavor = AppFlavor._('staging', idSuffix: '.staging');

/// The flavor that users get; see [AppEntryRole.releaseFlavor].
const _prodFlavor = AppFlavor._('prod');

/// The section [AppEntryRole.flavorsHeading] of the README of the app with
/// [identity]: the id of each flavor, what a command without `--flavor`
/// builds, and how a build for a store names its flavor.
String _flavorsSection(AppIdentity identity) {
  const fallback = AppEntryRole.defaultFlavor;
  const release = AppEntryRole.releaseFlavor;
  String rowOf(AppFlavor flavor) => '| `${flavor.name}` '
      '| `${flavor.applicationIdIn(identity)}` '
      '| `${flavor.bundleIdIn(identity)}` |';

  return '''
The app has three flavors, which install next to each other on a device, each under an id of its own:

| Flavor | Android application id | iOS bundle id |
| --- | --- | --- |
${AppEntryRole.flavors.map(rowOf).join('\n')}

A `flutter` command without `--flavor` builds `${fallback.name}`, because `default-flavor` in `pubspec.yaml` says so. That holds in release mode too: `flutter build appbundle` and `flutter build ipa` build a release of `${fallback.name}`, under its id. For a store, name the flavor:

```bash
flutter run --flavor ${_stagingFlavor.name}
flutter build appbundle --flavor ${release.name}
flutter build ipa --flavor ${release.name}
```

Code reads the flavor from `appFlavor` of `package:flutter/services.dart`. A service that knows your app by its id, such as a store or a push provider, knows each flavor as an app of its own, so you repeat a step of its setup for each flavor that needs it.''';
}

/// What a problem of the rule of the flavors says of the flavors of the role.
String get _roleFlavorNames =>
    AppEntryRole.flavors.map((flavor) => flavor.name).join(', ');

List<SmfIssue> _checkFlavors(StructuralRuleInput<NoDsl> input) {
  final gradle = input.texts[AppEntryRole.gradleAppFile];
  final project = input.texts[AppEntryRole.xcodeProjectFile];
  if (gradle == null && project == null) return const [];
  return [
    ..._defaultFlavorIssues(input),
    if (gradle != null) ..._gradleFlavorIssues(input, gradle),
    if (project != null) ...[
      ..._xcodeFlavorIssues(input, project),
      for (final flavor in AppEntryRole.flavors)
        ..._xcodeSchemeIssues(input, flavor),
    ],
  ];
}

/// The problems of the pubspec of the app of [input]: it has to name a flavor
/// of the role as the default one. Which one it names is left to a running
/// app, since only a run of the `flutter` tool shows what a plain command
/// builds.
Iterable<SmfIssue> _defaultFlavorIssues(
  StructuralRuleInput<NoDsl> input,
) sync* {
  const path = 'pubspec.yaml';
  final flavor = _defaultFlavorIn(input.texts[path] ?? '');
  const hint = 'Give the flutter section of the pubspec the default flavor of '
      'the role, with PubspecContribution.flutter(defaultFlavor: '
      'AppEntryRole.defaultFlavor.name).';
  if (flavor == null) {
    yield SmfIssue(
      '$path has no default-flavor in its flutter section, so a command of '
      'the flutter tool without --flavor cannot tell which flavor to build.',
      hint: hint,
      origin: input.owners[path],
      path: path,
    );
  } else if (!AppEntryRole.flavors.any((known) => known.name == flavor)) {
    yield SmfIssue(
      'default-flavor in $path is "$flavor", which is no flavor of the role: '
      '$_roleFlavorNames.',
      hint: hint,
      origin: input.owners[path],
      path: path,
    );
  }
}

/// The value of `default-flavor` among the keys right below the top-level
/// key `flutter` of the pubspec [text], or `null` if it has none.
String? _defaultFlavorIn(String text) {
  final key = RegExp(r'^( +)([\w-]+)\s*:(.*)$');
  final keys = const LineSplitter()
      .convert(text)
      .where((line) => line.trim().isNotEmpty)
      .where((line) => !line.trimLeft().startsWith('#'))
      .skipWhile((line) => !RegExp(r'^flutter\s*:').hasMatch(line))
      .skip(1)
      .takeWhile((line) => line.startsWith(' '))
      .map(key.firstMatch)
      .nonNulls;
  final flavor = keys
      .where((match) => match[1]!.length == keys.first[1]!.length)
      .where((match) => match[2] == 'default-flavor')
      .firstOrNull;
  if (flavor == null) return null;
  return flavor[3]!
      .replaceFirst(RegExp(r'\s#.*$'), '')
      .trim()
      .replaceAll(RegExp(r'''^["']|["']$'''), '');
}

/// The problems of [text], the Gradle build script of the app module of
/// [input]: its product flavors are those of the role, each with a dimension
/// and with the application id of the flavor.
Iterable<SmfIssue> _gradleFlavorIssues(
  StructuralRuleInput<NoDsl> input,
  String text,
) sync* {
  const path = AppEntryRole.gradleAppFile;
  SmfIssue issue(String message, {String? hint}) => SmfIssue(
        message,
        hint: hint,
        origin: input.owners[path],
        path: path,
      );

  final code = text.replaceAll(RegExp(r'/\*.*?\*/|//[^\n]*', dotAll: true), '');
  if (!RegExp(r'\bflavorDimensions\b').hasMatch(code)) {
    yield issue('$path has no flavorDimensions, which product flavors need.');
  }
  final open = RegExp(r'\bproductFlavors\s*\{').firstMatch(code);
  final close = open == null ? 0 : _closingBrace(code, open.end - 1);
  final blocks = open == null ? '' : code.substring(open.end, close);
  final outside =
      open == null ? code : code.replaceRange(open.start, close, '');
  final blocksByName = <String, String>{
    for (final block
        in RegExp(r'\bcreate\s*\(\s*"([^"]*)"\s*\)\s*\{').allMatches(blocks))
      block[1]!:
          blocks.substring(block.end, _closingBrace(blocks, block.end - 1)),
  };

  final applicationId = RegExp(r'\bapplicationId\s*=\s*"([^"]*)"');
  final idOfApp = applicationId.firstMatch(outside)?[1] ?? '';
  final identity = input.roleInput.context.appIdentity;
  for (final flavor in AppEntryRole.flavors) {
    final block = blocksByName[flavor.name];
    if (block == null) {
      yield issue(
        '$path has no flavor ${flavor.name} in productFlavors.',
        hint: 'Each flavor of AppEntryRole.flavors is a '
            'create("${flavor.name}") block of productFlavors, with a '
            'dimension and the applicationIdSuffix of the flavor.',
      );
      continue;
    }
    if (!RegExp(r'\bdimension\s*=').hasMatch(block)) {
      yield issue('The flavor ${flavor.name} in $path has no dimension.');
    }
    final suffix =
        RegExp(r'\bapplicationIdSuffix\s*=\s*"([^"]*)"').firstMatch(block)?[1];
    final id =
        '${applicationId.firstMatch(block)?[1] ?? idOfApp}${suffix ?? ''}';
    final expected = flavor.applicationIdIn(identity);
    if (id != expected) {
      yield issue(
        'The flavor ${flavor.name} in $path builds the application id $id, '
        'but the id of the flavor is $expected.',
        hint: 'applicationId in defaultConfig is the id of the app, and '
            'applicationIdSuffix of a flavor is its AppFlavor.idSuffix, none '
            'for a flavor with an empty one.',
      );
    }
  }
  for (final name in blocksByName.keys) {
    if (!AppEntryRole.flavors.any((flavor) => flavor.name == name)) {
      yield issue(
        '$path has the flavor $name in productFlavors, which is no flavor of '
        'the role: $_roleFlavorNames.',
      );
    }
  }
}

/// The setting `PRODUCT_BUNDLE_IDENTIFIER` of build settings, with its value.
final _bundleIdSetting = RegExp(
  r'(?:^|(?<=;))\s*"?PRODUCT_BUNDLE_IDENTIFIER"?\s*=\s*"?([^";]*)"?\s*;',
  multiLine: true,
);

/// The problems of [text], the Xcode project of the app of [input]: every
/// configuration list has the build configurations of the flavors, under
/// the name in its object, and those of the app target have the id of their
/// flavor and a base, the same for the flavors of a mode.
Iterable<SmfIssue> _xcodeFlavorIssues(
  StructuralRuleInput<NoDsl> input,
  String text,
) sync* {
  SmfIssue issue(String message, {String? hint}) => SmfIssue(
        message,
        hint: hint,
        origin: input.owners[AppEntryRole.xcodeProjectFile],
        path: AppEntryRole.xcodeProjectFile,
      );

  final objects = _projectObjects(_withoutProjectComments(text));
  final configurations = {
    for (final object in objects)
      if (object.isa == 'XCBuildConfiguration') object.id: object,
  };
  yield* _xcodeListIssues(objects, configurations, issue);

  final ofProject = _projectConfigurations(objects);
  final ofApp = {
    for (final object in configurations.values)
      if (_signingConfigurationOf(
        object,
        ofProject: ofProject.contains(object.id),
      ).ofApp)
        _buildConfiguration(object.body).name: object,
  };
  yield* _xcodeAppIssues(ofApp, input.roleInput.context.appIdentity, issue);
  yield* _xcodeBaseIssues(ofApp, issue);
}

/// The problems of the configuration lists among [objects], whose build
/// configurations are in [configurations]: each has those of every flavor,
/// reported through [issue].
Iterable<SmfIssue> _xcodeListIssues(
  List<_ProjectObject> objects,
  Map<String, _ProjectObject> configurations,
  SmfIssue Function(String message, {String? hint}) issue,
) sync* {
  for (final list in objects.where((o) => o.isa == 'XCConfigurationList')) {
    final names = {
      for (final id in _configurationsIn(list.id, objects))
        if (configurations[id] case final configuration?)
          _buildConfiguration(configuration.body).name,
    };
    final expected = AppEntryRole.flavors.expand(
      (flavor) => flavor.xcodeConfigurations,
    );
    for (final name in expected.where((name) => !names.contains(name))) {
      yield issue(
        'The build configuration list ${list.id} in '
        '${AppEntryRole.xcodeProjectFile} lacks $name.',
        hint: 'Flutter builds a flavor with the configuration of that name, '
            'which the project and each target have to have.',
      );
    }
  }
}

/// The problems of [ofApp], the build configurations of the app target by
/// their names, for the app with [identity]: each flavor has its own, with
/// the id of the flavor and a base, reported through [issue].
Iterable<SmfIssue> _xcodeAppIssues(
  Map<String?, _ProjectObject> ofApp,
  AppIdentity identity,
  SmfIssue Function(String message, {String? hint}) issue,
) sync* {
  const path = AppEntryRole.xcodeProjectFile;
  final infoPlist = _inIosProject(AppEntryRole.infoPlistFile);
  for (final flavor in AppEntryRole.flavors) {
    final expected = flavor.bundleIdIn(identity);
    for (final name in flavor.xcodeConfigurations) {
      final object = ofApp[name];
      if (object == null) {
        yield issue(
          '$path has no build configuration $name of the app target, with '
          'INFOPLIST_FILE = $infoPlist.',
        );
        continue;
      }
      final settings = _buildConfiguration(object.body).settings;
      final id = _bundleIdSetting.firstMatch(settings)?[1]!.trim() ?? '';
      if (id != expected) {
        yield issue(
          'The build configuration $name of the app target in $path has the '
          'bundle id "$id", but the id of the flavor is $expected.',
        );
      }
      if (_baseOf(object) == null) {
        yield issue(
          'The build configuration $name of the app target in $path has no '
          'baseConfigurationReference, so it reads no '
          'ios/Flutter/Generated.xcconfig.',
        );
      }
    }
  }
}

/// The problems of the bases of [ofApp], the build configurations of the app
/// target by their names: the flavors of a mode share one, reported through
/// [issue].
Iterable<SmfIssue> _xcodeBaseIssues(
  Map<String?, _ProjectObject> ofApp,
  SmfIssue Function(String message, {String? hint}) issue,
) sync* {
  for (final mode in _xcodeModes) {
    final names = [
      for (final flavor in AppEntryRole.flavors) '$mode-${flavor.name}',
    ];
    final bases = {
      for (final name in names)
        if (ofApp[name] case final object?)
          if (_baseOf(object) case final base?) base,
    };
    if (bases.length > 1) {
      yield issue(
        'The build configurations ${names.join(', ')} of the app target in '
        '${AppEntryRole.xcodeProjectFile} do not share one '
        'baseConfigurationReference.',
      );
    }
  }
}

/// The base of the build configuration [object], the id of the file of
/// settings that it reads, if any.
String? _baseOf(_ProjectObject object) =>
    RegExp(r'\bbaseConfigurationReference\s*=\s*(\w+)\s*;')
        .firstMatch(object.body)?[1];

/// The mode of the build configuration that each action of a scheme takes.
const _schemeActionModes = {
  'TestAction': 'Debug',
  'LaunchAction': 'Debug',
  'ProfileAction': 'Profile',
  'AnalyzeAction': 'Debug',
  'ArchiveAction': 'Release',
};

/// The problems of the Xcode scheme of [flavor] in the app of [input]: it
/// exists, its actions take the build configurations of the flavor, and its
/// build has the pre-action of Flutter's template.
Iterable<SmfIssue> _xcodeSchemeIssues(
  StructuralRuleInput<NoDsl> input,
  AppFlavor flavor,
) sync* {
  final path = flavor.xcodeSchemeFile;
  final text = input.texts[path];
  if (text == null) {
    yield SmfIssue(
      '$path is missing: a build of the flavor ${flavor.name} selects the '
      'scheme of the flavor by its name.',
      origin: input.owners[AppEntryRole.xcodeProjectFile],
      path: path,
    );
    return;
  }
  final origin = input.owners[path];
  final xml = _withoutXmlComments(text);
  final tags = _xmlTags.allMatches(xml).toList();
  for (final MapEntry(key: action, value: mode) in _schemeActionModes.entries) {
    final expected = '$mode-${flavor.name}';
    final found = _xmlAttribute(
      tags.where((tag) => tag[1] != '/' && tag[2] == action).firstOrNull?[3] ??
          '',
      'buildConfiguration',
    );
    if (found != expected) {
      yield SmfIssue(
        '$action of $path takes the build configuration "${found ?? ''}", but '
        'this flavor builds $expected there.',
        origin: origin,
        path: path,
      );
    }
  }
  if (!_preparesFlutter(xml)) {
    yield SmfIssue(
      'BuildAction of $path has no pre-action that runs xcode_backend.sh '
      'prepare.',
      hint: "Copy the PreActions of the scheme of Flutter's template. Without "
          'them, Flutter rewrites the scheme on the first build, for Swift '
          'Package Manager.',
      origin: origin,
      path: path,
    );
  }
}

/// Whether the build of the Xcode scheme [xml], which has no comments, runs
/// the step `prepare` of Flutter's script before it starts.
bool _preparesFlutter(String xml) {
  final build = RegExp(r'<BuildAction\b.*?</BuildAction>', dotAll: true)
          .stringMatch(xml) ??
      '';
  final preActions = RegExp(r'<PreActions\b.*?</PreActions>', dotAll: true)
          .stringMatch(build) ??
      '';
  return _xmlTags.allMatches(preActions).any(
        (tag) => RegExp(r'xcode_backend\.sh"?\s+prepare\b').hasMatch(
          _unescapeXml(_xmlAttribute(tag[3]!, 'scriptText') ?? ''),
        ),
      );
}

/// A build setting `IPHONEOS_DEPLOYMENT_TARGET`, with its value.
final _deploymentTargetSetting = RegExp(
  r'(?:^|(?<=;))\s*"?IPHONEOS_DEPLOYMENT_TARGET"?\s*=\s*"?([^";]*)"?\s*;',
  multiLine: true,
);

/// The problems of the template of the Xcode project of a module: a literal
/// version renders right until a module raises the minimum iOS version, so
/// that only the template shows it. Each build configuration of the project
/// has the tag of [AppEntryRole.iosDeploymentTarget], and one of a target has
/// that tag or leaves the version to the project.
List<SmfIssue> _checkIosDeploymentTargetTag(ModuleRuleInput<NoDsl> input) {
  const path = AppEntryRole.xcodeProjectFile;
  final tag = '{{{${AppEntryRole.iosDeploymentTarget.tag}}}}';
  final template = _templatesOf(input.contributions)[path] ?? '';
  final objects = _projectObjects(_withoutProjectComments(template));
  final ofProject = _projectConfigurations(objects);
  final origin = ModuleOrigin(input.module.id);
  const hint = 'A target inherits the version from the build configurations of '
      'the project, which the tag fills.';
  return [
    for (final object in objects)
      if (object.isa == 'XCBuildConfiguration')
        for (final message in _deploymentTargetProblems(
          object,
          tag: tag,
          ofProject: ofProject.contains(object.id),
        ))
          SmfIssue(message, hint: hint, origin: origin, path: path),
  ];
}

/// What is wrong with the minimum iOS version of the build configuration
/// [object] of a template, one of the project itself if [ofProject].
Iterable<String> _deploymentTargetProblems(
  _ProjectObject object, {
  required String tag,
  required bool ofProject,
}) sync* {
  const path = AppEntryRole.xcodeProjectFile;
  const lost = 'so the version that a module raises does not reach it';
  final (:settings, :name) = _buildConfiguration(object.body);
  final named = 'The build configuration $name (${object.id}) in $path';
  final values = _deploymentTargetSetting.allMatches(settings);
  if (ofProject && values.isEmpty) {
    yield '$named has no IPHONEOS_DEPLOYMENT_TARGET, though the targets '
        'inherit it from there, $lost.';
  }
  for (final value in values) {
    if (value[1]!.trim() != tag) {
      yield '$named has IPHONEOS_DEPLOYMENT_TARGET = ${value[1]!.trim()} '
          'instead of the tag $tag, $lost.';
    }
  }
}
