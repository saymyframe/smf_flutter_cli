import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:mustachex/mustachex.dart';
import 'package:path/path.dart';
import 'package:smf_contribution_engine/src/contribution.dart';
import 'package:smf_contribution_engine/src/contributions/contributions.dart';

/// Applies [contributions] to the files under [projectRoot].
///
/// Mustache placeholders, such as `{{app_name_sc}}`, are rendered with
/// [mustacheVariables] in the text that contributions insert. The code that is
/// already in the files is never rendered.
///
/// For the contribution types of this package, only the fields that hold new
/// code are rendered, such as [InsertIntoFunction.insert] or
/// [ReplaceWidget.toWidget]; the fields that find the target, such as
/// function names and anchors, are matched as written. A contribution of any
/// other type, a subclass included, is applied first and its result rendered,
/// with the `{{` that was already in the file kept out of it.
///
/// Each file is read once, gets its contributions in list order and is
/// written back once. A failure leaves the file being patched untouched, but
/// the files written before it stay patched.
class PatchEngine {
  /// Creates an engine that applies [contributions] to the files under
  /// [projectRoot].
  const PatchEngine(
    this.contributions, {
    required this.projectRoot,
    this.mustacheVariables,
    this.logger,
  });

  /// The changes to apply, in list order within each file.
  final List<Contribution> contributions;

  /// The directory that each [Contribution.file] is relative to.
  final String projectRoot;

  /// The values of the placeholders, such as `{'app_name': 'shop app'}`.
  ///
  /// Suffixes pick a case: with that value, `{{app_name_sc}}` renders as
  /// `shop_app` and `{{app_name_pc}}` as `ShopApp`.
  final Map<dynamic, dynamic>? mustacheVariables;

  /// Reports the progress of each file, when given.
  final Logger? logger;

  /// Applies [contributions] and writes the patched files back.
  ///
  /// Throws a [FileSystemException] when a file doesn't exist, a
  /// [MissingVariableException] when an inserted placeholder has no value,
  /// and whatever a failing contribution throws.
  Future<void> applyAll() async {
    final byFile = <String, List<Contribution>>{};
    for (final c in contributions) {
      byFile.putIfAbsent(c.file, () => []).add(c);
    }

    final mustacheProcessor = MustachexProcessor(
      initialVariables: mustacheVariables,
    );

    for (final entry in byFile.entries) {
      final file = join(projectRoot, entry.key);

      final generateProgress = logger?.progress(
        'Generating shared content for ${entry.key}',
      );

      final content = await File(file).readAsString();
      var result = content;
      for (final c in entry.value) {
        result = await _apply(c, result, mustacheProcessor);
      }

      await File(file).writeAsString(result);

      generateProgress?.complete('Generated shared content for ${entry.key}');
    }
  }
}

/// Applies [contribution] to [source] with the placeholders in the text it
/// inserts rendered by [mustache].
Future<String> _apply(
  Contribution contribution,
  String source,
  MustachexProcessor mustache,
) async {
  final rendered = await _withRenderedInserts(contribution, mustache.process);
  if (rendered != null) return rendered.apply(source);

  // A contribution of another type can only be rendered after it is applied.
  // Meanwhile the `{{` already in the file are swapped for a stand-in, so that
  // only the text the contribution adds is rendered.
  final patched = await contribution.apply(
    source.replaceAll('{{', _mustacheStandIn),
  );
  return (await mustache.process(patched)).replaceAll(_mustacheStandIn, '{{');
}

/// Two private-use characters: as long as `{{`, so lines keep their length and
/// the formatter its layout.
const _mustacheStandIn = '\u{E000}\u{E000}';

/// A copy of [c] with [render] applied to the text it inserts, so that the
/// text matches the rendered code already in the file. Null for a type the
/// engine does not define.
Future<Contribution?> _withRenderedInserts(
  Contribution c,
  Future<String> Function(String) render,
) async {
  final copy = switch (c) {
    InsertImport() => InsertImport(
        file: c.file,
        import: await render(c.import),
      ),
    InsertIntoFunction() => InsertIntoFunction(
        file: c.file,
        function: c.function,
        beforeStatement: c.beforeStatement,
        afterStatement: c.afterStatement,
        insert: await render(c.insert),
      ),
    InsertIntoListInFunction() => InsertIntoListInFunction(
        file: c.file,
        function: c.function,
        listVariableMatch: c.listVariableMatch,
        parentExpressionMatch: c.parentExpressionMatch,
        insert: await render(c.insert),
        index: c.index,
      ),
    InsertIntoListInMethodInClass() => InsertIntoListInMethodInClass(
        file: c.file,
        className: c.className,
        method: c.method,
        listVariableMatch: c.listVariableMatch,
        parentExpressionMatch: c.parentExpressionMatch,
        insert: await render(c.insert),
        index: c.index,
      ),
    InsertIntoMethodInClass() => InsertIntoMethodInClass(
        file: c.file,
        className: c.className,
        method: c.method,
        afterStatement: c.afterStatement,
        insert: await render(c.insert),
      ),
    ModifyWidgetArguments() => ModifyWidgetArguments(
        file: c.file,
        widgetName: c.widgetName,
        removeArgs: c.removeArgs,
        addArgs: {
          for (final MapEntry(:key, :value) in c.addArgs.entries)
            await render(key): await render(value),
        },
      ),
    ReplaceWidget() => ReplaceWidget(
        file: c.file,
        fromWidget: c.fromWidget,
        toWidget: await render(c.toWidget),
        className: c.className,
        methodName: c.methodName,
      ),
    _ => null,
  };
  // A subclass may do more than its fields say, so no copy of its base class
  // stands in for it.
  return copy?.runtimeType == c.runtimeType ? copy : null;
}
