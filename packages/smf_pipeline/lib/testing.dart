/// The contract test harness of the lego model: checks that modules and
/// role templates follow the rules of their roles, and renders the apps
/// they make in memory.
///
/// It runs without `package:test`, so both the tests of this package and the
/// contract tests of the CLI can use it.
library;

export 'src/collector.dart' show Collected, Collection;
export 'src/order.dart' show ContributionOrder, OrderEdge;
export 'src/pubspec.dart' show MergedDependency, MergedPubspec;
export 'src/render.dart' show AddedImport, RenderedApp, RenderedFile;
export 'src/resolver.dart'
    show
        DependencyOf,
        ProviderOf,
        Requested,
        Resolution,
        ResolvedModule,
        SelectionReason;
export 'src/templates.dart'
    show
        TemplateScan,
        TemplateSection,
        TemplateTag,
        checkTemplateTags,
        missingTemplateTags,
        scanTemplate,
        templateFilesOf;
export 'src/testing/file_indexer.dart';
export 'src/testing/flutterfire.dart';
export 'src/testing/harness.dart';
export 'src/validation.dart' show ValidationResult;
