@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';

const _icon = Fragment(
  'Icons.home',
  imports: [ImportRef('package:flutter/material.dart')],
);

/// The label of the destination of the route [tab] of a module of the
/// tests: a text named after the route, with its name as its English text,
/// and with a translation into Ukrainian if [translated] is set.
LocalizedText _label(String tab, {bool translated = false}) => LocalizedText(
      '${tab}Label',
      en: tab,
      translations: {if (translated) 'uk': 'uk $tab'},
    );

/// The routes of a feature [module] with a destination per name in [tabs],
/// each labelled with [_label], and a route without one.
RoleData<Object> _feature(
  String module,
  List<String> tabs, {
  bool translated = false,
  Fragment icon = _icon,
}) =>
    dataOf(
      routerRole,
      RoutesData([
        for (final tab in tabs)
          Route(
            '/$tab',
            name: tab,
            screen: ScreenRef(
              '${tab[0].toUpperCase()}${tab.substring(1)}Screen',
              import: ImportRef.app('features/$module/$tab.dart'),
            ),
            destination: Destination(
              label: _label(tab, translated: translated),
              icon: icon,
            ),
          ),
        Route(
          '/plain',
          name: 'plain',
          screen: ScreenRef(
            'PlainScreen',
            import: ImportRef.app('features/$module/plain.dart'),
          ),
        ),
      ]),
      module: module,
    );

/// The texts that the module [module] gives the localization role: the
/// labels of the destinations of its routes [tabs], as [_feature] has them.
RoleData<Object> _labels(String module, List<String> tabs) => dataOf(
      localizationRole,
      TextsData([for (final tab in tabs) _label(tab, translated: true)]),
      module: module,
    );

/// A stand-in for the part of Flutter's widgets library that the file of
/// the destinations uses, with the signatures of Flutter 3.44, and a
/// context that is in a language, as one below the root of an app is.
const _widgets = '''
final class BuildContext {
  const BuildContext(this.language);

  /// The code of the language of the app at the context.
  final String language;
}

final class IconData {
  const IconData(this.codePoint);

  final int codePoint;
}
''';

/// A stand-in for the icons of Flutter's material library.
const _material = '''
import 'widgets.dart';

abstract final class Icons {
  static const IconData home = IconData(1);

  static const IconData inbox = IconData(2);
}
''';

/// The file of the texts of a provider of the localization role, with a
/// getter for each of [getters], which returns the name of the getter after
/// the language of the context.
String _textsFile(List<String> getters) => [
      "import 'package:flutter/widgets.dart';",
      '',
      'final class Texts {',
      '  const Texts(this._language);',
      '',
      '  final String _language;',
      for (final getter in getters) ...[
        '',
        "  String get $getter => '\$_language $getter';",
      ],
      '}',
      '',
      'extension AppTexts on BuildContext {',
      '  Texts get l10n => Texts(language);',
      '}',
      '',
    ].join('\n');

/// A script that sends the destinations of the app: for each, its label in
/// English and in Ukrainian and the code point of its icon.
const _readDestinations = r'''
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:my_app/core/layout/destination.dart';

void main(List<String> arguments, SendPort port) {
  port.send([
    for (final destination in appDestinations)
      [
        destination.label(const BuildContext('en')),
        destination.label(const BuildContext('uk')),
        '${destination.icon.codePoint}',
      ].join(' | '),
  ]);
}
''';

/// The destinations of the app whose file of the destinations is [code],
/// as [_readDestinations] sends them, once the file type-checks against
/// the stand-ins of Flutter and [texts], the file of the texts of the app,
/// if it has one.
Future<Object?> _destinationsOf(String code, {String? texts}) async {
  final files = DartFiles.write(
    {
      LayoutRole.destinationFile: code,
      if (texts != null) LocalizationRole.textsFile: texts,
    },
    flutter: const {'widgets.dart': _widgets, 'material.dart': _material},
  );
  try {
    expect(await files.analysisProblems(), isEmpty, reason: code);
    return await files.run(_readDestinations);
  } finally {
    files.delete();
  }
}

/// The top-level declarations of the Dart [code] by name, each as its
/// source.
Map<String, String> _topLevelOf(String code) => {
      for (final declaration in parseString(content: code).unit.declarations)
        switch (declaration) {
          FunctionDeclaration(:final name) => name.lexeme,
          TopLevelVariableDeclaration(:final variables) =>
            variables.variables.single.name.lexeme,
          ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
          _ => '$declaration',
        }: declaration.toSource(),
    };

/// The URIs of the imports of the Dart [code], in order.
List<String?> _importsOf(String code) => [
      for (final directive in parseString(content: code).unit.directives)
        if (directive is ImportDirective) directive.uri.stringValue,
    ];

final class _AnyLayout extends LayoutProvider {
  const _AnyLayout();
}

final class _Tabs extends LayoutProvider {
  const _Tabs(this.maxDestinations);

  @override
  final int? maxDestinations;
}

void main() {
  test('the layout reads the destinations of the router in order', () {
    final input = inputOf(
      layoutRole,
      data: [
        _feature('home', ['feed', 'inbox']),
        _feature('settings', ['general']),
      ],
      present: {routerRole},
    );

    expect(
      [for (final route in layoutRole.destinationsIn(input)) route.fullPath],
      ['/home/feed', '/home/inbox', '/settings/general'],
    );
  });

  test(
      'the role requires the router, whose destinations it shows, and uses '
      'the localization role, for their labels', () {
    expect(layoutRole.requires, {routerRole});
    expect(layoutRole.uses, {localizationRole});
  });

  test('the app shell takes the destinations and the selected branch', () {
    expect(LayoutRole.appShell.path, LayoutRole.appShellFile);
    expect(LayoutRole.appShell.namedParameters, [
      'destinations',
      'currentIndex',
      'onSelect',
      'body',
    ]);
    // What code that knows only the role reads from the shell; the body is
    // only shown.
    expect(LayoutRole.appShell.getters, [
      'destinations',
      'currentIndex',
      'onSelect',
    ]);
    expect(
      layoutRole.interface.symbols,
      [LayoutRole.destination, LayoutRole.appShell],
    );
  });

  test('code that knows only the role reads the navigation from the shell', () {
    // An AppShell that takes what the router passes, but keeps none of the
    // destinations, the selected index and onSelect where code can read
    // them.
    const shell = IndexedDeclaration(
      name: 'AppShell',
      kind: DeclarationKind.classType,
      constructors: [
        IndexedConstructor(
          isConst: true,
          parameters: [
            IndexedParameter('destinations', kind: ParameterKind.requiredNamed),
            IndexedParameter('currentIndex', kind: ParameterKind.requiredNamed),
            IndexedParameter('onSelect', kind: ParameterKind.requiredNamed),
            IndexedParameter('body', kind: ParameterKind.requiredNamed),
          ],
        ),
      ],
    );

    const prefix = 'class AppShell in lib/core/layout/app_shell.dart must';
    expect(
      [
        for (final issue in LayoutRole.appShell.checkIn({
          LayoutRole.appShellFile: const DartFileIndex(
            path: LayoutRole.appShellFile,
            declarations: [shell],
          ),
        }))
          issue.message,
      ],
      [
        for (final getter in ['destinations', 'currentIndex', 'onSelect'])
          '$prefix declare the public instance field or getter $getter.',
      ],
    );
  });

  group('LayoutProvider', () {
    RoleHookInput<NoDsl> input(int destinations) => inputOf(
          layoutRole,
          data: [
            _feature('home', ['a', 'b']),
            _feature(
              'more',
              [for (var i = 0; i < destinations - 2; i++) 't$i'],
            ),
          ],
          present: {routerRole},
        );

    test('is a provider of the layout role', () {
      expect(const _Tabs(null).role, same(layoutRole));
      expect(const _Tabs(null).maxDestinations, isNull);
    });

    test('accepts any number of destinations without a maximum', () {
      expect(const _AnyLayout().maxDestinations, isNull);
      expect(const _AnyLayout().validate(input(9)), isEmpty);
    });

    test('leaves out destinations that do not come from a module', () {
      final input = inputOf(
        layoutRole,
        data: [
          routerRole
              .data(
                const RoutesData([
                  Route(
                    '/a',
                    name: 'a',
                    screen: ScreenRef(
                      'AScreen',
                      import: ImportRef.app('a.dart'),
                    ),
                    destination: Destination(
                      label: LocalizedText('label', en: 'A'),
                      icon: _icon,
                    ),
                  ),
                ]),
              )
              .withOrigin(const RoleTemplateOrigin(routerRole)),
        ],
        present: {routerRole},
      );

      expect(const _Tabs(0).validate(input), isEmpty);
    });

    test('accepts up to its maximum of destinations', () {
      expect(const _Tabs(5).validate(input(5)), isEmpty);
    });

    test('rejects more destinations and names the first extra one', () {
      final issue = const _Tabs(3).validate(input(4)).single;

      expect(issue.message, contains('can show 3 destinations'));
      expect(issue.message, contains('/more/t1'));
      expect(issue.origin, const ModuleOrigin(ModuleId('more')));
    });
  });

  group('the template', () {
    test('generates the destination class, whose label is a function',
        () async {
      final rendered = await renderTemplate(layoutRole, present: {routerRole});

      expect(rendered.files.keys, [LayoutRole.destinationFile]);
      final code = rendered.files[LayoutRole.destinationFile]!;
      expectParses(code);
      expect(code, contains('final class Destination {'));
      expect(code, contains('final IconData icon;'));
      expect(
        code,
        contains('final String Function(BuildContext context) label;'),
      );
      expect(rendered.elsewhere, isEmpty);
      // As the symbol of the role says, which the contract harness checks in
      // every app with the role.
      expect(
        code,
        contains(
          'const Destination({required this.label, required this.icon});',
        ),
      );
      expect(LayoutRole.destination.path, LayoutRole.destinationFile);
      expect(LayoutRole.destination.namedParameters, ['label', 'icon']);
      expect(LayoutRole.destination.constConstructor, isTrue);
    });

    test(
        'generates the constant list of the destinations of the app, in '
        'their order, each with its icon and a function for its label',
        () async {
      final rendered = await renderTemplate(
        layoutRole,
        data: [
          _feature('home', ['feed', 'inbox']),
          _feature(
            'app_settings',
            ['general'],
            icon: const Fragment(
              'Icons.inbox',
              imports: [
                ImportRef('package:flutter/material.dart', show: ['Icons']),
              ],
            ),
          ),
        ],
        present: {routerRole},
      );
      final code = rendered.files[LayoutRole.destinationFile]!;
      final declarations = _topLevelOf(code);

      expect(declarations.keys, [
        'Destination',
        LayoutRole.appDestinations,
        '_homeFeedLabel',
        '_homeInboxLabel',
        '_appSettingsGeneralLabel',
      ]);
      const items = [
        'Destination(label: _homeFeedLabel, icon: Icons.home)',
        'Destination(label: _homeInboxLabel, icon: Icons.home)',
        'Destination(label: _appSettingsGeneralLabel, icon: Icons.inbox)',
      ];
      expect(
        declarations[LayoutRole.appDestinations],
        'const List<Destination> appDestinations = [${items.join(', ')}];',
      );
      // Without the localization role, each label is its English text.
      expect(
        declarations['_homeFeedLabel'],
        "String _homeFeedLabel(BuildContext context) => 'feed';",
      );
      // The imports of the icons, once each, and no file of texts.
      expect(_importsOf(code), [
        'package:flutter/widgets.dart',
        'package:flutter/material.dart',
      ]);
      expect(
        await _destinationsOf(code),
        ['feed | feed | 1', 'inbox | inbox | 1', 'general | general | 2'],
      );
    });

    test(
        'reads the label of a destination from the texts of the app when '
        'its module gave the localization role the text, and as its English '
        'text otherwise', () async {
      final rendered = await renderTemplate(
        layoutRole,
        data: [
          // Two modules that list the localization role and gave it their
          // labels, one of which both name alike, and a module that does not
          // list it, whose label has no translation.
          _feature('home', ['feed', 'inbox'], translated: true),
          _labels('home', ['feed', 'inbox']),
          _feature('shop', ['feed'], translated: true),
          _labels('shop', ['feed']),
          _feature('plain', ['about']),
        ],
        present: {routerRole, localizationRole},
      );
      final code = rendered.files[LayoutRole.destinationFile]!;
      final declarations = _topLevelOf(code);

      expect(
        declarations['_homeFeedLabel'],
        'String _homeFeedLabel(BuildContext context) => '
        'context.l10n.homeFeedLabel;',
      );
      expect(
        declarations['_homeInboxLabel'],
        'String _homeInboxLabel(BuildContext context) => '
        'context.l10n.homeInboxLabel;',
      );
      // The text of the module of the destination, not the text of that
      // name of another module.
      expect(
        declarations['_shopFeedLabel'],
        'String _shopFeedLabel(BuildContext context) => '
        'context.l10n.shopFeedLabel;',
      );
      expect(
        declarations['_plainAboutLabel'],
        "String _plainAboutLabel(BuildContext context) => 'about';",
      );
      // The file of the texts of the app, once.
      expect(_importsOf(code), [
        'package:flutter/widgets.dart',
        'package:flutter/material.dart',
        'package:my_app/core/l10n/l10n.dart',
      ]);
      // The list is a constant, and the labels follow the language of the
      // context that they are read at.
      expect(
        declarations[LayoutRole.appDestinations],
        startsWith('const List<Destination> appDestinations = ['),
      );
      expect(
        await _destinationsOf(
          code,
          texts: _textsFile([
            'homeFeedLabel',
            'homeInboxLabel',
            'shopFeedLabel',
          ]),
        ),
        [
          'en homeFeedLabel | uk homeFeedLabel | 1',
          'en homeInboxLabel | uk homeInboxLabel | 1',
          'en shopFeedLabel | uk shopFeedLabel | 1',
          'about | about | 1',
        ],
      );
    });

    test(
        'reads no text that the app lacks: the label of a module that gave '
        'the localization role another text is its English text', () async {
      final rendered = await renderTemplate(
        layoutRole,
        data: [
          _feature('home', ['feed', 'inbox'], translated: true),
          // The module gave the role one of its two labels: the rule of the
          // localization role reports the other.
          _labels('home', ['feed']),
        ],
        present: {routerRole, localizationRole},
      );
      final code = rendered.files[LayoutRole.destinationFile]!;

      expect(
        await _destinationsOf(code, texts: _textsFile(['homeFeedLabel'])),
        ['en homeFeedLabel | uk homeFeedLabel | 1', 'inbox | inbox | 1'],
      );
    });

    test('escapes the English text of a label', () async {
      final rendered = await renderTemplate(
        layoutRole,
        data: [
          dataOf(
            routerRole,
            const RoutesData([
              Route(
                '/',
                name: 'cart',
                screen: ScreenRef(
                  'CartScreen',
                  import: ImportRef.app('features/home/cart.dart'),
                ),
                destination: Destination(
                  label: LocalizedText('label', en: r"Today's $5 deals"),
                  icon: _icon,
                ),
              ),
            ]),
          ),
        ],
        present: {routerRole},
      );

      expect(
        await _destinationsOf(rendered.files[LayoutRole.destinationFile]!),
        [r"Today's $5 deals | Today's $5 deals | 1"],
      );
    });

    test('generates an empty list in an app without destinations', () async {
      final rendered = await renderTemplate(
        layoutRole,
        data: [_feature('home', const [])],
        present: {routerRole, localizationRole},
      );
      final code = rendered.files[LayoutRole.destinationFile]!;

      expect(
        _topLevelOf(code).keys,
        ['Destination', LayoutRole.appDestinations],
      );
      expect(_importsOf(code), ['package:flutter/widgets.dart']);
      expect(await _destinationsOf(code), isEmpty);
    });

    test('refuses a label with problems, in every app', () {
      for (final present in <Set<Role>>[
        {routerRole},
        {routerRole, localizationRole},
      ]) {
        expect(
          () => layoutRole.template.render(
            inputOf(
              layoutRole,
              data: [
                dataOf(
                  routerRole,
                  const RoutesData([
                    Route(
                      '/',
                      name: 'a',
                      screen: ScreenRef(
                        'AScreen',
                        import: ImportRef.app('a.dart'),
                      ),
                      destination: Destination(
                        label: LocalizedText('Label', en: 'A'),
                        icon: _icon,
                      ),
                    ),
                  ]),
                ),
              ],
              present: present,
            ),
          ),
          throwsArgumentError,
        );
      }
    });
  });

  test(
      'the note of the template for coding agents names the shell and the '
      'destinations of the role, and the navigation of the router', () async {
    final rendered = await renderTemplate(
      layoutRole,
      data: [
        _feature('home', ['feed']),
      ],
      present: {routerRole},
    );
    final note = agentNoteOf(layoutRole);

    expect(rendered.notes.single.socket, AppEntryRole.agentSections);
    expect(rendered.notes.single.entryKey, 'Layout');
    expect(rendered.notes.single.entryValue, note);
    // The class of a destination with its label, and the list that a new
    // destination goes into.
    expectNamesOfCode(
      note,
      {
        LayoutRole.destinationFile: [
          'Destination',
          'Destination.label',
          LayoutRole.appDestinations,
        ],
      },
      files: rendered.files,
    );
    expect(note.text, contains('`destination.label(context)`'));
    // The navigation of the router role, which the layout requires.
    expectNamesOfCode(
      note,
      {
        RouterRole.navigationFile: [
          'NavLink.go',
          'NavLink.push',
          'NavLink.replace',
        ],
      },
      files: (await renderTemplate(routerRole)).files,
    );
    // Where the router creates the shell is up to its provider: the role
    // guarantees only the function that creates the router in that file.
    expect(note.text, isNot(contains(RouterRole.appRouterFactoryFile)));
    // The shell of the provider, as the role requires it.
    for (final name in [
      LayoutRole.appShell.name,
      ...LayoutRole.appShell.namedParameters,
    ]) {
      expect(note.text, contains('`$name`'), reason: name);
    }
    expect(
      note.text,
      contains(
        'with its `destinations`, `currentIndex`, `onSelect` and `body`,',
      ),
    );
  });
}
