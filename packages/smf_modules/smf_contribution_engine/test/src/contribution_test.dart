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
    test(
      'accepts syntax from current language versions',
      () async {
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
      },
      skip: 'Bug: the formatter is pinned to the Dart 3.6 short style, so it '
          'rejects dot shorthands (3.10) and null-aware elements (3.8)',
    );
  });
}
