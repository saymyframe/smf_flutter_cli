@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:fake_infra/fake_infra.dart';
import 'package:fake_router/fake_router.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:test/test.dart';

/// The modules of these tests: the app entry, the fixture provider of the
/// theme role, the fixture providers of the roles that the theme role
/// requires or uses, and the settings module, since no fixture provides the
/// settings screen role, with the router that a settings screen requires.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  FakeRouterModule(),
  FakeL10nModule(),
  FakePreferencesModule(),
  FakeThemeModule(),
  SettingsModule(),
];

/// The texts of the entry of the settings screen, as code reads them from
/// the texts of the app, each with its English text.
const Map<String, String> _texts = {
  'themeTitle': 'Theme',
  'themeSystem': 'System',
  'themeLight': 'Light',
  'themeDark': 'Dark',
};

/// Collects the code of the first argument of each `Text(...)`.
final class _TextArguments extends RecursiveAstVisitor<void> {
  final List<String> arguments = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'Text') {
      arguments.add(node.argumentList.arguments.first.toSource());
    }
    super.visitMethodInvocation(node);
  }
}

void main() {
  final harness = ContractHarness(ModuleRegistry(_modules));

  /// The app with the theme role and its preferences, without errors: with
  /// the settings module and its router if [settings], and with the
  /// localization role if [localized].
  Future<ContractResult> app({
    required bool settings,
    required bool localized,
  }) async {
    final result = await harness.check(
      ContractCase(
        'theme',
        requested: [
          FakeThemeModule.id,
          FakePreferencesModule.id,
          if (settings) ...[FakeRouterModule.id, SettingsModule.id],
          if (localized) FakeL10nModule.id,
        ],
      ),
    );
    expect(result.errors.map((issue) => '$issue'), isEmpty);
    return result;
  }

  /// What the socket [socket] of the app of [result] got from [origin], the
  /// template of the theme role unless set, each fragment as its code.
  List<String> putInto(
    ContractResult result,
    SocketRef socket, {
    ContributionOrigin origin = const RoleTemplateOrigin(themeRole),
  }) =>
      [
        for (final collected
            in result.app!.socketOrders[socket]?.contributions ??
                const <Collected>[])
          if (collected.origin == origin)
            switch (collected.contribution as SocketContribution) {
              SocketContribution(:final argName?, :final fragment?) =>
                '$argName: ${fragment.code}',
              SocketContribution(:final fragment?) => '${fragment.code}'
                  '${fragment.closing == null ? '' : '…${fragment.closing}'}',
              _ => '',
            },
      ];

  /// The file of the entry of the settings screen of the app of [result],
  /// parsed.
  CompilationUnit entryOf(ContractResult result) => parseString(
        content: result.app!.files[ThemeRole.themeModeSettingFile]!.text,
      ).unit;

  /// The texts that the entry in [unit] shows, as its code reads them.
  List<String> shownBy(CompilationUnit unit) {
    final finder = _TextArguments();
    unit.accept(finder);
    return finder.arguments;
  }

  /// Whether the file [unit] imports the texts of the app.
  bool importsTexts(CompilationUnit unit) {
    final texts = LocalizationRole.appTexts.importRef
        .resolveUri(ContractHarness.defaultContext.appName);
    return unit.directives
        .whereType<ImportDirective>()
        .any((directive) => directive.uri.stringValue == texts);
  }

  group('the theme role, with the fixture provider', () {
    test(
        'is checked in an app for each combination of a settings screen and '
        'the localization role, and none has errors', () async {
      final cases = harness.casesOfModule(FakeThemeModule.id);

      expect(cases.map((contractCase) => '$contractCase'), [
        'fake_theme with settings_screen, localization',
        'fake_theme with settings_screen',
        'fake_theme with localization',
        'fake_theme',
      ]);
      for (final contractCase in cases) {
        final result = await harness.check(contractCase);
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '$contractCase',
        );
        expect(result.app, isNotNull, reason: '$contractCase');
        // The guide for coding agents has the section of the role, and the
        // harness found every file that the section names in the app.
        expect(
          '\n## ${themeRole.description}\n'.allMatches(
            result.app!.files[AppEntryRole.agentsFile]!.text,
          ),
          hasLength(1),
          reason: '$contractCase',
        );
      }
    });

    test(
        'gives the root of the app the themes of the provider for the '
        'context of the root and the mode of the scope around the root, and '
        'the preferences the restorer of the mode', () async {
      final result = await app(settings: false, localized: false);

      expect(putInto(result, AppEntryRole.appArgs), [
        'theme: createLightTheme(context)',
        'darkTheme: createDarkTheme(context)',
        'themeMode: AppThemeModeScope.of(context)',
      ]);
      expect(putInto(result, AppEntryRole.rootWrappers), [
        'AppThemeModeScope(notifier: appThemeMode, child: …)',
      ]);
      expect(
        putInto(result, PreferencesRole.restorers),
        ['restoreAppThemeMode'],
      );
    });

    test(
        'has a provider whose look depends on state of its own: its themes '
        'read a colour from the context of the root, from a widget that the '
        'provider puts around the root', () async {
      final result = await app(settings: false, localized: false);

      expect(
        putInto(
          result,
          AppEntryRole.rootWrappers,
          origin: const ModuleOrigin(FakeThemeModule.id),
        ),
        ['FixtureSeedScope(notifier: fixtureSeed, child: …)'],
      );
      // Each of the two functions of the provider asks the scope of the
      // colour for the context that the root gives it.
      final unit = parseString(
        content: result.app!.files[ThemeRole.appThemeFile]!.text,
      ).unit;
      final functions = {
        for (final function
            in unit.declarations.whereType<FunctionDeclaration>())
          function.name.lexeme: function,
      };
      for (final name in [
        ThemeRole.createLightTheme.name,
        ThemeRole.createDarkTheme.name,
      ]) {
        final function = functions[name]!.functionExpression;
        expect(
          function.parameters!.toSource(),
          '(BuildContext context)',
          reason: name,
        );
        final body = function.body as ExpressionFunctionBody;
        expect(
          (body.expression as MethodInvocation)
              .argumentList
              .arguments
              .first
              .toSource(),
          'context',
          reason: name,
        );
      }
      final themeOf = functions['_themeOf']!.toSource();
      expect(themeOf, contains('seedColor: FixtureSeedScope.of(context)'));
    });

    test(
        'has the file of the mode from its template and the file of the '
        'themes from its provider in every app, and the file of the entry '
        'of the settings screen only in an app with one', () async {
      for (final settings in [false, true]) {
        for (final localized in [false, true]) {
          final result = await app(settings: settings, localized: localized);
          final owners = {
            for (final MapEntry(key: path, value: file)
                in result.app!.files.entries)
              if (path.startsWith('lib/core/theme/')) path: '${file.owner}',
          };

          expect(
            owners,
            {
              ThemeRole.appThemeFile: 'fake_theme',
              ThemeRole.themeModeFile: 'role:theme',
              if (settings) ThemeRole.themeModeSettingFile: 'role:theme',
            },
            reason: 'settings: $settings, localized: $localized',
          );
        }
      }
    });
  });

  group('the entry of the theme mode', () {
    test('reaches the settings screen role in an app with a settings screen',
        () async {
      final result = await app(settings: true, localized: false);

      final entry = settingsScreenRole
          .entriesIn(settingsScreenRole.hookInput(result.hook!))
          .single;
      expect('$entry', 'settings entry ThemeModeSetting');
      expect(entry.file, ThemeRole.themeModeSettingFile);
    });

    test(
        'shows texts of the app, which reach the localization role in '
        'English and in Ukrainian, in an app with the role', () async {
      final result = await app(settings: true, localized: true);
      final input = localizationRole.hookInput(result.hook!);
      final texts = [
        for (final text in localizationRole.textsIn(input))
          if (text.owner == const RoleTemplateOrigin(themeRole)) text,
      ];

      expect({for (final text in texts) text.getter: text.text.en}, _texts);
      for (final text in texts) {
        expect(text.text.languages, ['en', 'uk']);
      }
      expect(localizationRole.localesIn(input), ['en', 'uk']);
      final entry = entryOf(result);
      expect(
        shownBy(entry),
        [for (final getter in _texts.keys) 'context.l10n.$getter'],
      );
      expect(importsTexts(entry), isTrue);
    });

    test('shows its texts in English in an app without the localization role',
        () async {
      final result = await app(settings: true, localized: false);

      expect(result.hook!.presentRoles, isNot(contains(localizationRole)));
      final entry = entryOf(result);
      expect(
        shownBy(entry),
        [for (final english in _texts.values) "'$english'"],
      );
      expect(importsTexts(entry), isFalse);
    });

    test(
        'gives an app without a settings screen neither its entry nor its '
        'texts', () async {
      final result = await app(settings: false, localized: true);

      expect(result.hook!.presentRoles, isNot(contains(settingsScreenRole)));
      expect(
        [
          for (final text in localizationRole.textsIn(
            localizationRole.hookInput(result.hook!),
          ))
            if (text.owner == const RoleTemplateOrigin(themeRole)) text,
        ],
        isEmpty,
      );
    });
  });
}
