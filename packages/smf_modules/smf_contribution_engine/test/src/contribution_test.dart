import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:test/test.dart';

/// A contribution that only runs the shared formatter.
class _FormatOnly extends Contribution {
  const _FormatOnly() : super(file: 'lib/main.dart');

  @override
  Future<String> apply(String original) async => dartFormater.format(original);
}

void main() {
  group('Contribution.dartFormater', () {
    test('accepts syntax from current language versions', () async {
      const source = '''
import 'package:flutter/material.dart';

Widget buildBody(Widget? banner) {
  return Column(
    mainAxisAlignment: .center,
    children: [?banner, const Text('Hello World!')],
  );
}
''';

      expect(await const _FormatOnly().apply(source), contains('.center'));
    });

    test('keeps trailing commas', () async {
      const source = '''
final locales = [
  Locale('en'),
];
''';

      expect(await const _FormatOnly().apply(source), source);
    });

    test('formats code in the tall style', () async {
      const source = '''
final title = condition ? 'A long title that fills the line' : 'Another long title';
''';

      expect(await const _FormatOnly().apply(source), '''
final title = condition
    ? 'A long title that fills the line'
    : 'Another long title';
''');
    });
  });
}
